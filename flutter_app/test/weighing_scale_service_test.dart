import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_pos/core/services/scale_data_parser.dart';
import 'package:shop_pos/core/services/weighing_scale_service.dart';
import 'package:shop_pos/providers/weighing_scale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('⚖️ WeighingScaleService & Provider Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('WeighingScaleService initializes with default settings', () async {
      final service = WeighingScaleService.instance;
      await service.init();

      expect(service.protocol, ScaleProtocol.autoDetect);
      expect(service.autoFillDialog, isTrue);
      expect(service.autoAddOnStable, isFalse);
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
    });

    test('Settings toggle updates persistence', () async {
      final provider = WeighingScaleProvider();
      await Future.delayed(const Duration(milliseconds: 20));

      await provider.setProtocol(ScaleProtocol.phoenixNitiraj);
      expect(provider.protocol, ScaleProtocol.phoenixNitiraj);

      await provider.toggleAutoAdd(true);
      expect(provider.autoAddOnStable, isTrue);

      await provider.setUnitMode(ScaleUnitMode.gramsToKg);
      expect(provider.unitMode, ScaleUnitMode.gramsToKg);
    });

    test('WeighingScaleProvider calculates liveWeightGrams correctly', () async {
      final provider = WeighingScaleProvider();
      await Future.delayed(const Duration(milliseconds: 20));

      provider.simulateWeight(0.540, isStable: true);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(provider.liveWeight, 0.540);
      expect(provider.liveWeightGrams, closeTo(540.0, 0.001));
    });
  });
}

