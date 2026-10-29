import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/sound_service.dart';

class PosNumpad extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  const PosNumpad({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
  });

  void _onKey(String val) {
    String current = controller.text;

    if (val == '.') {
      SoundService.instance.playDot();
      if (current.isEmpty || current == '1' || current == '0') {
        current = '0.';
      } else if (!current.contains('.')) {
        current = '$current.';
      }
    } else if (val == 'BACK') {
      SoundService.instance.playDelete();
      if (current.isNotEmpty) {
        current = current.substring(0, current.length - 1);
      }
    } else if (val == 'CLR') {
      SoundService.instance.playDelete();
      current = '';
    } else {
      SoundService.instance.playNumberKey();
      // If default '1' is untouched and user types a digit, replace it
      if (current == '1') {
        current = val;
      } else {
        current = '$current$val';
      }
    }

    controller.text = current;
    onChanged?.call(current);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', 'BACK'],
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: keys.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: row.map((k) {
                final isAction = k == 'BACK' || k == '.';
                final actionBg = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
                final normalBg = isDark ? const Color(0xFF0F172A) : Colors.white;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Material(
                      color: isAction ? actionBg : normalBg,
                      borderRadius: BorderRadius.circular(10),
                      elevation: isDark ? 0 : 1,
                      shadowColor: Colors.black12,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _onKey(k),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          child: k == 'BACK'
                              ? const Icon(Icons.backspace_outlined, size: 20, color: AppColors.error)
                              : Text(
                                  k,
                                  style: TextStyle(
                                    fontSize: k == '.' ? 24 : 18,
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
