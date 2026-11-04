import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// Feature vector length:
/// 16 Hue bins (0-360 deg)
/// 4 Saturation bins
/// 4 Value/Brightness bins
/// 6 Dominant Color percentages (Red, Green, Yellow/Brown, Purple, White, Orange)
/// 1 Texture/Edge Complexity metric
/// Total = 31 dimensions.

class ClassFeatures {
  final String classId;
  final String englishName;
  final String localLabel;
  final String category;
  final List<double> featureVector; // 31 dims
  final Map<String, double> dominantColors;
  final int sampleCount;

  ClassFeatures({
    required this.classId,
    required this.englishName,
    required this.localLabel,
    required this.category,
    required this.featureVector,
    required this.dominantColors,
    required this.sampleCount,
  });

  Map<String, dynamic> toJson() => {
    'class_id': classId,
    'english_name': englishName,
    'local_label': localLabel,
    'category': category,
    'vector': featureVector.map((v) => double.parse(v.toStringAsFixed(4))).toList(),
    'dominant_colors': dominantColors.map((k, v) => MapEntry(k, double.parse(v.toStringAsFixed(4)))),
    'sample_count': sampleCount,
  };
}

List<double> extractFeatures(img.Image decoded) {
  // Center crop 75% region (tray area)
  final cropW = (decoded.width * 0.75).toInt();
  final cropH = (decoded.height * 0.75).toInt();
  final cropX = ((decoded.width - cropW) / 2).toInt();
  final cropY = ((decoded.height - cropH) / 2).toInt();

  final cropped = img.copyCrop(decoded, x: cropX, y: cropY, width: cropW, height: cropH);
  final thumb = img.copyResize(cropped, width: 128, height: 128);

  final hueBins = List<double>.filled(16, 0.0);
  final satBins = List<double>.filled(4, 0.0);
  final valBins = List<double>.filled(4, 0.0);

  int redCount = 0;
  int greenCount = 0;
  int yellowBrownCount = 0;
  int purpleCount = 0;
  int whiteCount = 0;
  int orangeCount = 0;

  double totalDiff = 0.0;
  int totalPixels = 0;

  for (int y = 0; y < thumb.height; y++) {
    for (int x = 0; x < thumb.width; x++) {
      final p = thumb.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();

      final maxC = math.max(r, math.max(g, b));
      final minC = math.min(r, math.min(g, b));
      final delta = maxC - minC;

      // Simple horizontal difference for edge/texture complexity
      if (x > 0) {
        final prev = thumb.getPixel(x - 1, y);
        totalDiff += (r - prev.r).abs() + (g - prev.g).abs() + (b - prev.b).abs();
      }

      if (maxC < 30) continue; // Dark background / shadow
      totalPixels++;

      // Saturation (0..1)
      final sat = maxC == 0 ? 0.0 : delta / maxC;
      final val = maxC / 255.0;

      // Saturation binning
      int sBin = (sat * 4).floor().clamp(0, 3);
      satBins[sBin]++;

      // Value binning
      int vBin = (val * 4).floor().clamp(0, 3);
      valBins[vBin]++;

      // White/cream detection
      if (sat < 0.18 && val > 0.65) {
        whiteCount++;
      }

      // Hue calculation (0..360)
      double hue = 0.0;
      if (delta > 0) {
        if (maxC == r) {
          hue = ((g - b) / delta) % 6;
        } else if (maxC == g) {
          hue = ((b - r) / delta) + 2;
        } else {
          hue = ((r - g) / delta) + 4;
        }
        hue *= 60;
        if (hue < 0) hue += 360;
      }

      // 16-bin Hue
      int hBin = (hue / (360 / 16)).floor().clamp(0, 15);
      hueBins[hBin]++;

      // Color categories
      if (sat >= 0.15) {
        if ((hue >= 345 || hue <= 15)) {
          redCount++;
        } else if (hue > 15 && hue <= 45) {
          orangeCount++;
        } else if (hue > 45 && hue <= 80) {
          yellowBrownCount++;
        } else if (hue > 80 && hue <= 170) {
          greenCount++;
        } else if (hue > 260 && hue <= 340) {
          purpleCount++;
        } else {
          yellowBrownCount++;
        }
      }
    }
  }

  if (totalPixels == 0) totalPixels = 1;

  // Normalize histograms
  for (int i = 0; i < 16; i++) hueBins[i] /= totalPixels;
  for (int i = 0; i < 4; i++) satBins[i] /= totalPixels;
  for (int i = 0; i < 4; i++) valBins[i] /= totalPixels;

  final redPct = redCount / totalPixels;
  final greenPct = greenCount / totalPixels;
  final yellowBrownPct = yellowBrownCount / totalPixels;
  final purplePct = purpleCount / totalPixels;
  final whitePct = whiteCount / totalPixels;
  final orangePct = orangeCount / totalPixels;

  final textureScore = (totalDiff / (thumb.width * thumb.height * 255 * 3)).clamp(0.0, 1.0);

  return [
    ...hueBins,
    ...satBins,
    ...valBins,
    redPct,
    greenPct,
    yellowBrownPct,
    purplePct,
    whitePct,
    orangePct,
    textureScore,
  ];
}

void main() async {
  print('🚀 Starting AI Smart Weighing POS Model Training...');
  final datasetDir = Directory('../ai_smart_weighing_pos_dataset');
  if (!datasetDir.existsSync()) {
    print('❌ Error: Dataset directory not found at ../ai_smart_weighing_pos_dataset');
    exit(1);
  }

  // Read class map
  final classMapFile = File('${datasetDir.path}/class_map.csv');
  final lines = classMapFile.readAsLinesSync();
  final classMap = <String, Map<String, String>>{};

  for (int i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final parts = line.split(',');
    if (parts.length >= 4) {
      classMap[parts[0].trim()] = {
        'english_name': parts[1].trim(),
        'local_label': parts[2].trim(),
        'category': parts[3].trim(),
      };
    }
  }

  print('📋 Loaded ${classMap.length} classes from class_map.csv');

  final List<ClassFeatures> trainedClasses = [];

  // Locations to scan: fresh_produce and optional_packaged_products
  final searchDirs = [
    Directory('${datasetDir.path}/images/fresh_produce'),
    Directory('${datasetDir.path}/images/optional_packaged_products'),
  ];

  int totalImagesProcessed = 0;

  for (final sDir in searchDirs) {
    if (!sDir.existsSync()) continue;
    final classDirs = sDir.listSync().whereType<Directory>().toList();

    for (final cDir in classDirs) {
      final classId = cDir.uri.pathSegments[cDir.uri.pathSegments.length - 2];
      final meta = classMap[classId] ?? {
        'english_name': classId,
        'local_label': classId,
        'category': 'produce',
      };

      final imageFiles = cDir.listSync().whereType<File>().where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.png')).toList();

      if (imageFiles.isEmpty) {
        print('⚠️ Warning: No images found for $classId');
        continue;
      }

      final vectorSum = List<double>.filled(31, 0.0);
      final domColorSum = <String, double>{
        'red': 0.0,
        'green': 0.0,
        'yellow_brown': 0.0,
        'purple': 0.0,
        'white': 0.0,
        'orange': 0.0,
      };

      int validImages = 0;

      for (final imgFile in imageFiles) {
        try {
          final bytes = imgFile.readAsBytesSync();
          final decoded = img.decodeImage(bytes);
          if (decoded != null) {
            final feats = extractFeatures(decoded);
            for (int i = 0; i < 31; i++) {
              vectorSum[i] += feats[i];
            }
            domColorSum['red'] = (domColorSum['red'] ?? 0) + feats[24];
            domColorSum['green'] = (domColorSum['green'] ?? 0) + feats[25];
            domColorSum['yellow_brown'] = (domColorSum['yellow_brown'] ?? 0) + feats[26];
            domColorSum['purple'] = (domColorSum['purple'] ?? 0) + feats[27];
            domColorSum['white'] = (domColorSum['white'] ?? 0) + feats[28];
            domColorSum['orange'] = (domColorSum['orange'] ?? 0) + feats[29];

            validImages++;
            totalImagesProcessed++;
          }
        } catch (e) {
          print('Error processing ${imgFile.path}: $e');
        }
      }

      if (validImages > 0) {
        final meanVector = vectorSum.map((v) => v / validImages).toList();
        final meanDomColors = domColorSum.map((k, v) => MapEntry(k, v / validImages));

        trainedClasses.add(ClassFeatures(
          classId: classId,
          englishName: meta['english_name']!,
          localLabel: meta['local_label']!,
          category: meta['category']!,
          featureVector: meanVector,
          dominantColors: meanDomColors,
          sampleCount: validImages,
        ));
      }
    }
  }

  print('✅ Successfully extracted features from $totalImagesProcessed images across ${trainedClasses.length} classes!');

  // Export to assets/data/ai_vision_model.json
  final modelOutput = {
    'version': '1.0.0',
    'timestamp': DateTime.now().toIso8601String(),
    'model_name': 'Yadav POS Smart Vision Centroid Model',
    'vector_dimensions': 31,
    'total_classes': trainedClasses.length,
    'classes': trainedClasses.map((c) => c.toJson()).toList(),
  };

  final outDir = Directory('assets/data');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final outFile = File('assets/data/ai_vision_model.json');
  outFile.writeAsStringSync(jsonEncode(modelOutput));
  print('💾 Saved trained AI model weights to ${outFile.path} (${outFile.lengthSync()} bytes)');
}

