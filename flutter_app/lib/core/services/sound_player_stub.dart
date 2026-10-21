import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'sound_player_interface.dart';

class SoundPlayerImpl implements SoundPlayerPlatform {
  final AudioPlayer _beepPlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  final AudioPlayer _successPlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  final AudioPlayer _deletePlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);

  @override
  void playBeep() {
    try {
      _beepPlayer.play(AssetSource('sounds/beep.wav'), volume: 0.65, mode: PlayerMode.lowLatency);
    } catch (_) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  @override
  void playClick() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  @override
  void playSuccess() {
    try {
      _successPlayer.play(AssetSource('sounds/success.wav'), volume: 0.70, mode: PlayerMode.lowLatency);
    } catch (_) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  @override
  void playDelete() {
    try {
      _deletePlayer.play(AssetSource('sounds/delete.wav'), volume: 0.55, mode: PlayerMode.lowLatency);
    } catch (_) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  @override
  void playDot() {
    try {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  @override
  void playButtonClick() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  @override
  void playProductAdd() {
    try {
      _beepPlayer.play(AssetSource('sounds/beep.wav'), volume: 0.65, mode: PlayerMode.lowLatency);
    } catch (_) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  @override
  void playNumberKey() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  @override
  void playAppStartup() {
    try {
      _successPlayer.play(AssetSource('sounds/success.wav'), volume: 0.45, mode: PlayerMode.lowLatency);
    } catch (_) {}
  }
}

SoundPlayerPlatform getPlatformPlayer() => SoundPlayerImpl();
