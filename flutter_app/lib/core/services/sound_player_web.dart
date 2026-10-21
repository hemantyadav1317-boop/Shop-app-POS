// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'sound_player_interface.dart';

class SoundPlayerImpl implements SoundPlayerPlatform {
  @override
  void playBeep() {
    try {
      js.context.callMethod('eval', ["window.posAudio && window.posAudio.playBeep && window.posAudio.playBeep()"]);
    } catch (_) {}
  }

  @override
  void playClick() {
    try {
      js.context.callMethod('eval', ["window.posAudio && window.posAudio.playClick && window.posAudio.playClick()"]);
    } catch (_) {}
  }

  @override
  void playSuccess() {
    try {
      js.context.callMethod('eval', ["window.posAudio && window.posAudio.playSuccess && window.posAudio.playSuccess()"]);
    } catch (_) {}
  }

  @override
  void playDelete() {
    try {
      js.context.callMethod('eval', ["window.posAudio && window.posAudio.playDelete && window.posAudio.playDelete()"]);
    } catch (_) {}
  }
}

SoundPlayerPlatform getPlatformPlayer() => SoundPlayerImpl();
