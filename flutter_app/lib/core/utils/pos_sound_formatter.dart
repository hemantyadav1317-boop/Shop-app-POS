import 'package:flutter/services.dart';
import '../services/sound_service.dart';

/// Intercepts text inputs to trigger sound effects:
/// - Digits (0-9): Plays tactile number click sound
/// - Dot (.): Plays distinct high-pitched chime sound
/// - Delete / Backspace: Plays soft delete sound
class PosNumberSoundFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length > oldValue.text.length) {
      final addedText = newValue.text.substring(oldValue.selection.start.clamp(0, newValue.text.length));
      if (addedText.contains('.')) {
        SoundService.instance.playDot();
      } else if (RegExp(r'\d').hasMatch(addedText)) {
        SoundService.instance.playNumberKey();
      }
    } else if (newValue.text.length < oldValue.text.length) {
      SoundService.instance.playDelete();
    }
    return newValue;
  }
}
