import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiSpeechService {
  AiSpeechService._();
  static final AiSpeechService instance = AiSpeechService._();

  FlutterTts? _tts;
  bool _initialized = false;
  bool _enabled = true;
  double _volume = 0.9;
  final double _rate = 0.48; // Natural, clear Indian speaking pace

  bool get isEnabled => _enabled;
  double get volume => _volume;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool('ai_vision_voice_enabled') ?? true;
      _volume = prefs.getDouble('ai_vision_voice_volume') ?? 0.9;

      _tts = FlutterTts();
      await _tts?.setVolume(_volume);
      await _tts?.setSpeechRate(_rate);
      await _tts?.setPitch(1.0);

      // Prefer Hindi voice if available, fallback to en-IN or default
      final languages = await _tts?.getLanguages;
      if (languages is List && languages.contains('hi-IN')) {
        await _tts?.setLanguage('hi-IN');
      } else if (languages is List && languages.contains('hi')) {
        await _tts?.setLanguage('hi');
      } else if (languages is List && languages.contains('en-IN')) {
        await _tts?.setLanguage('en-IN');
      }

      _initialized = true;
    } catch (e) {
      debugPrint('AiSpeechService init error: $e');
      _initialized = true; // Avoid re-trying in a loop
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ai_vision_voice_enabled', enabled);
    } catch (_) {}
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    try {
      await _tts?.setVolume(_volume);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('ai_vision_voice_volume', _volume);
    } catch (_) {}
  }

  /// Speaks the given text if voice feedback is enabled
  Future<void> speak(String text) async {
    if (!_enabled) return;
    try {
      await init();
      await _tts?.stop();
      await _tts?.speak(text);
    } catch (e) {
      debugPrint('AiSpeechService speak error: $e');
    }
  }

  /// Speaks item added to cart
  Future<void> speakItemAdded({
    required String itemName,
    required double weightKg,
    required double totalPrice,
  }) async {
    if (!_enabled) return;
    final weightStr = weightKg < 1.0
        ? '${(weightKg * 1000).toStringAsFixed(0)} ग्राम'
        : '${weightKg.toStringAsFixed(2)} किलो';
    final priceStr = '₹${totalPrice.toStringAsFixed(0)}';
    final sentence = '$itemName $weightStr $priceStr जुड़ा';
    await speak(sentence);
  }

  /// Speaks ambiguous choice prompt
  Future<void> speakAmbiguousPrompt(String item1, String item2) async {
    if (!_enabled) return;
    final sentence = 'कृपया चुनें: $item1 या $item2';
    await speak(sentence);
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
