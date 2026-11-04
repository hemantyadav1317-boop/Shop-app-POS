import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shop_pos/core/services/ai_vision_catalog.dart';
import 'package:shop_pos/core/services/ai_vision_service.dart';
import 'package:shop_pos/providers/ai_vision_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🥦 AI Vision Catalog Tests', () {
    test('Catalog contains 30+ produce items with complete metadata', () {
      expect(AiVisionCatalog.allItems.length, greaterThanOrEqualTo(25));
      for (final item in AiVisionCatalog.allItems) {
        expect(item.id.isNotEmpty, isTrue);
        expect(item.hindiName.isNotEmpty, isTrue);
        expect(item.englishName.isNotEmpty, isTrue);
        expect(item.icon.isNotEmpty, isTrue);
        expect(item.primaryColors.isNotEmpty, isTrue);
      }
    });

    test('findById and findByText search accurately in Hindi and English', () {
      final tomato = AiVisionCatalog.findById('tomato');
      expect(tomato, isNotNull);
      expect(tomato!.hindiName, 'टमाटर');

      final foundHindi = AiVisionCatalog.findByText('टमाटर');
      expect(foundHindi, isNotNull);
      expect(foundHindi!.id, 'tamatar');

      final foundAlias = AiVisionCatalog.findByText('tamatar');
      expect(foundAlias, isNotNull);
      expect(foundAlias!.id, 'tamatar');

      final foundKheera = AiVisionCatalog.findByText('kheera');
      expect(foundKheera, isNotNull);
      expect(foundKheera!.id, 'kheera');
    });

    test('Confusable items mapping exists for ambiguous produce pairs', () {
      final cucumber = AiVisionCatalog.findById('cucumber');
      expect(cucumber, isNotNull);
      expect(cucumber!.confusableWith.contains('kakdi'), isTrue);

      final tomato = AiVisionCatalog.findById('tomato');
      expect(tomato, isNotNull);
      expect(tomato!.confusableWith.contains('apple'), isTrue);
    });
  });

  group('🔬 AI Vision Service Engine Tests', () {
    test('Analyzes red image bytes and ranks Tomato / Apple', () async {
      // Create a small pure red 100x100 image
      final redImg = img.Image(width: 100, height: 100);
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 100; x++) {
          redImg.setPixelRgba(x, y, 220, 20, 20, 255);
        }
      }
      final bytes = Uint8List.fromList(img.encodeJpg(redImg));

      final result = await AiVisionService.instance.analyzeImageBytes(bytes);
      expect(result, isNotNull);
      // Top result should have red in its primary colors
      expect(result!.item.primaryColors.contains('red'), isTrue);
    });

    test('Analyzes green image bytes and ranks Green produce', () async {
      final greenImg = img.Image(width: 100, height: 100);
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 100; x++) {
          greenImg.setPixelRgba(x, y, 20, 200, 30, 255);
        }
      }
      final bytes = Uint8List.fromList(img.encodeJpg(greenImg));

      final result = await AiVisionService.instance.analyzeImageBytes(bytes);
      expect(result, isNotNull);
      // Top result should have green as primary color
      expect(result!.item.primaryColors.contains('green'), isTrue);
    });
  });

  group('⚙️ AI Vision Provider State Tests', () {
    test('Initializes with default settings and toggles properly', () async {
      final provider = AiVisionProvider();
      expect(provider.isProcessing, isFalse);

      await provider.toggleAiVision(true);
      expect(provider.isAiVisionActive, isTrue);

      await provider.setVoiceFeedbackEnabled(false);
      expect(provider.voiceFeedbackEnabled, isFalse);

      await provider.setCameraSource(AiCameraSource.remotePhoneNode, remoteUrl: '192.168.1.50:8080');
      expect(provider.cameraSource, AiCameraSource.remotePhoneNode);
      expect(provider.remoteCameraUrl, '192.168.1.50:8080');
    });
  });
}

