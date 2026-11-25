import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_pos/core/services/update_service.dart';
import 'package:shop_pos/core/services/contact_service.dart';
import 'package:shop_pos/providers/weighing_scale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('🚀 v1.7.9 Release & Features Verification', () {
    test('UpdateService has correct release version constant', () {
      expect(UpdateService.currentVersion, '1.7.9');
    });

    test('Semantic version comparison behaves accurately', () {
      expect(UpdateService.isNewerVersion('1.7.9', '1.7.8'), isFalse);
      expect(UpdateService.isNewerVersion('1.7.9', '1.7.9'), isFalse);
      expect(UpdateService.isNewerVersion('1.7.9', '1.7.10'), isTrue);
      expect(UpdateService.isNewerVersion('1.7.9', 'v1.7.9'), isFalse);
      expect(UpdateService.isNewerVersion('1.7.9', 'v1.7.10'), isTrue);
    });

    test('ContactService cleans Indian phone numbers correctly', () {
      expect(ContactService.cleanPhoneNumber('+91 98765-43210'), '9876543210');
      expect(ContactService.cleanPhoneNumber('09876543210'), '9876543210');
      expect(ContactService.cleanPhoneNumber('9876543210'), '9876543210');
      expect(ContactService.cleanPhoneNumber(''), '');
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

    test('Android XML files and contacts manifest permissions exist', () {
      final filepaths = File('android/app/src/main/res/xml/filepaths.xml');
      expect(filepaths.existsSync(), isTrue, reason: 'filepaths.xml must exist for OTA FileProvider');

      final manifest = File('android/app/src/main/AndroidManifest.xml');
      expect(manifest.existsSync(), isTrue);
      final manifestContent = manifest.readAsStringSync();
      expect(manifestContent.contains('android.permission.READ_CONTACTS'), isTrue);
      expect(manifestContent.contains('android.permission.WRITE_CONTACTS'), isTrue);
      expect(manifestContent.contains('sk.fourq.otaupdate.OtaUpdateFileProvider'), isTrue);
      expect(manifestContent.contains('sk.fourq.otaupdate.InstallResultReceiver'), isTrue);
    });
  });
}
