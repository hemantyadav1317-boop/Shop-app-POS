import 'package:flutter/foundation.dart';

enum ScaleProtocol {
  autoDetect,
  standardSpp,
  essae,
  phoenixNitiraj,
  casEagle,
}

class ScaleReading {
  final double weight;
  final bool isStable;
  final String unit;
  final String rawData;
  final DateTime timestamp;

  const ScaleReading({
    required this.weight,
    required this.isStable,
    required this.unit,
    required this.rawData,
    required this.timestamp,
  });

  @override
  String toString() =>
      'ScaleReading(weight: $weight $unit, isStable: $isStable, raw: "$rawData")';
}

class ScaleDataParser {
  /// Parses a raw string received from a Bluetooth weighing scale
  static ScaleReading? parse(String raw, ScaleProtocol protocol) {
    final clean = raw.trim();
    if (clean.isEmpty) return null;

    switch (protocol) {
      case ScaleProtocol.essae:
        return _parseEssae(clean);
      case ScaleProtocol.phoenixNitiraj:
        return _parsePhoenix(clean);
      case ScaleProtocol.casEagle:
        return _parseCasEagle(clean);
      case ScaleProtocol.standardSpp:
        return _parseStandardSpp(clean);
      case ScaleProtocol.autoDetect:
        return _parseAutoDetect(clean);
    }
  }

  /// Auto-Detect: Tries protocols in sequence or uses universal number extraction
  static ScaleReading? _parseAutoDetect(String raw) {
    // 1. Try Phoenix / Nitiraj format (ST,GS,+001.250kg or US,GS,...)
    if (raw.contains('ST,') || raw.contains('US,') || raw.contains('GS,')) {
      final res = _parsePhoenix(raw);
      if (res != null) return res;
    }

    // 2. Try Essae STX/ETX or Essae format
    if (raw.contains('\x02') || raw.contains('\x03') || raw.startsWith('=')) {
      final res = _parseEssae(raw);
      if (res != null) return res;
    }

    // 3. Try CAS / Eagle (WN... or WT:)
    if (raw.toUpperCase().startsWith('WN') || raw.toUpperCase().contains('WT:')) {
      final res = _parseCasEagle(raw);
      if (res != null) return res;
    }

    // 4. Fallback to Universal Intelligent Number Extractor
    return _parseUniversalRegex(raw);
  }

  /// Phoenix / Nitiraj Protocol (Very popular in Maharashtra, Gujarat, MP Mandis)
  /// Format: "ST,GS,+001.250kg\r\n" or "US,GS,+001.250kg\r\n"
  static ScaleReading? _parsePhoenix(String raw) {
    try {
      final bool isStable = raw.contains('ST,') || !raw.contains('US,');
      final unit = raw.toLowerCase().contains('g') && !raw.toLowerCase().contains('kg') ? 'g' : 'kg';

      // Find signed or unsigned decimal value
      final match = RegExp(r'([+-]?\s*\d+\.?\d*)').firstMatch(raw);
      if (match != null) {
        final numStr = match.group(1)?.replaceAll(' ', '') ?? '';
        final double? w = double.tryParse(numStr);
        if (w != null) {
          return ScaleReading(
            weight: (w < 0 ? 0.0 : w),
            isStable: isStable,
            unit: unit,
            rawData: raw,
            timestamp: DateTime.now(),
          );
        }
      }
    } catch (e) {
      debugPrint("Error parsing Phoenix scale: $e");
    }
    return null;
  }

  /// Essae / Teraoka Protocol (Standard in supermarkets & modern Mandis)
  /// Format: [STX]001.250[ETX] or =001.250
  static ScaleReading? _parseEssae(String raw) {
    try {
      String sanitized = raw.replaceAll('\x02', '').replaceAll('\x03', '').trim();
      if (sanitized.startsWith('=')) {
        sanitized = sanitized.substring(1).trim();
      }

      final match = RegExp(r'(\d+\.?\d*)').firstMatch(sanitized);
      if (match != null) {
        final double? w = double.tryParse(match.group(1)!);
        if (w != null) {
          return ScaleReading(
            weight: w,
            isStable: true, // Essae typically transmits on stable weight
            unit: 'kg',
            rawData: raw,
            timestamp: DateTime.now(),
          );
        }
      }
    } catch (e) {
      debugPrint("Error parsing Essae scale: $e");
    }
    return null;
  }

  /// CAS / Eagle / Aczet Protocol
  /// Format: "WN001.250kg" or "WT:  1.250 kg"
  static ScaleReading? _parseCasEagle(String raw) {
    try {
      final unit = raw.toLowerCase().contains('kg') ? 'kg' : 'g';
      final match = RegExp(r'(\d+\.?\d*)').firstMatch(raw);
      if (match != null) {
        final double? w = double.tryParse(match.group(1)!);
        if (w != null) {
          return ScaleReading(
            weight: w,
            isStable: true,
            unit: unit,
            rawData: raw,
            timestamp: DateTime.now(),
          );
        }
      }
    } catch (e) {
      debugPrint("Error parsing CAS/Eagle scale: $e");
    }
    return null;
  }

  /// Standard SPP / HC-05 Continuous Serial Stream
  /// Format: "+  1.250 kg" or "1.250 kg"
  static ScaleReading? _parseStandardSpp(String raw) {
    return _parseUniversalRegex(raw);
  }

  /// Universal Intelligent Regex Extractor (Handles any scale outputting ASCII numbers)
  static ScaleReading? _parseUniversalRegex(String raw) {
    try {
      // Look for a floating point weight number like 1.250, 0.500, 12.34
      final match = RegExp(r'([+-]?\s*\d+\.\d{1,4})').firstMatch(raw);
      if (match != null) {
        final numStr = match.group(1)?.replaceAll(' ', '') ?? '';
        final double? w = double.tryParse(numStr);
        if (w != null) {
          final isGram = raw.toLowerCase().contains(' g') && !raw.toLowerCase().contains('kg');
          return ScaleReading(
            weight: w < 0 ? 0.0 : w,
            isStable: !raw.toUpperCase().contains('US') && !raw.toUpperCase().contains('UNSTABLE'),
            unit: isGram ? 'g' : 'kg',
            rawData: raw,
            timestamp: DateTime.now(),
          );
        }
      }

      // If no decimal point found, look for integer weights (e.g. "500 g" or "1 kg")
      final intMatch = RegExp(r'(\d{1,5})\s*(kg|g)?', caseSensitive: false).firstMatch(raw);
      if (intMatch != null) {
        final double? w = double.tryParse(intMatch.group(1)!);
        if (w != null) {
          final unit = (intMatch.group(2) ?? 'kg').toLowerCase();
          return ScaleReading(
            weight: w < 0 ? 0.0 : w,
            isStable: true,
            unit: unit,
            rawData: raw,
            timestamp: DateTime.now(),
          );
        }
      }
    } catch (e) {
      debugPrint("Error in universal scale regex parse: $e");
    }
    return null;
  }
}
