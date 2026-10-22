import 'package:audioplayers/audioplayers.dart';
import 'sound_player_interface.dart';

class SoundPlayerImpl implements SoundPlayerPlatform {
  // Round-robin pool of low-latency players for instant multi-tap button clicks
  final List<AudioPlayer> _clickPool = List.generate(
    4,
    (_) => AudioPlayer()..setPlayerMode(PlayerMode.lowLatency),
  );
  int _clickIdx = 0;

  // Round-robin pool for rapid product additions
  final List<AudioPlayer> _addPool = List.generate(
    3,
    (_) => AudioPlayer()..setPlayerMode(PlayerMode.lowLatency),
  );
  int _addIdx = 0;

  final AudioPlayer _deletePlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  final AudioPlayer _successPlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);

  SoundPlayerImpl() {
    _preloadAudio();
  }

  void _preloadAudio() async {
    try {
      for (final p in _clickPool) {
        await p.setSource(AssetSource('sounds/click.wav'));
      }
      for (final p in _addPool) {
        await p.setSource(AssetSource('sounds/beep.wav'));
      }
      await _deletePlayer.setSource(AssetSource('sounds/delete.wav'));
      await _successPlayer.setSource(AssetSource('sounds/success.wav'));
    } catch (_) {}
  }

  @override
  void playClick() {
    try {
      final player = _clickPool[_clickIdx++ % _clickPool.length];
      player.play(AssetSource('sounds/click.wav'), volume: 0.35, mode: PlayerMode.lowLatency);
    } catch (_) {}
  }

  @override
  void playButtonClick() {
    playClick();
  }

  @override
  void playNumberKey() {
    playClick();
  }

  @override
  void playDot() {
    playClick();
  }

  @override
  void playProductAdd() {
    try {
      final player = _addPool[_addIdx++ % _addPool.length];
      player.play(AssetSource('sounds/beep.wav'), volume: 0.45, mode: PlayerMode.lowLatency);
    } catch (_) {}
  }

  @override
  void playBeep() {
    playProductAdd();
  }

  @override
  void playDelete() {
    try {
      _deletePlayer.play(AssetSource('sounds/delete.wav'), volume: 0.40, mode: PlayerMode.lowLatency);
    } catch (_) {}
  }

  @override
  void playSuccess() {
    try {
      _successPlayer.play(AssetSource('sounds/success.wav'), volume: 0.50, mode: PlayerMode.lowLatency);
    } catch (_) {}
  }

  @override
  void playAppStartup() {
    try {
      _successPlayer.play(AssetSource('sounds/success.wav'), volume: 0.35, mode: PlayerMode.lowLatency);
    } catch (_) {}
  }
}

SoundPlayerPlatform getPlatformPlayer() => SoundPlayerImpl();
