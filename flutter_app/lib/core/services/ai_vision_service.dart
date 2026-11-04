import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'ai_vision_catalog.dart';
import 'ai_vision_model_data.dart';

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

      // Crop center 75% region (where produce sits on weighing scale tray)
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

          if (x > 0) {
            final prev = thumb.getPixel(x - 1, y);
            totalDiff += (r - prev.r).abs() + (g - prev.g).abs() + (b - prev.b).abs();
          }

          if (maxC < 30) continue; // Dark background
          totalPixels++;

          final sat = maxC == 0 ? 0.0 : delta / maxC;
          final val = maxC / 255.0;

          int sBin = (sat * 4).floor().clamp(0, 3);
          satBins[sBin]++;

          int vBin = (val * 4).floor().clamp(0, 3);
          valBins[vBin]++;

          if (sat < 0.18 && val > 0.65) {
            whiteCount++;
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

          int hBin = (hue / (360 / 16)).floor().clamp(0, 15);
          hueBins[hBin]++;

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

      for (int i = 0; i < 16; i++) {
        hueBins[i] /= totalPixels;
      }
      for (int i = 0; i < 4; i++) {
        satBins[i] /= totalPixels;
      }
      for (int i = 0; i < 4; i++) {
        valBins[i] /= totalPixels;
      }

      final redPct = redCount / totalPixels;
      final greenPct = greenCount / totalPixels;
      final yellowBrownPct = yellowBrownCount / totalPixels;
      final purplePct = purpleCount / totalPixels;
      final whitePct = whiteCount / totalPixels;
      final orangePct = orangeCount / totalPixels;

      final textureScore = (totalDiff / (thumb.width * thumb.height * 255 * 3)).clamp(0.0, 1.0);

      final inputVector = [
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

      // Compute Cosine Similarity against all 83 trained class centroids
      final scoredCandidates = <MapEntry<ProduceItem, double>>[];

      double inputMag = 0.0;
      for (final v in inputVector) {
        inputMag += v * v;
      }
      inputMag = math.sqrt(inputMag);
      if (inputMag == 0) inputMag = 1.0;

      for (final entry in AiVisionModelData.centroids.entries) {
        final classId = entry.key;
        final centroid = entry.value;

        final item = AiVisionCatalog.findById(classId);
        if (item == null) continue;

        double dot = 0.0;
        double centMag = 0.0;
        for (int i = 0; i < inputVector.length && i < centroid.length; i++) {
          dot += inputVector[i] * centroid[i];
          centMag += centroid[i] * centroid[i];
        }
        centMag = math.sqrt(centMag);
        if (centMag == 0) centMag = 1.0;

        double similarity = (dot / (inputMag * centMag)).clamp(0.0, 1.0);

        // Color boost heuristics if primary color clearly dominates
        for (final col in item.primaryColors) {
          if (col == 'red' && redPct > 0.40) similarity += redPct * 0.15;
          if (col == 'green' && greenPct > 0.40) similarity += greenPct * 0.15;
          if ((col == 'yellow' || col == 'brown') && yellowBrownPct > 0.40) similarity += yellowBrownPct * 0.12;
          if (col == 'purple' && purplePct > 0.30) similarity += purplePct * 0.20;
          if (col == 'white' && whitePct > 0.40) similarity += whitePct * 0.15;
          if (col == 'orange' && orangePct > 0.35) similarity += orangePct * 0.15;
        }

        scoredCandidates.add(MapEntry(item, similarity.clamp(0.05, 0.98)));
      }

      scoredCandidates.sort((a, b) => b.value.compareTo(a.value));
      if (scoredCandidates.isEmpty) return null;

      final top1 = scoredCandidates[0];
      final top2 = scoredCandidates.length > 1 ? scoredCandidates[1] : null;
      final top3 = scoredCandidates.length > 2 ? scoredCandidates[2] : null;

      bool isAmbiguous = false;
      final alternatives = <ProduceItem>[];

      if (top2 != null) {
        final scoreDiff = top1.value - top2.value;
        final areConfusable = top1.key.confusableWith.contains(top2.key.id) ||
            top2.key.confusableWith.contains(top1.key.id);

        if (areConfusable && scoreDiff < 0.15) {
          isAmbiguous = true;
          alternatives.add(top1.key);
          alternatives.add(top2.key);
          if (top3 != null && top3.value > 0.65) alternatives.add(top3.key);
        } else if (scoreDiff < 0.08) {
          isAmbiguous = true;
          alternatives.add(top1.key);
          alternatives.add(top2.key);
          if (top3 != null && top3.value > 0.65) alternatives.add(top3.key);
        }
      }

      final confidence = isAmbiguous ? (top1.value * 0.88).clamp(0.55, 0.82) : top1.value;

      return AiRecognitionResult(
        item: top1.key,
        confidence: confidence,
        isAmbiguous: isAmbiguous,
        alternativeItems: alternatives,
        debugDetails: 'Top: ${top1.key.hindiName} (${(top1.value * 100).toInt()}%) | R:${(redPct * 100).toInt()}% G:${(greenPct * 100).toInt()}% Y:${(yellowBrownPct * 100).toInt()}%',
      );
    } catch (e) {
      debugPrint('Error in _decodeAndAnalyze: $e');
      return null;
    }
  }
}
