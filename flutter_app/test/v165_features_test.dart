import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_pos/core/services/update_service.dart';
import 'package:shop_pos/providers/weighing_scale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('🚀 v1.6.5 Release & In-App Update Verification', () {
    test('UpdateService has correct release version constant', () {
      expect(UpdateService.currentVersion, '1.6.5');
    });

    test('Semantic version comparison behaves accurately', () {
      // Current is 1.6.5
      expect(UpdateService.isNewerVersion('1.6.5', '1.6.4'), isFalse);
      expect(UpdateService.isNewerVersion('1.6.5', '1.6.5'), isFalse);
      expect(UpdateService.isNewerVersion('1.6.5', '1.6.6'), isTrue);
      expect(UpdateService.isNewerVersion('1.6.5', 'v1.6.5'), isFalse);
      expect(UpdateService.isNewerVersion('1.6.5', 'v1.7.0'), isTrue);
    });

    test('WeighingScaleProvider safely maintains disconnected & live weight values', () async {
      final scale = WeighingScaleProvider();
      await Future.delayed(const Duration(milliseconds: 20));
      expect(scale.isConnected, isFalse);
      expect(scale.liveWeight, 0.0);

      scale.simulateWeight(3.125, isStable: true);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(scale.liveWeight, 3.125);
      expect(scale.liveWeight.toStringAsFixed(3), '3.125');
    });

    test('Android XML files and provider manifest entries exist', () {
      final filepaths = File('android/app/src/main/res/xml/filepaths.xml');
      expect(filepaths.existsSync(), isTrue, reason: 'filepaths.xml must exist for OTA FileProvider');
      final filepathsContent = filepaths.readAsStringSync();
      expect(filepathsContent.contains('internal_apk_storage'), isTrue);
      expect(filepathsContent.contains('ota_update/'), isTrue);

      final manifest = File('android/app/src/main/AndroidManifest.xml');
      expect(manifest.existsSync(), isTrue);
      final manifestContent = manifest.readAsStringSync();
      expect(manifestContent.contains('sk.fourq.otaupdate.OtaUpdateFileProvider'), isTrue);
      expect(manifestContent.contains('sk.fourq.otaupdate.InstallResultReceiver'), isTrue);
    });
  });
}
