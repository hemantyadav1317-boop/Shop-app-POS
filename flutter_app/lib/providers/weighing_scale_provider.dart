import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:bluetooth_classic/models/device.dart';
import '../core/services/scale_data_parser.dart';
import '../core/services/weighing_scale_service.dart';

class WeighingScaleProvider extends ChangeNotifier with WidgetsBindingObserver {
  final WeighingScaleService _service = WeighingScaleService.instance;

  StreamSubscription? _readingSub;
  StreamSubscription? _connSub;
  StreamSubscription? _statusSub;
  bool _disposed = false;

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
  bool get isConnecting => _isConnecting || _service.isConnecting;

  bool get isReconnecting => _service.isReconnecting;

  String? _scaleName;
  String? get scaleName => _scaleName;

  String? _scaleMac;
  String? get scaleMac => _scaleMac;

  ScaleProtocol get protocol => _service.protocol;
  ScaleUnitMode get unitMode => _service.unitMode;
  bool get autoFillDialog => _service.autoFillDialog;
  bool get autoAddOnStable => _service.autoAddOnStable;
  bool get keepAlivePing => _service.keepAlivePing;
  bool get isHardwareSupported => _service.isHardwareSupported;

  WeighingScaleProvider() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    await _service.init();
    if (_disposed) return;

    _scaleMac = await _service.getSavedScaleMac();
    _scaleName = await _service.getSavedScaleName();
    _isConnected = _service.isConnected;

    _readingSub = _service.onReading.listen((reading) {
      if (_disposed) return;
      _liveWeight = reading.weight;
      _isStable = reading.isStable;
      _unit = reading.unit;
      _rawStreamData = reading.rawData;
      notifyListeners();
    });

    _connSub = _service.onConnectionStateChanged.listen((connected) {
      if (_disposed) return;
      _isConnected = connected;
      _isConnecting = _service.isConnecting;
      notifyListeners();
    });

    _statusSub = _service.onStatusChanged.listen((_) {
      if (_disposed) return;
      _isConnected = _service.isConnected;
      _isConnecting = _service.isConnecting;
      notifyListeners();
    });

    // Auto-connect to saved scale if present
    if (_scaleMac != null && _scaleMac!.isNotEmpty) {
      connectToScale(_scaleMac!, name: _scaleName);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_service.ensureConnected());
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
    if (_disposed) return ok;
    _isConnected = ok;
    _isConnecting = _service.isConnecting;
    notifyListeners();
    return ok;
  }

  Future<void> ensureScaleConnected({bool force = false}) async {
    await _service.ensureConnected(force: force);
  }

  Future<void> disconnectScale() async {
    await _service.disconnect();
    if (_disposed) return;
    _isConnected = false;
    _isConnecting = false;
    _liveWeight = 0.0;
    _rawStreamData = '--';
    notifyListeners();
  }

  Future<void> forgetSavedScale() async {
    await _service.forgetScale();
    if (_disposed) return;
    _scaleMac = null;
    _scaleName = null;
    _isConnected = false;
    _isConnecting = false;
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

  Future<void> toggleKeepAlivePing(bool val) async {
    await _service.saveSettings(keepAlivePing: val);
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
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _readingSub?.cancel();
    _connSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }
}
