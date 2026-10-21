import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/sound_service.dart';

class PosNumpad extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  const PosNumpad({
    super.key,
    required this.controller,
    this.onSubmitted,
  });

  void _onKey(String val) {
    if (val == '.') {
      SoundService.instance.playDot();
      if (!controller.text.contains('.')) {
        controller.text += '.';
      }
    } else if (val == 'BACK') {
      SoundService.instance.playDelete();
      if (controller.text.isNotEmpty) {
        controller.text = controller.text.substring(0, controller.text.length - 1);
      }
    } else if (val == 'CLR') {
      SoundService.instance.playDelete();
      controller.clear();
    } else {
      SoundService.instance.playNumberKey();
      controller.text += val;
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', 'BACK'],
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: keys.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: row.map((k) {
                final isAction = k == 'BACK' || k == '.';
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Material(
                      color: isAction ? Colors.grey.shade200 : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      elevation: 1,
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
                                    fontSize: k == '.' ? 22 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: k == '.' ? AppColors.primary : Colors.black87,
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
