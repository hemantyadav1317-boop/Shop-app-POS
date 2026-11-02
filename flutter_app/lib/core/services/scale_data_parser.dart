import 'package:flutter/foundation.dart';

enum ScaleProtocol {
  autoDetect,
  standardSpp,
  essae,
  phoenixNitiraj,
  casEagle,
}

enum ScaleUnitMode {
  autoDetect, // Smart Auto: Converts grams (g) or raw integer count (>50 or no dot) to kg
  gramsToKg,  // Always divide by 1000 (e.g. 540 -> 0.540 kg)
  directKg,   // As-is without division (e.g. 0.540 -> 0.540 kg)
}

class ScaleReading {
  /// Always normalized in Kilograms (KG) for billing & cart calculations
  final double weight;

  /// Raw numeric value before unit normalization
  final double rawWeight;

  final bool isStable;
  final String unit;
  final String rawData;
  final DateTime timestamp;

  const ScaleReading({
    required this.weight,
    double? rawWeight,
    required this.isStable,
    required this.unit,
    required this.rawData,
    required this.timestamp,
  }) : rawWeight = rawWeight ?? weight;

  /// Formatted weight in Kilograms (e.g. "0.540 kg")
  String get displayKg => '${weight.toStringAsFixed(3)} kg';

  /// Formatted weight in Grams (e.g. "540 g")
  String get displayGrams => '${(weight * 1000).toStringAsFixed(0)} g';

  @override
  String toString() =>
      'ScaleReading(weight: ${weight.toStringAsFixed(3)} kg, raw: $rawWeight $unit, isStable: $isStable, rawData: "$rawData")';
}

class ScaleDataParser {
  /// Normalizes parsed weight into Kilograms (KG)
  static double normalizeWeight(
    double rawWeight,
    String unit,
    String raw,
    ScaleUnitMode unitMode,
  ) {
    if (rawWeight <= 0) return 0.0;

    switch (unitMode) {
      case ScaleUnitMode.gramsToKg:
        return rawWeight / 1000.0;

      case ScaleUnitMode.directKg:
        return rawWeight;

      case ScaleUnitMode.autoDetect:
        // 1. Explicit gram unit in data stream (e.g. "540 g", "540g")
        if (unit.toLowerCase() == 'g') {
          return rawWeight / 1000.0;
        }

        // 2. Retail counter scales max capacity is 30kg or 50kg.
        // If a scale outputs a number > 50 without decimal or unit, it's raw grams (e.g. 540 -> 0.540 kg)
        if (rawWeight > 50.0) {
          return rawWeight / 1000.0;
        }

        // 3. Scale sends integer without decimal dot and 3 or more digits (e.g. "000540" -> 0.540 kg)
        if (!raw.contains('.') && rawWeight >= 10.0 && raw.trim().length >= 4) {
          return rawWeight / 1000.0;
        }

        return rawWeight;
    }
  }

  /// Parses a raw string received from a Bluetooth weighing scale
  static ScaleReading? parse(
    String raw,
    ScaleProtocol protocol, {
    ScaleUnitMode unitMode = ScaleUnitMode.autoDetect,
  }) {
    final clean = raw.trim();
    if (clean.isEmpty) return null;

    switch (protocol) {
      case ScaleProtocol.essae:
        return _parseEssae(clean, unitMode);
      case ScaleProtocol.phoenixNitiraj:
        return _parsePhoenix(clean, unitMode);
      case ScaleProtocol.casEagle:
        return _parseCasEagle(clean, unitMode);
      case ScaleProtocol.standardSpp:
        return _parseStandardSpp(clean, unitMode);
      case ScaleProtocol.autoDetect:
        return _parseAutoDetect(clean, unitMode);
    }
  }

  /// Auto-Detect: Tries protocols in sequence or uses universal number extraction
  static ScaleReading? _parseAutoDetect(String raw, ScaleUnitMode unitMode) {
    // 1. Try Phoenix / Nitiraj format (ST,GS,+001.250kg or US,GS,...)
    if (raw.contains('ST,') || raw.contains('US,') || raw.contains('GS,')) {
      final res = _parsePhoenix(raw, unitMode);
      if (res != null) return res;
    }

    // 2. Try Essae STX/ETX or Essae format
    if (raw.contains('\x02') || raw.contains('\x03') || raw.startsWith('=')) {
      final res = _parseEssae(raw, unitMode);
      if (res != null) return res;
    }

    // 3. Try CAS / Eagle (WN... or WT:)
    if (raw.toUpperCase().startsWith('WN') || raw.toUpperCase().contains('WT:')) {
      final res = _parseCasEagle(raw, unitMode);
      if (res != null) return res;
    }

    // 4. Fallback to Universal Intelligent Number Extractor
    return _parseUniversalRegex(raw, unitMode);
  }

  /// Phoenix / Nitiraj Protocol (Very popular in Maharashtra, Gujarat, MP Mandis)
  /// Format: "ST,GS,+001.250kg\r\n" or "US,GS,+001.250kg\r\n"
  static ScaleReading? _parsePhoenix(String raw, ScaleUnitMode unitMode) {
    try {
      final bool isStable = raw.contains('ST,') || !raw.contains('US,');
      final unit = raw.toLowerCase().contains('g') && !raw.toLowerCase().contains('kg') ? 'g' : 'kg';

      // Find signed or unsigned decimal or integer value
      final match = RegExp(r'([+-]?\s*\d+\.?\d*)').firstMatch(raw);
      if (match != null) {
        final numStr = match.group(1)?.replaceAll(' ', '') ?? '';
        final double? rawW = double.tryParse(numStr);
        if (rawW != null) {
          final cleanRawW = rawW < 0 ? 0.0 : rawW;
          final double normalizedKg = normalizeWeight(cleanRawW, unit, raw, unitMode);
          return ScaleReading(
            weight: normalizedKg,
            rawWeight: cleanRawW,
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
  static ScaleReading? _parseEssae(String raw, ScaleUnitMode unitMode) {
    try {
      String sanitized = raw.replaceAll('\x02', '').replaceAll('\x03', '').trim();
      if (sanitized.startsWith('=')) {
        sanitized = sanitized.substring(1).trim();
      }

      final match = RegExp(r'(\d+\.?\d*)').firstMatch(sanitized);
      if (match != null) {
        final double? rawW = double.tryParse(match.group(1)!);
        if (rawW != null) {
          final double normalizedKg = normalizeWeight(rawW, 'kg', raw, unitMode);
          return ScaleReading(
            weight: normalizedKg,
            rawWeight: rawW,
            isStable: true,
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
  static ScaleReading? _parseCasEagle(String raw, ScaleUnitMode unitMode) {
    try {
      final unit = raw.toLowerCase().contains('kg') ? 'kg' : (raw.toLowerCase().contains('g') ? 'g' : 'kg');
      final match = RegExp(r'(\d+\.?\d*)').firstMatch(raw);
      if (match != null) {
        final double? rawW = double.tryParse(match.group(1)!);
        if (rawW != null) {
          final double normalizedKg = normalizeWeight(rawW, unit, raw, unitMode);
          return ScaleReading(
            weight: normalizedKg,
            rawWeight: rawW,
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
  static ScaleReading? _parseStandardSpp(String raw, ScaleUnitMode unitMode) {
    return _parseUniversalRegex(raw, unitMode);
  }

  /// Universal Intelligent Regex Extractor (Handles any scale outputting ASCII numbers)
  static ScaleReading? _parseUniversalRegex(String raw, ScaleUnitMode unitMode) {
    try {
      final isStable = !raw.toUpperCase().contains('US') && !raw.toUpperCase().contains('UNSTABLE');
      final bool hasGramExplicit = RegExp(r'\b(g|gm|grams?)\b', caseSensitive: false).hasMatch(raw) &&
          !raw.toLowerCase().contains('kg');
      final unit = hasGramExplicit ? 'g' : 'kg';

      // 1. Look for floating point weight number (e.g. "0.540", "1.250", "+  0.850 kg")
      final floatMatch = RegExp(r'([+-]?\s*\d+\.\d{1,4})').firstMatch(raw);
      if (floatMatch != null) {
        final numStr = floatMatch.group(1)?.replaceAll(' ', '') ?? '';
        final double? rawW = double.tryParse(numStr);
        if (rawW != null) {
          final cleanRawW = rawW < 0 ? 0.0 : rawW;
          final double normalizedKg = normalizeWeight(cleanRawW, unit, raw, unitMode);
          return ScaleReading(
            weight: normalizedKg,
            rawWeight: cleanRawW,
            isStable: isStable,
            unit: unit,
            rawData: raw,
            timestamp: DateTime.now(),
          );
        }
      }

      // 2. Look for integer weights (e.g. "540 g", "540", "000540", "1 kg")
      final intMatch = RegExp(r'(\d{1,6})\s*(kg|g|gm)?', caseSensitive: false).firstMatch(raw);
      if (intMatch != null) {
        final double? rawW = double.tryParse(intMatch.group(1)!);
        if (rawW != null) {
          final cleanRawW = rawW < 0 ? 0.0 : rawW;
          final matchedUnit = intMatch.group(2)?.toLowerCase();
          final effectiveUnit = (matchedUnit == 'g' || matchedUnit == 'gm' || hasGramExplicit) ? 'g' : 'kg';
          final double normalizedKg = normalizeWeight(cleanRawW, effectiveUnit, raw, unitMode);

          return ScaleReading(
            weight: normalizedKg,
            rawWeight: cleanRawW,
            isStable: isStable,
            unit: effectiveUnit,
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
