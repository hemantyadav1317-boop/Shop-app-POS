import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/sound_service.dart';
import '../../../data/models/cart_item.dart';
import '../../../providers/cart_provider.dart';

class QuickSaleKeypad extends StatefulWidget {
  final VoidCallback? onItemAdded;

  const QuickSaleKeypad({super.key, this.onItemAdded});

  @override
  State<QuickSaleKeypad> createState() => _QuickSaleKeypadState();
}

class _QuickSaleKeypadState extends State<QuickSaleKeypad> {
  String _amountStr = '';
  final TextEditingController _nameController = TextEditingController(text: 'Quick Item');

  double get _currentAmount => double.tryParse(_amountStr) ?? 0.0;

  void _onDigit(String d) {
    SoundService.instance.playClick();
    if (d == '.' && _amountStr.contains('.')) return;
    if (_amountStr.length >= 8) return;

    setState(() {
      if (_amountStr.isEmpty && (d == '0' || d == '00')) {
        return;
      }
      if (_amountStr.isEmpty && d == '.') {
        _amountStr = '0.';
        return;
      }
      _amountStr += d;
    });
  }

  void _onBackspace() {
    SoundService.instance.playClick();
    if (_amountStr.isNotEmpty) {
      setState(() {
        _amountStr = _amountStr.substring(0, _amountStr.length - 1);
      });
    }
  }

  void _onClear() {
    SoundService.instance.playClick();
    setState(() {
      _amountStr = '';
    });
  }

  void _onAddItem() {
    final amt = _currentAmount;
    if (amt <= 0) {
      SoundService.instance.playError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount greater than ₹0'),
          duration: Duration(milliseconds: 1000),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final cart = context.read<CartProvider>();
    final itemName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Quick Item';

    final newItem = CartItem(
      productId: 'quick_${DateTime.now().millisecondsSinceEpoch}',
      name: itemName,
      unit: 'item',
      price: amt,
      qty: 1.0,
      icon: 'zap',
    );

    cart.addLine(newItem);
    SoundService.instance.playProductAdd();

    setState(() {
      _amountStr = '';
    });

    widget.onItemAdded?.call();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          // 📟 Amount Display & Item Name
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '⚡ Quick Calculator Sale',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    if (_amountStr.isNotEmpty)
                      InkWell(
                        onTap: _onClear,
                        child: const Text('CLEAR', style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // Live Amount LCD
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      '₹',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF00875A)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _amountStr.isEmpty ? '0.00' : _amountStr,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: 1.5,
                          color: _amountStr.isEmpty ? Colors.grey.shade400 : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                // Item Name Quick Bar
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Item Name (e.g. Quick Item, Rice, Dal)',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 🔢 Calculator Keypad Grid matching Image 2
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    // Row 1: 7, 8, 9, Backspace
                    Expanded(
                      child: Row(
                        children: [
                          _buildNumBtn('7', isDark),
                          _buildNumBtn('8', isDark),
                          _buildNumBtn('9', isDark),
                          _buildActionKey(
                            icon: Icons.backspace_outlined,
                            color: Colors.amber.shade700,
                            onTap: _onBackspace,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Row 2: 4, 5, 6, Clear (X)
                    Expanded(
                      child: Row(
                        children: [
                          _buildNumBtn('4', isDark),
                          _buildNumBtn('5', isDark),
                          _buildNumBtn('6', isDark),
                          _buildActionKey(
                            icon: Icons.close_rounded,
                            color: AppColors.error,
                            onTap: _onClear,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Row 3 & 4: Left 3 cols (1 2 3, 0 00 .) & Right 1 col (Add Item Button)
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          // Left 3 columns
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                // 1, 2, 3
                                Expanded(
                                  child: Row(
                                    children: [
                                      _buildNumBtn('1', isDark),
                                      _buildNumBtn('2', isDark),
                                      _buildNumBtn('3', isDark),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // 0, 00, .
                                Expanded(
                                  child: Row(
                                    children: [
                                      _buildNumBtn('0', isDark),
                                      _buildNumBtn('00', isDark),
                                      _buildNumBtn('.', isDark),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Right Column: Big Blue "Add Item" Button
                          Expanded(
                            flex: 1,
                            child: Material(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(14),
                              elevation: 2,
                              child: InkWell(
                                onTap: _onAddItem,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 28),
                                      SizedBox(height: 8),
                                      Text(
                                        'Add Item',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumBtn(String text, bool isDark) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: 1,
          child: InkWell(
            onTap: () => _onDigit(text),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              alignment: Alignment.center,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: 1,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
