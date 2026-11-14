import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final inputPath = r'C:\Users\hemny\.gemini\antigravity\brain\7b28a530-def2-4e26-ba14-ede454d67735\.user_uploaded\media_1794668867759_a1925adc.jpg';
  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    print('Error: Input file does not exist: $inputPath');
    exit(1);
  }

  final bytes = inputFile.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Error: Could not decode image');
    exit(1);
  }

  print('Decoded source image: ${image.width}x${image.height}');

  // Targets to generate
  final targets = <String, int>{
    // 1. Flutter app asset icon
    'assets/icons/app_icon.png': 1024,

    // 2. Android mipmaps
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,

    // 3. Web icons
    'web/favicon.png': 64,
    'web/icons/Icon-192.png': 192,
    'web/icons/Icon-512.png': 512,
    'web/icons/Icon-maskable-192.png': 192,
    'web/icons/Icon-maskable-512.png': 512,

    // 4. iOS icons
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png': 1024,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png': 20,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png': 40,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png': 60,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png': 29,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png': 58,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png': 87,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png': 40,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png': 80,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png': 120,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png': 120,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png': 180,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png': 76,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png': 152,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png': 167,

    // 5. Root public web assets (Vite / PWA)
    '../public/favicon.png': 64,
    '../public/icons/icon-192.png': 192,
    '../public/icons/icon-512.png': 512,
  };

  for (final entry in targets.entries) {
    final relPath = entry.key;
    final size = entry.value;
    final targetFile = File(relPath);
    if (!targetFile.parent.existsSync()) {
      targetFile.parent.createSync(recursive: true);
    }

    final resized = img.copyResize(
      image,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );

    final pngBytes = img.encodePng(resized);
    targetFile.writeAsBytesSync(pngBytes);
    print('Generated: $relPath (${size}x$size, ${pngBytes.length} bytes)');
  }

  print('\nAll app icons successfully generated!');
}
