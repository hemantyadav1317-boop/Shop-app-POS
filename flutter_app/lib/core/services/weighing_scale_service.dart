import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bluetooth_classic/models/device.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'scale_data_parser.dart';

class WeighingScaleService {
  static final WeighingScaleService instance = WeighingScaleService._internal();
  WeighingScaleService._internal();

  static const String _prefMacKey = 'saved_scale_mac';
  static const String _prefNameKey = 'saved_scale_name';
  static const String _prefProtocolKey = 'saved_scale_protocol';
  static const String _prefUnitModeKey = 'saved_scale_unit_mode';
  static const String _prefAutoFillKey = 'saved_scale_auto_fill';
  static const String _prefAutoAddKey = 'saved_scale_auto_add_stable';
  static const String _prefKeepAliveKey = 'saved_scale_keep_alive_ping';

  static const String sppUuid = "00001101-0000-1000-8000-00805f9b34fb";

  static const MethodChannel _nativeMethodChannel =
      MethodChannel('com.shop.pos/bluetooth_scale');
  static const EventChannel _nativeDataChannel =
      EventChannel('com.shop.pos/bluetooth_scale_data');
  static const EventChannel _nativeStatusChannel =
      EventChannel('com.shop.pos/bluetooth_scale_status');

  StreamSubscription? _dataSubscription;
  StreamSubscription? _statusSubscription;
  Timer? _reconnectTimer;
  Timer? _keepAliveWatchdog;
  Completer<bool>? _connectCompleter;

  DateTime? _lastDataReceivedAt;
  DateTime? _previousPacketAt;
  DateTime? _lastKeepAliveWriteAt;
  int _fastPacketStreak = 0;
  bool _observedContinuousStream = false;

  int _reconnectAttempt = 0;
  bool _isConnecting = false;
  bool _isRefreshingSocket = false;
  bool _userExplicitDisconnect = false;
  String _buffer = "";

  final StreamController<ScaleReading> _readingController =
      StreamController<ScaleReading>.broadcast();
  Stream<ScaleReading> get onReading => _readingController.stream;

  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get onConnectionStateChanged => _connectionStateController.stream;

  final StreamController<void> _statusTickController =
      StreamController<void>.broadcast();
  Stream<void> get onStatusChanged => _statusTickController.stream;

  ScaleReading? _lastReading;
  ScaleReading? get lastReading => _lastReading;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool get isConnecting => _isConnecting;

  bool get isReconnecting =>
      !_isConnected &&
      !_userExplicitDisconnect &&
      _connectedMac != null &&
      _connectedMac!.isNotEmpty &&
      (_isConnecting || (_reconnectTimer?.isActive ?? false));

  String? _connectedMac;
  String? get connectedMac => _connectedMac;

  String? _connectedName;
  String? get connectedName => _connectedName;

  ScaleProtocol _protocol = ScaleProtocol.autoDetect;
  ScaleProtocol get protocol => _protocol;

  ScaleUnitMode _unitMode = ScaleUnitMode.autoDetect;
  ScaleUnitMode get unitMode => _unitMode;

  bool _autoFillDialog = true;
  bool get autoFillDialog => _autoFillDialog;

  bool _autoAddOnStable = false;
  bool get autoAddOnStable => _autoAddOnStable;

  bool _keepAlivePing = true;
  bool get keepAlivePing => _keepAlivePing;

  bool get isHardwareSupported =>
      hardwareSupportedOverrideForTest ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  // Testing hooks
  @visibleForTesting
  bool? hardwareSupportedOverrideForTest;
  @visibleForTesting
  Future<bool> Function(String mac, String uuid)? nativeConnectOverrideForTest;
  @visibleForTesting
  Future<bool> Function()? nativeDisconnectOverrideForTest;
  @visibleForTesting
  Future<bool> Function()? nativeSocketAliveOverrideForTest;
  @visibleForTesting
  Future<bool> Function(String msg)? nativeWriteOverrideForTest;
  @visibleForTesting
  Duration reconnectBaseDelayForTest = const Duration(seconds: 2);
  @visibleForTesting
  Duration heartbeatSilenceThresholdForTest = const Duration(seconds: 12);
  @visibleForTesting
  Duration continuousStallThresholdForTest = const Duration(seconds: 25);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final protocolIndex = prefs.getInt(_prefProtocolKey) ?? 0;
    _protocol = ScaleProtocol.values[protocolIndex.clamp(0, ScaleProtocol.values.length - 1)];
    final unitModeIndex = prefs.getInt(_prefUnitModeKey) ?? 0;
    _unitMode = ScaleUnitMode.values[unitModeIndex.clamp(0, ScaleUnitMode.values.length - 1)];
    _autoFillDialog = prefs.getBool(_prefAutoFillKey) ?? true;
    _autoAddOnStable = prefs.getBool(_prefAutoAddKey) ?? false;
    _keepAlivePing = prefs.getBool(_prefKeepAliveKey) ?? true;

    if (isHardwareSupported) {
      _listenToNativeStreams();
    }
  }

  void _listenToNativeStreams() {
    if (_statusSubscription == null && nativeConnectOverrideForTest == null) {
      try {
        _statusSubscription = _nativeStatusChannel.receiveBroadcastStream().listen(
          (dynamic status) {
            if (status is int) {
              _handleNativeStatus(status);
            } else if (status is num) {
              _handleNativeStatus(status.toInt());
            }
          },
          onError: (e) {
            debugPrint("Native scale status stream error: $e");
          },
        );
      } catch (_) {}
    }

    if (_dataSubscription == null && nativeConnectOverrideForTest == null) {
      try {
        _dataSubscription = _nativeDataChannel.receiveBroadcastStream().listen(
          (dynamic data) {
            if (data is Uint8List) {
              _handleIncomingData(data);
            } else if (data is List<int>) {
              _handleIncomingData(Uint8List.fromList(data));
            }
          },
          onError: (e) {
            debugPrint("Native scale data stream error: $e");
            _handleConnectionDrop();
          },
          onDone: () {
            debugPrint("Native scale data stream closed");
            _handleConnectionDrop();
          },
        );
      } catch (_) {}
    }
  }

  void _handleNativeStatus(int status) {
    // 0 = disconnected, 1 = connecting, 2 = connected, 3 = BT adapter back ON
    debugPrint("Bluetooth scale native status changed: $status (refreshing=$_isRefreshingSocket)");
    if (_isRefreshingSocket && status == 0) {
      return;
    }
    if (status == 0) {
      if ((_isConnected || _isConnecting) && !_userExplicitDisconnect) {
        _handleConnectionDrop();
      } else {
        _isConnected = false;
        _isConnecting = false;
        _connectionStateController.add(false);
        _statusTickController.add(null);
      }
    } else if (status == 2) {
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempt = 0;
      _reconnectTimer?.cancel();
      _connectionStateController.add(true);
      _statusTickController.add(null);
    } else if (status == 3) {
      // Bluetooth radio was turned back ON on the phone
      if (!_userExplicitDisconnect && _connectedMac != null && _connectedMac!.isNotEmpty) {
        _reconnectAttempt = 0;
        unawaited(ensureConnected(force: true));
      }
    }
  }

  Future<void> saveSettings({
    ScaleProtocol? protocol,
    ScaleUnitMode? unitMode,
    bool? autoFillDialog,
    bool? autoAddOnStable,
    bool? keepAlivePing,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (protocol != null) {
      _protocol = protocol;
      await prefs.setInt(_prefProtocolKey, protocol.index);
    }
    if (unitMode != null) {
      _unitMode = unitMode;
      await prefs.setInt(_prefUnitModeKey, unitMode.index);
    }
    if (autoFillDialog != null) {
      _autoFillDialog = autoFillDialog;
      await prefs.setBool(_prefAutoFillKey, autoFillDialog);
    }
    if (autoAddOnStable != null) {
      _autoAddOnStable = autoAddOnStable;
      await prefs.setBool(_prefAutoAddKey, autoAddOnStable);
    }
    if (keepAlivePing != null) {
      _keepAlivePing = keepAlivePing;
      await prefs.setBool(_prefKeepAliveKey, keepAlivePing);
    }
  }

  Future<String?> getSavedScaleMac() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefMacKey);
  }

  Future<String?> getSavedScaleName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefNameKey);
  }

  Future<void> saveSelectedScale(String mac, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefMacKey, mac);
    await prefs.setString(_prefNameKey, name);
  }

  Future<void> forgetScale() async {
    await disconnect(userExplicit: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefMacKey);
    await prefs.remove(_prefNameKey);
    _connectedMac = null;
    _connectedName = null;
    _statusTickController.add(null);
  }

  Future<List<Device>> getPairedDevices() async {
    if (!isHardwareSupported) {
      return [];
    }

    final List<Device> result = [];

    // 1. Native BluetoothAdapter.bondedDevices (works immediately with BLUETOOTH_CONNECT)
    try {
      final List<dynamic>? bonded =
          await _nativeMethodChannel.invokeMethod<List<dynamic>>('getBondedDevices');
      if (bonded != null && bonded.isNotEmpty) {
        for (final entry in bonded) {
          if (entry is Map) {
            final name = (entry['name']?.toString() ?? '').trim();
            final addr = (entry['address']?.toString() ?? '').trim();
            if (addr.isNotEmpty) {
              result.add(Device(name: name.isNotEmpty ? name : 'Bluetooth Device', address: addr));
            }
          }
        }
        if (result.isNotEmpty) {
          return result;
        }
      }
    } catch (e) {
      debugPrint("Native getBondedDevices err: $e");
    }

    // 2. Fallback: PrintBluetoothThermal bonded devices query
    try {
      final List<BluetoothInfo> thermalList = await PrintBluetoothThermal.pairedBluetooths;
      if (thermalList.isNotEmpty) {
        for (final info in thermalList) {
          final devName = (info.name.isNotEmpty) ? info.name : 'Bluetooth Device';
          final devMac = info.macAdress;
          if (devMac.isNotEmpty) {
            result.add(Device(name: devName, address: devMac));
          }
        }
      }
    } catch (e) {
      debugPrint("PrintBluetoothThermal paired query err: $e");
    }

    return result;
  }

  Future<bool> _invokeNativeConnect(String mac, String uuid) async {
    if (nativeConnectOverrideForTest != null) {
      return await nativeConnectOverrideForTest!(mac, uuid);
    }
    final ok = await _nativeMethodChannel.invokeMethod<bool>('connect', {
      'address': mac,
      'serviceUuid': uuid,
    });
    return ok ?? false;
  }

  Future<void> _invokeNativeDisconnect() async {
    if (nativeDisconnectOverrideForTest != null) {
      await nativeDisconnectOverrideForTest!();
      return;
    }
    await _nativeMethodChannel.invokeMethod<bool>('disconnect');
  }

  Future<bool> _checkNativeSocketAlive() async {
    if (!isHardwareSupported) return _isConnected;
    if (nativeSocketAliveOverrideForTest != null) {
      return await nativeSocketAliveOverrideForTest!();
    }
    try {
      final alive = await _nativeMethodChannel.invokeMethod<bool>('isSocketAlive');
      return alive ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _invokeNativeWrite(String message) async {
    if (!isHardwareSupported) return true;
    if (nativeWriteOverrideForTest != null) {
      return await nativeWriteOverrideForTest!(message);
    }
    try {
      final ok = await _nativeMethodChannel.invokeMethod<bool>('write', {
        'message': message,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> connect(
    String macAddress, {
    String? name,
    bool isAutoRetry = false,
  }) async {
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      return await _connectCompleter!.future;
    }

    final completer = Completer<bool>();
    _connectCompleter = completer;

    try {
      _userExplicitDisconnect = false;
      _connectedMac = macAddress;
      _connectedName = name ?? _connectedName ?? 'Bluetooth Scale';

      if (!isAutoRetry) {
        _reconnectAttempt = 0;
      }
      _reconnectTimer?.cancel();

      if (!isHardwareSupported) {
        _isConnected = true;
        _isConnecting = false;
        _lastDataReceivedAt = DateTime.now();
        await saveSelectedScale(macAddress, _connectedName!);
        _connectionStateController.add(true);
        _statusTickController.add(null);
        completer.complete(true);
        return true;
      }

      _listenToNativeStreams();
      _isConnecting = true;
      _statusTickController.add(null);

      // Persist selected scale immediately so auto-reconnect stays active even if scale is momentarily asleep
      await saveSelectedScale(macAddress, _connectedName!);

      // Ensure bluetooth permissions are granted smoothly without throwing crash
      if (nativeConnectOverrideForTest == null) {
        try {
          await PrintBluetoothThermal.isPermissionBluetoothGranted;
        } catch (_) {}
      }

      _isRefreshingSocket = true;
      try {
        await _cleanConnection(emitDisconnectedEvent: false);
      } finally {
        _isRefreshingSocket = false;
      }

      final bool success = await _invokeNativeConnect(macAddress, sppUuid);
      if (success && !_userExplicitDisconnect) {
        _isConnected = true;
        _isConnecting = false;
        _reconnectAttempt = 0;
        _lastDataReceivedAt = DateTime.now();
        _previousPacketAt = null;
        _lastKeepAliveWriteAt = null;
        _fastPacketStreak = 0;
        _observedContinuousStream = false;
        _startWatchdog();
        _connectionStateController.add(true);
        _statusTickController.add(null);
        completer.complete(true);
        return true;
      }
    } catch (e) {
      debugPrint("Error connecting to scale: $e");
    } finally {
      _isRefreshingSocket = false;
      if (_connectCompleter == completer) {
        _connectCompleter = null;
      }
    }

    _isConnected = false;
    _isConnecting = false;
    _connectionStateController.add(false);
    _statusTickController.add(null);

    if (!_userExplicitDisconnect && _connectedMac != null) {
      _startWatchdog();
      _scheduleAutoReconnect();
    }

    if (!completer.isCompleted) {
      completer.complete(false);
    }
    return false;
  }

  /// Ensures a saved/active scale stays connected (safe to call on AppResume or periodic health checks).
  Future<void> ensureConnected({bool force = false}) async {
    if (_userExplicitDisconnect) return;

    final targetMac = (_connectedMac != null && _connectedMac!.isNotEmpty)
        ? _connectedMac
        : await getSavedScaleMac();
    if (targetMac == null || targetMac.isEmpty) return;

    final targetName = _connectedName ?? await getSavedScaleName();
    _connectedMac = targetMac;
    _connectedName = targetName;

    if (_isConnected) {
      final alive = await _checkNativeSocketAlive();
      if (alive && !force) {
        return;
      }
      debugPrint("ensureConnected detected dead socket; triggering recovery...");
      _handleConnectionDrop();
      return;
    }

    if (!_isConnecting) {
      if (force) _reconnectAttempt = 0;
      await connect(targetMac, name: targetName, isAutoRetry: !force);
    }
  }

  void _handleConnectionDrop() {
    if (_isRefreshingSocket) return;
    _isConnected = false;
    _isConnecting = false;
    _connectionStateController.add(false);
    _statusTickController.add(null);

    if (!_userExplicitDisconnect && _connectedMac != null && _connectedMac!.isNotEmpty) {
      _startWatchdog();
      _scheduleAutoReconnect();
    }
  }

  Duration _computeReconnectDelay(int attempt) {
    final baseMs = reconnectBaseDelayForTest.inMilliseconds;
    // Backoff schedule: 1x (2s), 2x (4s), 3x (6s), 5x (10s cap)
    final multiplier = attempt <= 0
        ? 1
        : attempt == 1
            ? 2
            : attempt == 2
                ? 3
                : 5;
    return Duration(milliseconds: baseMs * multiplier);
  }

  void _scheduleAutoReconnect() {
    if (_userExplicitDisconnect || _connectedMac == null || _connectedMac!.isEmpty) return;
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;

    final delay = _computeReconnectDelay(_reconnectAttempt);
    debugPrint("Scheduling scale auto-reconnect attempt #${_reconnectAttempt + 1} in ${delay.inMilliseconds}ms to $_connectedMac");

    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      if (_userExplicitDisconnect || _isConnected || _connectedMac == null) return;
      _reconnectAttempt++;
      await connect(_connectedMac!, name: _connectedName, isAutoRetry: true);
    });
    _statusTickController.add(null);
  }

  void _startWatchdog() {
    if (_keepAliveWatchdog != null && _keepAliveWatchdog!.isActive) return;
    _keepAliveWatchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_runWatchdogTick());
    });
  }

  Future<void> _runWatchdogTick() async {
    if (_userExplicitDisconnect || _connectedMac == null || _connectedMac!.isEmpty) {
      return;
    }

    if (!_isConnected) {
      if (!_isConnecting && (_reconnectTimer == null || !_reconnectTimer!.isActive)) {
        _scheduleAutoReconnect();
      }
      return;
    }

    // 1. Ask native Android stack if RFCOMM socket & read thread are still alive
    if (isHardwareSupported) {
      final alive = await _checkNativeSocketAlive();
      if (!alive) {
        debugPrint("Scale watchdog: native socket is dead -> reconnecting");
        _handleConnectionDrop();
        return;
      }
    }

    final now = DateTime.now();
    final lastData = _lastDataReceivedAt;
    if (lastData == null) return;

    final silenceDuration = now.difference(lastData);

    // 2. If a scale that normally streams continuously went completely silent for too long,
    //    refresh the RFCOMM link so a sleeping/half-open connection recovers automatically.
    if (_observedContinuousStream && silenceDuration >= continuousStallThresholdForTest) {
      debugPrint(
        "Scale continuous stream stalled for ${silenceDuration.inSeconds}s -> refreshing socket",
      );
      _isConnected = false;
      _connectionStateController.add(false);
      await connect(_connectedMac!, name: _connectedName, isAutoRetry: true);
      return;
    }

    // 3. Optional lightweight keep-alive CRLF heartbeat during extended silence
    if (_keepAlivePing && silenceDuration >= heartbeatSilenceThresholdForTest) {
      final sinceLastPing = _lastKeepAliveWriteAt == null
          ? const Duration(days: 1)
          : now.difference(_lastKeepAliveWriteAt!);
      if (sinceLastPing >= heartbeatSilenceThresholdForTest) {
        _lastKeepAliveWriteAt = now;
        final ok = await _invokeNativeWrite("\r\n");
        if (!ok && isHardwareSupported) {
          debugPrint("Scale keep-alive ping write failed -> socket lost, reconnecting");
          _handleConnectionDrop();
        }
      }
    }
  }

  Future<void> disconnect({bool userExplicit = true}) async {
    _userExplicitDisconnect = userExplicit;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (userExplicit) {
      _keepAliveWatchdog?.cancel();
      _keepAliveWatchdog = null;
      _reconnectAttempt = 0;
    }
    await _cleanConnection(emitDisconnectedEvent: true);
    _statusTickController.add(null);
  }

  Future<void> _cleanConnection({bool emitDisconnectedEvent = true}) async {
    _buffer = "";

    if (isHardwareSupported) {
      try {
        await _invokeNativeDisconnect();
      } catch (_) {}
    }

    _isConnected = false;
    _isConnecting = false;
    if (emitDisconnectedEvent) {
      _connectionStateController.add(false);
    }
  }

  void _handleIncomingData(Uint8List bytes) {
    final now = DateTime.now();
    if (_previousPacketAt != null && now.difference(_previousPacketAt!).inSeconds <= 3) {
      _fastPacketStreak++;
      if (_fastPacketStreak >= 4) {
        _observedContinuousStream = true;
      }
    } else {
      _fastPacketStreak = 1;
    }
    _previousPacketAt = now;
    _lastDataReceivedAt = now;

    try {
      final String chunk = ascii.decode(bytes, allowInvalid: true);
      _buffer += chunk;

      // Check for line delimiters commonly used by scales (\n, \r, or ETX \x03)
      if (_buffer.contains('\n') || _buffer.contains('\r') || _buffer.contains('\x03')) {
        List<String> segments = _buffer.split(RegExp(r'[\r\n\x03]+'));
        _buffer = segments.isNotEmpty ? segments.removeLast() : "";

        for (final seg in segments) {
          final trimmed = seg.trim();
          if (trimmed.isNotEmpty) {
            final reading = ScaleDataParser.parse(
              trimmed,
              _protocol,
              unitMode: _unitMode,
            );
            if (reading != null) {
              _lastReading = reading;
              _readingController.add(reading);
            }
          }
        }
      }

      // Safeguard against unbounded buffer growth
      if (_buffer.length > 512) {
        _buffer = _buffer.substring(_buffer.length - 128);
      }
    } catch (e) {
      debugPrint("Error decoding incoming scale bytes: $e");
    }
  }

  /// Sends a Tare / Zero command to scales that support remote zeroing
  Future<bool> sendTareCommand() async {
    if (!isHardwareSupported || !_isConnected) {
      // In simulator mode, emit 0.000 kg
      simulateReading(0.000, isStable: true);
      return true;
    }
    try {
      // Standard scale tare command
      return await _invokeNativeWrite("T\r\n");
    } catch (e) {
      debugPrint("Error sending tare to scale: $e");
      return false;
    }
  }

  /// Allows developers & merchants to test live weight synchronization
  /// without requiring a physical hardware scale attached.
  void simulateReading(double weight, {bool isStable = true, String unit = 'kg'}) {
    final reading = ScaleReading(
      weight: weight,
      isStable: isStable,
      unit: unit,
      rawData: 'SIMULATED:+${weight.toStringAsFixed(3)}$unit',
      timestamp: DateTime.now(),
    );
    _lastReading = reading;
    _readingController.add(reading);
  }

  @visibleForTesting
  Future<void> runWatchdogTickForTest() => _runWatchdogTick();

  @visibleForTesting
  void simulateNativeStatusForTest(int status) => _handleNativeStatus(status);

  @visibleForTesting
  void simulateIncomingBytesForTest(Uint8List bytes) => _handleIncomingData(bytes);

  @visibleForTesting
  void backdateLastDataForTest(DateTime timestamp, {bool observedContinuous = false}) {
    _lastDataReceivedAt = timestamp;
    _observedContinuousStream = observedContinuous;
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _keepAliveWatchdog?.cancel();
    _keepAliveWatchdog = null;
    await _dataSubscription?.cancel();
    _dataSubscription = null;
    await _statusSubscription?.cancel();
    _statusSubscription = null;
    _connectCompleter = null;
    _isConnected = false;
    _isConnecting = false;
    _isRefreshingSocket = false;
    _userExplicitDisconnect = false;
    _connectedMac = null;
    _connectedName = null;
    _reconnectAttempt = 0;
    _lastDataReceivedAt = null;
    _previousPacketAt = null;
    _lastKeepAliveWriteAt = null;
    _fastPacketStreak = 0;
    _observedContinuousStream = false;
    _lastReading = null;
    hardwareSupportedOverrideForTest = null;
    nativeConnectOverrideForTest = null;
    nativeDisconnectOverrideForTest = null;
    nativeSocketAliveOverrideForTest = null;
    nativeWriteOverrideForTest = null;
    reconnectBaseDelayForTest = const Duration(seconds: 2);
    heartbeatSilenceThresholdForTest = const Duration(seconds: 12);
    continuousStallThresholdForTest = const Duration(seconds: 25);
  }
}
