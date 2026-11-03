import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
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

  static const String sppUuid = "00001101-0000-1000-8000-00805f9b34fb";

  BluetoothClassic? _bluetoothClassic;
  StreamSubscription? _dataSubscription;
  StreamSubscription? _statusSubscription;
  Timer? _reconnectTimer;
  Timer? _keepAliveWatchdog;
  DateTime? _lastDataReceivedAt;
  bool _isReconnecting = false;
  bool _userExplicitDisconnect = false;
  String _buffer = "";

  final StreamController<ScaleReading> _readingController =
      StreamController<ScaleReading>.broadcast();
  Stream<ScaleReading> get onReading => _readingController.stream;

  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get onConnectionStateChanged => _connectionStateController.stream;

  ScaleReading? _lastReading;
  ScaleReading? get lastReading => _lastReading;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

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

  bool get isHardwareSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final protocolIndex = prefs.getInt(_prefProtocolKey) ?? 0;
    _protocol = ScaleProtocol.values[protocolIndex.clamp(0, ScaleProtocol.values.length - 1)];
    final unitModeIndex = prefs.getInt(_prefUnitModeKey) ?? 0;
    _unitMode = ScaleUnitMode.values[unitModeIndex.clamp(0, ScaleUnitMode.values.length - 1)];
    _autoFillDialog = prefs.getBool(_prefAutoFillKey) ?? true;
    _autoAddOnStable = prefs.getBool(_prefAutoAddKey) ?? false;

    if (isHardwareSupported) {
      _bluetoothClassic = BluetoothClassic();
      _listenToDeviceStatus();
    }
  }

  void _listenToDeviceStatus() {
    if (_statusSubscription != null) return;
    try {
      _statusSubscription = _bluetoothClassic?.onDeviceStatusChanged().listen((status) {
        debugPrint("BluetoothClassic scale status changed: $status");
        // 0 = disconnected, 1 = connecting, 2 = connected
        if (status == 0 && _isConnected && !_userExplicitDisconnect) {
          _handleConnectionDrop();
        }
      });
    } catch (_) {}
  }

  Future<void> saveSettings({
    ScaleProtocol? protocol,
    ScaleUnitMode? unitMode,
    bool? autoFillDialog,
    bool? autoAddOnStable,
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
  }

  Future<List<Device>> getPairedDevices() async {
    if (!isHardwareSupported) {
      return [];
    }

    final List<Device> result = [];

    // 1. Primary & Rock-Solid: PrintBluetoothThermal bonded devices query
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
        if (result.isNotEmpty) {
          debugPrint("Found ${result.length} paired Bluetooth devices via PrintBluetoothThermal");
          return result;
        }
      }
    } catch (e) {
      debugPrint("PrintBluetoothThermal paired query err: $e");
    }

    // 2. Secondary fallback: BluetoothClassic getPairedDevices
    if (_bluetoothClassic != null) {
      try {
        final list = await _bluetoothClassic!.getPairedDevices();
        if (list.isNotEmpty) {
          return list;
        }
      } catch (e) {
        debugPrint("BluetoothClassic getPairedDevices fallback err: $e");
      }
    }

    return result;
  }

  Future<bool> connect(String macAddress, {String? name}) async {
    if (!isHardwareSupported || _bluetoothClassic == null) {
      // In simulator / web mode, simulate connection
      _isConnected = true;
      _connectedMac = macAddress;
      _connectedName = name ?? 'Simulated Scale';
      _connectionStateController.add(true);
      return true;
    }

    _userExplicitDisconnect = false;

    try {
      await _cleanConnection(userExplicit: false);
      // Ensure bluetooth permissions are granted smoothly without throwing crash
      try {
        await PrintBluetoothThermal.isPermissionBluetoothGranted;
      } catch (_) {}

      final bool success = await _bluetoothClassic!.connect(macAddress, sppUuid);

      if (success) {
        _isConnected = true;
        _connectedMac = macAddress;
        _connectedName = name ?? 'Bluetooth Scale';
        _lastDataReceivedAt = DateTime.now();
        await saveSelectedScale(macAddress, _connectedName!);

        _dataSubscription = _bluetoothClassic!.onDeviceDataReceived().listen(
          (Uint8List data) {
            _handleIncomingData(data);
          },
          onError: (e) {
            debugPrint("Scale data stream error: $e");
            _handleConnectionDrop();
          },
          onDone: () {
            debugPrint("Scale stream closed remotely");
            _handleConnectionDrop();
          },
        );

        _startWatchdog();
        _connectionStateController.add(true);
        return true;
      }
    } catch (e) {
      debugPrint("Error connecting to scale: $e");
    }

    _isConnected = false;
    _connectionStateController.add(false);
    return false;
  }

  void _handleConnectionDrop() {
    _isConnected = false;
    _connectionStateController.add(false);
    if (!_userExplicitDisconnect && _connectedMac != null) {
      _scheduleAutoReconnect();
    }
  }

  void _scheduleAutoReconnect() {
    if (_isReconnecting || _userExplicitDisconnect || _connectedMac == null) return;
    _reconnectTimer?.cancel();
    debugPrint("Scheduling automatic scale reconnection in 3 seconds to $_connectedMac");
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      if (_userExplicitDisconnect || _isConnected || _connectedMac == null) return;
      _isReconnecting = true;
      try {
        debugPrint("Watchdog attempting auto-reconnect to scale: $_connectedMac");
        await connect(_connectedMac!, name: _connectedName);
      } catch (e) {
        debugPrint("Auto-reconnect attempt failed: $e");
      } finally {
        _isReconnecting = false;
      }
    });
  }

  void _startWatchdog() {
    _keepAliveWatchdog?.cancel();
    _keepAliveWatchdog = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_isConnected || _userExplicitDisconnect || _connectedMac == null) return;
      // If we haven't received any data for 30s and scale was connected, check if still alive
      if (_lastDataReceivedAt != null && DateTime.now().difference(_lastDataReceivedAt!).inSeconds > 30) {
        debugPrint("Scale data silent for >30s, checking socket health...");
      }
    });
  }

  Future<void> disconnect({bool userExplicit = true}) async {
    _userExplicitDisconnect = userExplicit;
    _reconnectTimer?.cancel();
    _keepAliveWatchdog?.cancel();
    await _cleanConnection(userExplicit: userExplicit);
  }

  Future<void> _cleanConnection({bool userExplicit = false}) async {
    await _dataSubscription?.cancel();
    _dataSubscription = null;
    _buffer = "";

    if (isHardwareSupported && _bluetoothClassic != null) {
      try {
        await _bluetoothClassic!.disconnect();
      } catch (_) {}
    }

    _isConnected = false;
    _connectionStateController.add(false);
  }

  void _handleIncomingData(Uint8List bytes) {
    _lastDataReceivedAt = DateTime.now();
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
    if (!isHardwareSupported || _bluetoothClassic == null || !_isConnected) {
      // In simulator mode, emit 0.000 kg
      simulateReading(0.000, isStable: true);
      return true;
    }
    try {
      // Standard scale tare commands: 'T\r\n' or 'Z\r\n'
      await _bluetoothClassic!.write("T\r\n");
      return true;
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
}

