import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:bluetooth_classic/models/device.dart';
import '../core/services/scale_data_parser.dart';
import '../core/services/weighing_scale_service.dart';

class WeighingScaleProvider extends ChangeNotifier {
  final WeighingScaleService _service = WeighingScaleService.instance;

  StreamSubscription? _readingSub;
  StreamSubscription? _connSub;

  double _liveWeight = 0.0;
  double get liveWeight => _liveWeight;
  double get liveWeightGrams => (_liveWeight * 1000.0);

  bool _isStable = true;
  bool get isStable => _isStable;

  String _unit = 'kg';
  String get unit => _unit;

  String _rawStreamData = '--';
  String get rawStreamData => _rawStreamData;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  String? _scaleName;
  String? get scaleName => _scaleName;

  String? _scaleMac;
  String? get scaleMac => _scaleMac;

  ScaleProtocol get protocol => _service.protocol;
  ScaleUnitMode get unitMode => _service.unitMode;
  bool get autoFillDialog => _service.autoFillDialog;
  bool get autoAddOnStable => _service.autoAddOnStable;
  bool get isHardwareSupported => _service.isHardwareSupported;

  WeighingScaleProvider() {
    _init();
  }

  Future<void> _init() async {
    await _service.init();

    _scaleMac = await _service.getSavedScaleMac();
    _scaleName = await _service.getSavedScaleName();

    _readingSub = _service.onReading.listen((reading) {
      _liveWeight = reading.weight;
      _isStable = reading.isStable;
      _unit = reading.unit;
      _rawStreamData = reading.rawData;
      notifyListeners();
    });

    _connSub = _service.onConnectionStateChanged.listen((connected) {
      _isConnected = connected;
      _isConnecting = false;
      notifyListeners();
    });

    // Auto-connect to saved scale if present
    if (_scaleMac != null && _scaleMac!.isNotEmpty) {
      connectToScale(_scaleMac!, name: _scaleName);
    }
  }

  Future<List<Device>> getPairedDevices() async {
    return await _service.getPairedDevices();
  }

  Future<bool> connectToScale(String mac, {String? name}) async {
    _isConnecting = true;
    _scaleMac = mac;
    _scaleName = name;
    notifyListeners();

    final ok = await _service.connect(mac, name: name);
    _isConnected = ok;
    _isConnecting = false;
    notifyListeners();
    return ok;
  }

  Future<void> disconnectScale() async {
    await _service.disconnect();
    _isConnected = false;
    _liveWeight = 0.0;
    _rawStreamData = '--';
    notifyListeners();
  }

  Future<void> forgetSavedScale() async {
    await _service.forgetScale();
    _scaleMac = null;
    _scaleName = null;
    _isConnected = false;
    _liveWeight = 0.0;
    _rawStreamData = '--';
    notifyListeners();
  }

  Future<void> setProtocol(ScaleProtocol proto) async {
    await _service.saveSettings(protocol: proto);
    notifyListeners();
  }

  Future<void> setUnitMode(ScaleUnitMode mode) async {
    await _service.saveSettings(unitMode: mode);
    notifyListeners();
  }

  Future<void> toggleAutoFill(bool val) async {
    await _service.saveSettings(autoFillDialog: val);
    notifyListeners();
  }

  Future<void> toggleAutoAdd(bool val) async {
    await _service.saveSettings(autoAddOnStable: val);
    notifyListeners();
  }

  Future<void> tare() async {
    await _service.sendTareCommand();
    _liveWeight = 0.0;
    notifyListeners();
  }

  void simulateWeight(double weight, {bool isStable = true}) {
    _service.simulateReading(weight, isStable: isStable);
  }

  @override
  void dispose() {
    _readingSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }
}

