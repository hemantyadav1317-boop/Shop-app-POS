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
      _player.stop();
      _player.play(AssetSource('sounds/click.wav'));
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }
}

SoundPlayerPlatform getPlatformPlayer() => SoundPlayerImpl();
