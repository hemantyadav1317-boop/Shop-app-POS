import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'sound_player_interface.dart';

class SoundPlayerImpl implements SoundPlayerPlatform {
  final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  @override
  void playBeep() {
    try {
      _player.stop();
      _player.play(AssetSource('sounds/beep.wav'));
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  @override
  void playClick() {
    try {
      _player.stop();
      _player.play(AssetSource('sounds/click.wav'));
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  @override
  void playSuccess() {
    try {
      _player.stop();
      _player.play(AssetSource('sounds/success.wav'));
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  @override
  void playDelete() {
    try {
      _player.stop();
      _player.play(AssetSource('sounds/delete.wav'));
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  @override
  void playDot() {
    try {
      HapticFeedback.mediumImpact();
      _player.stop();
      _player.play(AssetSource('sounds/click.wav'), volume: 1.0);
    } catch (_) {
      try {
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  @override
  void playButtonClick() {
    try {
      _player.stop();
      _player.play(AssetSource('sounds/click.wav'), volume: 0.65);
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  @override
  void playProductAdd() {
    try {
      _player.stop();
      _player.play(AssetSource('sounds/beep.wav'), volume: 0.75);
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  @override
  void playNumberKey() {
    try {
      _player.stop();
      _player.play(AssetSource('sounds/click.wav'), volume: 0.5);
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  @override
  void playAppStartup() {
    try {
      _player.stop();
      _player.play(AssetSource('sounds/success.wav'), volume: 0.55);
    } catch (_) {}
  }
}

SoundPlayerPlatform getPlatformPlayer() => SoundPlayerImpl();
