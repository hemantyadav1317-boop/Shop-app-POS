import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/ai_speech_service.dart';
import '../core/services/ai_vision_catalog.dart';
import '../core/services/ai_vision_service.dart';
import '../core/services/remote_camera_service.dart';
import '../core/services/sound_service.dart';
import '../data/models/product.dart';
import 'cart_provider.dart';
import 'product_provider.dart';

enum AiCameraSource {
  localDevice,
  remotePhoneNode,
}

class AiVisionProvider extends ChangeNotifier {
  final AiVisionService _visionService = AiVisionService.instance;
  final AiSpeechService _speechService = AiSpeechService.instance;
  final RemoteCameraService _remoteCamera = RemoteCameraService.instance;

  bool _isAiVisionActive = false;
  bool get isAiVisionActive => _isAiVisionActive;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  AiCameraSource _cameraSource = AiCameraSource.localDevice;
  AiCameraSource get cameraSource => _cameraSource;

  String _remoteCameraUrl = '';
  String get remoteCameraUrl => _remoteCameraUrl;

  bool _voiceFeedbackEnabled = true;
  bool get voiceFeedbackEnabled => _voiceFeedbackEnabled;

  double _confidenceThreshold = 0.75;
  double get confidenceThreshold => _confidenceThreshold;

  AiRecognitionResult? _lastResult;
  AiRecognitionResult? get lastResult => _lastResult;

  bool _isAmbiguityPending = false;
  bool get isAmbiguityPending => _isAmbiguityPending;

  List<ProduceItem> _ambiguousOptions = [];
  List<ProduceItem> get ambiguousOptions => _ambiguousOptions;

  double _pendingWeight = 0.0;
  double get pendingWeight => _pendingWeight;

  bool _hasProcessedCurrentWeight = false;

  // Stream controller to notify UI of camera frame request
  final StreamController<void> _frameRequestController = StreamController<void>.broadcast();
  Stream<void> get onFrameRequested => _frameRequestController.stream;

  AiVisionProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAiVisionActive = prefs.getBool('ai_vision_active') ?? false;
      _voiceFeedbackEnabled = prefs.getBool('ai_vision_voice_enabled') ?? true;
      final src = prefs.getString('ai_camera_source') ?? 'local';
      _cameraSource = src == 'remote' ? AiCameraSource.remotePhoneNode : AiCameraSource.localDevice;
      _remoteCameraUrl = prefs.getString('ai_remote_camera_url') ?? '';
      _confidenceThreshold = prefs.getDouble('ai_confidence_threshold') ?? 0.75;
      await _speechService.init();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleAiVision([bool? enable]) async {
    _isAiVisionActive = enable ?? !_isAiVisionActive;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ai_vision_active', _isAiVisionActive);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setVoiceFeedbackEnabled(bool enabled) async {
    _voiceFeedbackEnabled = enabled;
    await _speechService.setEnabled(enabled);
    notifyListeners();
  }

  Future<void> setCameraSource(AiCameraSource source, {String? remoteUrl}) async {
    _cameraSource = source;
    if (remoteUrl != null) _remoteCameraUrl = remoteUrl.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_camera_source', source == AiCameraSource.remotePhoneNode ? 'remote' : 'local');
      await prefs.setString('ai_remote_camera_url', _remoteCameraUrl);
    } catch (_) {}
    notifyListeners();
  }

  /// Called continuously by weighing scale listener in POS screen
  void onScaleReadingChanged({
    required double weight,
    required bool isStable,
    required ProductProvider productProvider,
    required CartProvider cartProvider,
  }) {
    if (!_isAiVisionActive) return;

    // Platter cleared -> reset flag for next vegetable
    if (weight < 0.025) {
      if (_hasProcessedCurrentWeight || _isAmbiguityPending) {
        _hasProcessedCurrentWeight = false;
        _isAmbiguityPending = false;
        _ambiguousOptions = [];
        notifyListeners();
      }
      return;
    }

    // New weight placed and stable
    if (weight >= 0.040 && isStable && !_hasProcessedCurrentWeight && !_isProcessing) {
      _pendingWeight = weight;
      triggerAutoRecognition(
        weight: weight,
        productProvider: productProvider,
        cartProvider: cartProvider,
      );
    }
  }

  /// Triggers recognition using either local camera or remote camera
  Future<void> triggerAutoRecognition({
    required double weight,
    required ProductProvider productProvider,
    required CartProvider cartProvider,
  }) async {
    if (_isProcessing) return;
    _isProcessing = true;
    _pendingWeight = weight;
    notifyListeners();

    try {
      Uint8List? imageBytes;

      if (_cameraSource == AiCameraSource.remotePhoneNode && _remoteCameraUrl.isNotEmpty) {
        // Fetch snapshot from remote phone camera node
        imageBytes = await _remoteCamera.fetchRemoteSnapshot(_remoteCameraUrl);
      } else {
        // Request local frame from POS camera preview widget
        _frameRequestController.add(null);
        // Wait up to 600ms for local frame to arrive via processFrameBytes
        return;
      }

      if (imageBytes != null && imageBytes.isNotEmpty) {
        await processFrameBytes(
          imageBytes,
          weight: weight,
          productProvider: productProvider,
          cartProvider: cartProvider,
        );
      } else {
        _isProcessing = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('triggerAutoRecognition error: $e');
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Processes captured frame bytes from local or remote camera
  Future<void> processFrameBytes(
    Uint8List bytes, {
    required double weight,
    required ProductProvider productProvider,
    required CartProvider cartProvider,
  }) async {
    try {
      final result = await _visionService.analyzeImageBytes(bytes);
      _isProcessing = false;

      if (result == null) {
        notifyListeners();
        return;
      }

      _lastResult = result;

      // Handle Ambiguous Recognition (e.g., Cucumber vs Kakdi, or Raw Mango vs Guava)
      if (result.isAmbiguous && result.alternativeItems.isNotEmpty) {
        _isAmbiguityPending = true;
        _ambiguousOptions = result.alternativeItems;
        _pendingWeight = weight;
        SoundService.instance.playAiAmbiguousAlert();

        final item1 = result.alternativeItems[0].hindiName;
        final item2 = result.alternativeItems[1].hindiName;
        await _speechService.speakAmbiguousPrompt(item1, item2);
        notifyListeners();
        return;
      }

      // High Confidence Recognition
      if (result.confidence >= _confidenceThreshold) {
        _hasProcessedCurrentWeight = true;
        _isAmbiguityPending = false;
        SoundService.instance.playAiRecognized();

        // Find or match item in shopkeeper inventory
        final matchedProduct = _findMatchingInventoryProduct(result.item, productProvider);

        if (matchedProduct != null) {
          final totalPrice = matchedProduct.price * weight;
          cartProvider.incrementOrAdd(matchedProduct, weight);
          SoundService.instance.playProductAdd();

          if (_voiceFeedbackEnabled) {
            await _speechService.speakItemAdded(
              itemName: matchedProduct.name,
              weightKg: weight,
              totalPrice: totalPrice,
            );
          }
        } else {
          // Speak item recognized even if not in inventory yet
          if (_voiceFeedbackEnabled) {
            await _speechService.speak('${result.item.hindiName} पहचाना गया');
          }
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('processFrameBytes error: $e');
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Resolves an ambiguous choice when shopkeeper taps one of the 2-3 options
  Future<void> resolveAmbiguousChoice({
    required ProduceItem selectedItem,
    required ProductProvider productProvider,
    required CartProvider cartProvider,
  }) async {
    _isAmbiguityPending = false;
    _hasProcessedCurrentWeight = true;
    final weight = _pendingWeight > 0.0 ? _pendingWeight : 1.0;

    SoundService.instance.playAiRecognized();
    final matchedProduct = _findMatchingInventoryProduct(selectedItem, productProvider);

    if (matchedProduct != null) {
      final totalPrice = matchedProduct.price * weight;
      cartProvider.incrementOrAdd(matchedProduct, weight);
      SoundService.instance.playProductAdd();

      if (_voiceFeedbackEnabled) {
        await _speechService.speakItemAdded(
          itemName: matchedProduct.name,
          weightKg: weight,
          totalPrice: totalPrice,
        );
      }
    } else {
      if (_voiceFeedbackEnabled) {
        await _speechService.speak('${selectedItem.hindiName} चुना गया');
      }
    }

    notifyListeners();
  }

  /// Cancels ambiguity prompt
  void dismissAmbiguityPrompt() {
    _isAmbiguityPending = false;
    _ambiguousOptions = [];
    notifyListeners();
  }

  /// Searches the shopkeeper's actual inventory for a product matching the produce item
  Product? _findMatchingInventoryProduct(ProduceItem item, ProductProvider productProvider) {
    final products = productProvider.products;
    if (products.isEmpty) return null;

    // 1. Direct name match
    for (final p in products) {
      final nameLower = p.name.toLowerCase();
      if (nameLower.contains(item.id.toLowerCase()) ||
          nameLower.contains(item.englishName.toLowerCase()) ||
          nameLower.contains(item.hindiName.toLowerCase())) {
        return p;
      }
      for (final alias in item.aliases) {
        if (nameLower.contains(alias.toLowerCase())) {
          return p;
        }
      }
    }

    // 2. Keyword tokens match
    for (final p in products) {
      for (final alias in item.aliases) {
        if (p.name.toLowerCase().contains(alias.toLowerCase())) {
          return p;
        }
      }
    }

    return null;
  }

  @override
  void dispose() {
    _frameRequestController.close();
    super.dispose();
  }
}
