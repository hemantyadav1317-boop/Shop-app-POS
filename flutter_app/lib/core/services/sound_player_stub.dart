import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'sound_player_interface.dart';

class SoundPlayerImpl implements SoundPlayerPlatform {
  static const MethodChannel _nativeChannel = MethodChannel('com.shop.pos/native_sound');
  bool _useNative = true;

  // Fallback AudioPlayer if native channel is unavailable
  AudioPlayer? _fallbackPlayer;

  AudioPlayer? _getPlayer() {
    if (_fallbackPlayer == null) {
      try {
        _fallbackPlayer = AudioPlayer()
          ..setPlayerMode(PlayerMode.lowLatency)
          ..setReleaseMode(ReleaseMode.stop);
      } catch (_) {}
    }
    return _fallbackPlayer;
  }

  SoundPlayerImpl();

  void _play(String nativeMethod, String assetName, double volume) {
    if (_useNative) {
      _nativeChannel.invokeMethod<bool>(nativeMethod).then((success) {
        if (success != true) {
          _fallbackPlay(assetName, volume);
        }
      }).catchError((_) {
        _useNative = false;
        _fallbackPlay(assetName, volume);
      });
      return;
    }
    _fallbackPlay(assetName, volume);
  }

  void _fallbackPlay(String assetName, double volume) async {
    try {
      final p = _getPlayer();
      if (p == null) return;
      await p.stop();
      await p.play(
        AssetSource('sounds/$assetName'),
        volume: volume,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {}
  }

  @override
  void playClick() => _play('playClick', 'click.wav', 0.40);

  @override
  void playButtonClick() => playClick();

  @override
  void playNumberKey() => playClick();

  @override
  void playDot() => _play('playDot', 'dot.wav', 0.45);

  @override
  void playProductAdd() => _play('playProductAdd', 'beep.wav', 0.50);

  @override
  void playBeep() => playProductAdd();

  @override
  void playDelete() => _play('playDelete', 'delete.wav', 0.55);

  @override
  void playSuccess() => _play('playSuccess', 'success.wav', 0.60);

  @override
  void playAppStartup() => _play('playAppStartup', 'success.wav', 0.45);
}

SoundPlayerPlatform getPlatformPlayer() => SoundPlayerImpl();
