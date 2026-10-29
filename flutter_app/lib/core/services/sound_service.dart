import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sound_player_interface.dart';
import 'sound_player_stub.dart'
    if (dart.library.html) 'sound_player_web.dart' as platform_impl;

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final SoundPlayerPlatform _player = platform_impl.getPlatformPlayer();
  bool _enabled = true;

  bool get isSoundEnabled => _enabled;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool('pos_sound_enabled') ?? true;
    } catch (_) {}
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _enabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pos_sound_enabled', enabled);
    } catch (_) {}
  }

  void playBeep() {
    if (!_enabled) return;
    try {
      HapticFeedback.lightImpact();
      _player.playBeep();
    } catch (_) {}
  }

  void playClick() {
    if (!_enabled) return;
    try {
      HapticFeedback.selectionClick();
      _player.playClick();
    } catch (_) {}
  }

  void playSuccess() {
    if (!_enabled) return;
    try {
      HapticFeedback.mediumImpact();
      _player.playSuccess();
    } catch (_) {}
  }

  void playDelete() {
    if (!_enabled) return;
    try {
      HapticFeedback.lightImpact();
      _player.playDelete();
    } catch (_) {}
  }

  void playError() {
    if (!_enabled) return;
    try {
      HapticFeedback.heavyImpact();
      _player.playDelete();
    } catch (_) {}
  }

  void playDot() {
    if (!_enabled) return;
    try {
      HapticFeedback.mediumImpact();
      _player.playDot();
    } catch (_) {}
  }

  void playButtonClick() {
    if (!_enabled) return;
    try {
      HapticFeedback.selectionClick();
      _player.playButtonClick();
    } catch (_) {}
  }

  void playTypeKey() {
    if (!_enabled) return;
    try {
      HapticFeedback.selectionClick();
      _player.playClick();
    } catch (_) {}
  }

  void playProductAdd() {
    if (!_enabled) return;
    try {
      HapticFeedback.lightImpact();
      _player.playProductAdd();
    } catch (_) {}
  }

  void playNumberKey() {
    if (!_enabled) return;
    try {
      HapticFeedback.selectionClick();
      _player.playNumberKey();
    } catch (_) {}
  }

  void playAppStartup() {
    if (!_enabled) return;
    try {
      _player.playAppStartup();
    } catch (_) {}
  }
}
