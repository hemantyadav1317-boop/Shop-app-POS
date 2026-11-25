import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps billing timestamps accurate across devices even when a phone's local
/// system clock is skewed, by calibrating against Internet/Supabase HTTP Date
/// headers and persisting the measured offset for offline fallback.
class TimeSyncService {
  TimeSyncService._internal();
  static final TimeSyncService instance = TimeSyncService._internal();

  static const String _prefsOffsetKey = 'server_clock_offset_ms';
  static const Map<String, int> _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  Duration _serverOffset = Duration.zero;
  bool _hasNetworkSync = false;
  DateTime? _lastSyncAttempt;
  Future<bool>? _inflightSync;

  Duration get serverOffset => _serverOffset;
  bool get hasNetworkSync => _hasNetworkSync;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMs = prefs.getInt(_prefsOffsetKey);
      if (savedMs != null && savedMs.abs() <= const Duration(days: 30).inMilliseconds) {
        _serverOffset = Duration(milliseconds: savedMs);
      }
    } catch (_) {}
  }

  /// Current authoritative UTC time (calibrated with Internet time if available).
  DateTime nowUtc() => DateTime.now().toUtc().add(_serverOffset);

  /// Current authoritative local time for bill timestamps and UI display.
  DateTime nowLocal() => nowUtc().toLocal();

  /// Parses an HTTP IMF-fixdate / RFC-1123 Date header (e.g. `Wed, 25 Nov 2026 13:45:12 GMT`)
  /// safely on all platforms (Android, Windows, Web) without dart:io dependency.
  static DateTime? parseHttpDateHeader(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final match = RegExp(
      r'^[A-Za-z]{3},\s+(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT$',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (match == null) return null;
    final day = int.tryParse(match.group(1)!);
    final month = _months[match.group(2)!.toLowerCase()];
    final year = int.tryParse(match.group(3)!);
    final hour = int.tryParse(match.group(4)!);
    final minute = int.tryParse(match.group(5)!);
    final second = int.tryParse(match.group(6)!);
    if (day == null ||
        month == null ||
        year == null ||
        hour == null ||
        minute == null ||
        second == null) {
      return null;
    }
    return DateTime.utc(year, month, day, hour, minute, second);
  }

  /// Calibrates [_serverOffset] using Internet HTTP Date headers from [endpoints].
  /// Returns true if calibration succeeded. Cooldown avoids redundant network calls.
  Future<bool> syncWithInternet({
    List<String> endpoints = const [
      'https://zibgyfybhvadduuhexqy.supabase.co/rest/v1/',
      'https://clients3.google.com/generate_204',
    ],
    bool force = false,
  }) {
    if (!force &&
        _hasNetworkSync &&
        _lastSyncAttempt != null &&
        DateTime.now().difference(_lastSyncAttempt!) < const Duration(minutes: 5)) {
      return Future.value(true);
    }
    if (_inflightSync != null) return _inflightSync!;
    _inflightSync = _performSync(endpoints).whenComplete(() => _inflightSync = null);
    return _inflightSync!;
  }

  Future<bool> _performSync(List<String> endpoints) async {
    _lastSyncAttempt = DateTime.now();
    for (final url in endpoints) {
      try {
        final beforeUtc = DateTime.now().toUtc();
        final res = await http
            .head(Uri.parse(url))
            .timeout(const Duration(milliseconds: 1800));
        final afterUtc = DateTime.now().toUtc();
        final dateHeader = res.headers['date'] ?? res.headers['Date'];
        final serverUtc = parseHttpDateHeader(dateHeader);
        if (serverUtc != null) {
          final midpointUtc = beforeUtc.add(
            Duration(milliseconds: afterUtc.difference(beforeUtc).inMilliseconds ~/ 2),
          );
          final rawDiff = serverUtc.difference(midpointUtc);
          // Ignore tiny < 5s network jitter so normal device clocks remain untouched
          _serverOffset = rawDiff.abs() >= const Duration(seconds: 5)
              ? rawDiff
              : Duration.zero;
          _hasNetworkSync = true;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt(_prefsOffsetKey, _serverOffset.inMilliseconds);
          } catch (_) {}
          debugPrint('[TimeSync] Calibrated clock offset: ${_serverOffset.inSeconds}s');
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Heals legacy DB rows whose `created_at` was accidentally saved with an
  /// IST (+5:30) offset inside a UTC column (appearing in the future vs real server time).
  DateTime healCloudTimestampIfFuture(DateTime parsedLocal) {
    if (!_hasNetworkSync) return parsedLocal;
    final realNowUtc = nowUtc();
    final parsedUtc = parsedLocal.toUtc();
    if (parsedUtc.isAfter(realNowUtc.add(const Duration(minutes: 5)))) {
      final shifted = parsedUtc.subtract(const Duration(hours: 5, minutes: 30));
      if (!shifted.isAfter(realNowUtc.add(const Duration(minutes: 2)))) {
        return shifted.toLocal();
      }
      return realNowUtc.toLocal();
    }
    return parsedLocal;
  }

  @visibleForTesting
  void setForTest({
    Duration offset = Duration.zero,
    bool hasNetworkSync = false,
  }) {
    _serverOffset = offset;
    _hasNetworkSync = hasNetworkSync;
    _lastSyncAttempt = hasNetworkSync ? DateTime.now() : null;
  }
}
