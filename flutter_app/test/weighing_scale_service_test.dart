import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_pos/core/services/scale_data_parser.dart';
import 'package:shop_pos/core/services/weighing_scale_service.dart';
import 'package:shop_pos/providers/weighing_scale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('⚖️ WeighingScaleService & Provider Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await WeighingScaleService.instance.resetForTest();
    });

    tearDown(() async {
      await WeighingScaleService.instance.resetForTest();
    });

    test('WeighingScaleService initializes with default settings', () async {
      final service = WeighingScaleService.instance;
      await service.init();

      expect(service.protocol, ScaleProtocol.autoDetect);
      expect(service.autoFillDialog, isTrue);
      expect(service.autoAddOnStable, isFalse);
      expect(service.keepAlivePing, isTrue);
    });

    test('Simulate reading updates stream and lastReading', () async {
      final service = WeighingScaleService.instance;
      await service.init();

      ScaleReading? emittedReading;
      final sub = service.onReading.listen((reading) {
        emittedReading = reading;
      });

      service.simulateReading(2.450, isStable: true);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(emittedReading, isNotNull);
      expect(emittedReading!.weight, 2.450);
      expect(emittedReading!.isStable, isTrue);
      expect(service.lastReading?.weight, 2.450);

      await sub.cancel();
    });

    test('WeighingScaleProvider updates liveWeight on simulation', () async {
      final provider = WeighingScaleProvider();
      await Future.delayed(const Duration(milliseconds: 20));

      provider.simulateWeight(3.750, isStable: true);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(provider.liveWeight, 3.750);
      expect(provider.isStable, isTrue);

      // Test Tare
      await provider.tare();
      expect(provider.liveWeight, 0.0);
      provider.dispose();
    });

    test('Settings toggle updates persistence including keepAlivePing', () async {
      final provider = WeighingScaleProvider();
      await Future.delayed(const Duration(milliseconds: 20));

      await provider.setProtocol(ScaleProtocol.phoenixNitiraj);
      expect(provider.protocol, ScaleProtocol.phoenixNitiraj);

      await provider.toggleAutoAdd(true);
      expect(provider.autoAddOnStable, isTrue);

      await provider.setUnitMode(ScaleUnitMode.gramsToKg);
      expect(provider.unitMode, ScaleUnitMode.gramsToKg);

      await provider.toggleKeepAlivePing(false);
      expect(provider.keepAlivePing, isFalse);
      provider.dispose();
    });

    test('WeighingScaleProvider calculates liveWeightGrams correctly', () async {
      final provider = WeighingScaleProvider();
      await Future.delayed(const Duration(milliseconds: 20));

      provider.simulateWeight(0.540, isStable: true);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(provider.liveWeight, 0.540);
      expect(provider.liveWeightGrams, closeTo(540.0, 0.001));
      provider.dispose();
    });

    test('Persistent auto-reconnect retries repeatedly across failed attempts until scale wakes up', () async {
      final service = WeighingScaleService.instance;
      service.hardwareSupportedOverrideForTest = true;
      service.reconnectBaseDelayForTest = const Duration(milliseconds: 25);
      service.nativeDisconnectOverrideForTest = () async => true;
      service.nativeSocketAliveOverrideForTest = () async => service.isConnected;

      int connectAttempts = 0;
      service.nativeConnectOverrideForTest = (mac, uuid) async {
        connectAttempts++;
        // Initial connect (#1) succeeds, next 2 reconnect attempts (#2, #3) fail, #4 succeeds!
        return connectAttempts == 1 || connectAttempts >= 4;
      };

      await service.init();
      final initialOk = await service.connect('AA:BB:CC:DD:EE:FF', name: 'Mandi Scale');
      expect(initialOk, isTrue);
      expect(service.isConnected, isTrue);

      // Simulate native RFCOMM/ACL drop
      service.simulateNativeStatusForTest(0);
      expect(service.isConnected, isFalse);
      expect(service.isReconnecting, isTrue);

      // Wait for persistent retries to recover automatically
      await Future.delayed(const Duration(milliseconds: 450));
      expect(connectAttempts, 4);
      expect(service.isConnected, isTrue);
      expect(service.isReconnecting, isFalse);
    });

    test('Explicit user disconnect cancels auto-reconnect permanently', () async {
      final service = WeighingScaleService.instance;
      service.hardwareSupportedOverrideForTest = true;
      service.reconnectBaseDelayForTest = const Duration(milliseconds: 20);
      service.nativeDisconnectOverrideForTest = () async => true;
      service.nativeSocketAliveOverrideForTest = () async => false;

      int connectAttempts = 0;
      service.nativeConnectOverrideForTest = (mac, uuid) async {
        connectAttempts++;
        return connectAttempts == 1;
      };

      await service.init();
      expect(await service.connect('AA:BB:CC:DD:EE:FF', name: 'Kirana Scale'), isTrue);

      await service.disconnect(userExplicit: true);
      expect(service.isConnected, isFalse);
      expect(service.isReconnecting, isFalse);

      // Even if native emits status 0 or BT adapter turns ON, user explicit disconnect is respected
      service.simulateNativeStatusForTest(0);
      service.simulateNativeStatusForTest(3);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(connectAttempts, 1);
    });

    test('Watchdog detects dead socket, sends silent keep-alive ping, and refreshes stalled stream', () async {
      final service = WeighingScaleService.instance;
      service.hardwareSupportedOverrideForTest = true;
      service.reconnectBaseDelayForTest = const Duration(milliseconds: 20);
      service.heartbeatSilenceThresholdForTest = const Duration(seconds: 10);
      service.continuousStallThresholdForTest = const Duration(seconds: 20);
      service.nativeDisconnectOverrideForTest = () async => true;

      int connectCount = 0;
      bool socketAlive = true;
      final List<String> writes = [];

      service.nativeConnectOverrideForTest = (mac, uuid) async {
        connectCount++;
        return true;
      };
      service.nativeSocketAliveOverrideForTest = () async => socketAlive;
      service.nativeWriteOverrideForTest = (msg) async {
        writes.add(msg);
        return true;
      };

      await service.init();
      await service.connect('11:22:33:44:55:66', name: 'Essae Scale');
      expect(connectCount, 1);

      // 1. Idle silence >= 12s -> sends safe CRLF keep-alive without disconnecting
      service.backdateLastDataForTest(
        DateTime.now().subtract(const Duration(seconds: 12)),
        observedContinuous: false,
      );
      await service.runWatchdogTickForTest();
      expect(writes, ['\r\n']);
      expect(connectCount, 1);

      // 2. Continuous stream completely frozen > 20s -> triggers seamless refresh
      service.backdateLastDataForTest(
        DateTime.now().subtract(const Duration(seconds: 25)),
        observedContinuous: true,
      );
      await service.runWatchdogTickForTest();
      expect(connectCount, 2);

      // 3. Dead socket reported by native isSocketAlive() -> immediately drops & auto-reconnects
      socketAlive = false;
      await service.runWatchdogTickForTest();
      expect(service.isConnected, isFalse);
      socketAlive = true;
      await Future.delayed(const Duration(milliseconds: 80));
      expect(connectCount, 3);
      expect(service.isConnected, isTrue);
    });

    test('AppLifecycleState.resumed triggers ensureConnected on WeighingScaleProvider', () async {
      final service = WeighingScaleService.instance;
      service.hardwareSupportedOverrideForTest = true;
      service.nativeDisconnectOverrideForTest = () async => true;
      bool socketAlive = true;
      int connectCount = 0;
      service.nativeConnectOverrideForTest = (mac, uuid) async {
        connectCount++;
        return true;
      };
      service.nativeSocketAliveOverrideForTest = () async => socketAlive;

      SharedPreferences.setMockInitialValues({
        'saved_scale_mac': 'AA:11:22:33:44:55',
        'saved_scale_name': 'Saved Scale',
      });

      final provider = WeighingScaleProvider();
      await Future.delayed(const Duration(milliseconds: 40));
      expect(connectCount, 1);
      expect(provider.isConnected, isTrue);

      // Simulate scale receiving weight and then dying while app was backgrounded
      service.simulateIncomingBytesForTest(Uint8List.fromList('ST,GS,+002.500kg\r\n'.codeUnits));
      await Future.delayed(const Duration(milliseconds: 15));
      expect(provider.liveWeight, 2.500);

      socketAlive = false;
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future.delayed(const Duration(milliseconds: 30));
      expect(provider.isConnected, isFalse);

      socketAlive = true;
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future.delayed(const Duration(milliseconds: 40));
      expect(connectCount, 2);
      expect(provider.isConnected, isTrue);

      provider.dispose();
    });
  });
}
