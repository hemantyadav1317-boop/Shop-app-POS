import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/sound_service.dart';

class PosNumpad extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final VoidCallback? onAllClear;
  final bool replaceOnNextKey;
  final VoidCallback? onFirstKeyConsumed;

  const PosNumpad({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onAllClear,
    this.replaceOnNextKey = false,
    this.onFirstKeyConsumed,
  });

  void _onKey(String val) {
    String current = controller.text;

    if (val == '.') {
      SoundService.instance.playDot();
      if (replaceOnNextKey || current.isEmpty || current == '0') {
        current = '0.';
        onFirstKeyConsumed?.call();
      } else if (!current.contains('.')) {
        current = '$current.';
      }
    } else if (val == 'BACK') {
      SoundService.instance.playDelete();
      if (current.isNotEmpty) {
        current = current.substring(0, current.length - 1);
      }
      onFirstKeyConsumed?.call();
    } else if (val == 'AC') {
      SoundService.instance.playDelete();
      current = '';
      onFirstKeyConsumed?.call();
      onAllClear?.call();
    } else {
      SoundService.instance.playNumberKey();
      if (replaceOnNextKey) {
        current = val;
        onFirstKeyConsumed?.call();
      } else {
        if (current == '0' && val != '00') {
          current = val;
        } else {
          current = '$current$val';
        }
      }
    }

    controller.text = current;
    onChanged?.call(current);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 4x4 Tactile Layout with dedicated 'AC' (All Clear), Backspace, and double zero
    final keys = [
      ['1', '2', '3', 'AC'],
      ['4', '5', '6', 'BACK'],
      ['7', '8', '9', '00'],
      ['.', '0', '000', 'DONE'],
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: keys.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              children: row.map((k) {
                final isAC = k == 'AC';
                final isBack = k == 'BACK';
                final isDone = k == 'DONE';
                final isAction = isBack || k == '.' || k == '00' || k == '000';

                Color btnBg;
                if (isAC) {
                  btnBg = Colors.red.shade50;
                } else if (isDone) {
                  btnBg = const Color(0xFF00875A);
                } else if (isAction) {
                  btnBg = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
                } else {
                  btnBg = isDark ? const Color(0xFF0F172A) : Colors.white;
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Material(
                      color: btnBg,
                      borderRadius: BorderRadius.circular(8),
                      elevation: isDone ? 1 : (isDark ? 0 : 0.5),
                      shadowColor: Colors.black12,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          if (isDone) {
                            SoundService.instance.playButtonClick();
                            onSubmitted?.call();
                          } else {
                            _onKey(k);
                          }
                        },
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          child: isBack
                              ? const Icon(Icons.backspace_outlined, size: 19, color: AppColors.error)
                              : isDone
                                  ? const Icon(Icons.check, size: 20, color: Colors.white)
                                  : isAC
                                      ? const Text(
                                          'AC',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.red,
                                          ),
                                        )
                                      : Text(
                                          k,
                                          style: TextStyle(
                                            fontSize: (k == '00' || k == '000') ? 14 : 17,
                                            fontWeight: FontWeight.bold,
                                            color: k == '.'
                                                ? AppColors.primary
                                                : (isDark ? Colors.white : Colors.black87),
                                          ),
                                        ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}
