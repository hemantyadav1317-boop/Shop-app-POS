import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'ai_vision_catalog.dart';

class AiRecognitionResult {
  final ProduceItem item;
  final double confidence; // 0.0 to 1.0
  final bool isAmbiguous;
  final List<ProduceItem> alternativeItems;
  final String debugDetails;
  final DateTime timestamp;

  AiRecognitionResult({
    required this.item,
    required this.confidence,
    this.isAmbiguous = false,
    this.alternativeItems = const [],
    this.debugDetails = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'AiRecognitionResult(item: ${item.hindiName}/${item.englishName}, conf: ${(confidence * 100).toStringAsFixed(1)}%, ambiguous: $isAmbiguous)';
  }
}

class AiVisionService {
  AiVisionService._();
  static final AiVisionService instance = AiVisionService._();

  /// Analyzes JPEG/PNG image bytes and returns the classified produce
  Future<AiRecognitionResult?> analyzeImageBytes(Uint8List bytes) async {
    try {
      // Decode image in background compute / isolate if supported
      final image = await compute(_decodeAndAnalyze, bytes);
      return image;
    } catch (e) {
      debugPrint('AiVisionService analyze error: $e');
      return null;
    }
  }

  /// Direct analysis for already decoded or test environments
  static AiRecognitionResult? _decodeAndAnalyze(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      // Crop center 70% region (where produce sits on weighing scale)
      final cropW = (decoded.width * 0.70).toInt();
      final cropH = (decoded.height * 0.70).toInt();
      final cropX = ((decoded.width - cropW) / 2).toInt();
      final cropY = ((decoded.height - cropH) / 2).toInt();

      final cropped = img.copyCrop(decoded, x: cropX, y: cropY, width: cropW, height: cropH);
      // Resize to standard 160x160 for fast edge/color analysis
      final thumb = img.copyResize(cropped, width: 160, height: 160);

      // Color spectrum bins
      int redCount = 0;
      int greenCount = 0;
      int yellowBrownCount = 0;
      int purpleCount = 0;
      int whiteCount = 0;
      int orangeCount = 0;
      int totalPixels = 0;

      for (int y = 0; y < thumb.height; y += 2) {
        for (int x = 0; x < thumb.width; x += 2) {
          final p = thumb.getPixel(x, y);
          final r = p.r.toInt();
          final g = p.g.toInt();
          final b = p.b.toInt();

          // Convert RGB to HSV
          final maxC = math.max(r, math.max(g, b));
          final minC = math.min(r, math.min(g, b));
          final delta = maxC - minC;

          if (maxC < 35) continue; // Skip very dark shadow
          totalPixels++;

          if (delta < 25 && maxC > 180) {
            // Low saturation, high brightness -> White/Cream (Garlic, Cauliflower, Radish, Salt)
            whiteCount++;
            continue;
          }

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

          // Binning according to Hue (degrees)
          if ((hue >= 345 || hue <= 15) && delta > 30) {
            redCount++; // Red: Tomato, Apple, Pomegranate
          } else if (hue > 15 && hue <= 45 && delta > 30) {
            orangeCount++; // Orange: Carrot, Orange, Papaya
          } else if (hue > 45 && hue <= 80 && delta > 25) {
            yellowBrownCount++; // Yellow/Brown: Potato, Ginger, Banana, Onion outer
          } else if (hue > 80 && hue <= 170 && delta > 25) {
            greenCount++; // Green: Chilli, Cucumber, Kakdi, Bhindi, Capsicum, Palak
          } else if (hue > 260 && hue <= 340 && delta > 20) {
            purpleCount++; // Purple: Brinjal, Onion
          } else {
            yellowBrownCount++; // Earthy tones
          }
        }
      }

      if (totalPixels == 0) totalPixels = 1;

      final redPct = redCount / totalPixels;
      final greenPct = greenCount / totalPixels;
      final yellowBrownPct = yellowBrownCount / totalPixels;
      final purplePct = purpleCount / totalPixels;
      final whitePct = whiteCount / totalPixels;
      final orangePct = orangeCount / totalPixels;

      // Score each catalog item against the visual metrics
      final scores = <ProduceItem, double>{};

      for (final item in AiVisionCatalog.allItems) {
        double score = 0.20; // Base baseline

        // Color score
        for (final col in item.primaryColors) {
          if (col == 'red') score += redPct * 0.50;
          if (col == 'green') score += greenPct * 0.50;
          if (col == 'yellow' || col == 'brown') score += yellowBrownPct * 0.45;
          if (col == 'purple') score += purplePct * 0.55;
          if (col == 'white') score += whitePct * 0.50;
          if (col == 'orange') score += orangePct * 0.50;
        }

        // Texture / shape profile
        if (item.shapeType == 'elongated' && greenPct > 0.40) {
          if (['cucumber', 'kakdi', 'bottle_gourd', 'green_chilli', 'ladyfinger'].contains(item.id)) {
            score += 0.15;
          }
        }
        if (item.shapeType == 'round' && redPct > 0.35) {
          if (['tomato', 'apple', 'pomegranate'].contains(item.id)) {
            score += 0.20;
          }
        }
        if (item.shapeType == 'round' && yellowBrownPct > 0.35) {
          if (['potato', 'onion'].contains(item.id)) {
            score += 0.20;
          }
        }

        scores[item] = score.clamp(0.05, 0.98);
      }

      // Sort by descending score
      final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      if (sorted.isEmpty) return null;

      final top1 = sorted[0];
      final top2 = sorted.length > 1 ? sorted[1] : null;

      // Check for ambiguity (e.g. Cucumber vs Kakdi, or Raw Mango vs Guava)
      bool isAmbiguous = false;
      List<ProduceItem> alternatives = [];

      if (top2 != null) {
        final scoreDiff = top1.value - top2.value;
        final areConfusable = top1.key.confusableWith.contains(top2.key.id) ||
            top2.key.confusableWith.contains(top1.key.id);

        if (areConfusable && scoreDiff < 0.20) {
          isAmbiguous = true;
          alternatives = [top1.key, top2.key];
        } else if (scoreDiff < 0.08) {
          isAmbiguous = true;
          alternatives = [top1.key, top2.key];
        }
      }

      final confidence = isAmbiguous ? (top1.value * 0.85).clamp(0.50, 0.79) : top1.value;

      return AiRecognitionResult(
        item: top1.key,
        confidence: confidence,
        isAmbiguous: isAmbiguous,
        alternativeItems: alternatives,
        debugDetails: 'R:${(redPct * 100).toInt()}% G:${(greenPct * 100).toInt()}% Y/B:${(yellowBrownPct * 100).toInt()}%',
      );
    } catch (e) {
      debugPrint('Error in _decodeAndAnalyze: $e');
      return null;
    }
  }
}
