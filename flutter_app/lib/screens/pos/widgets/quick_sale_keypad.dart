import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/sound_service.dart';
import '../../../data/models/cart_item.dart';
import '../../../providers/cart_provider.dart';

enum QuickSaleMode { rateQty, direct }
enum ActiveInput { rate, qty, direct }

class QuickSaleKeypad extends StatefulWidget {
  final VoidCallback? onItemAdded;

  const QuickSaleKeypad({super.key, this.onItemAdded});

  @override
  State<QuickSaleKeypad> createState() => _QuickSaleKeypadState();
}

class _QuickSaleKeypadState extends State<QuickSaleKeypad> {
  QuickSaleMode _mode = QuickSaleMode.rateQty;
  ActiveInput _activeInput = ActiveInput.rate;

  String _rateStr = '';
  String _qtyStr = '1';
  String _directAmtStr = '';
  String _unit = 'kg';

  final TextEditingController _nameController = TextEditingController(text: 'सब्जी / Quick Item');

  double get _rate => double.tryParse(_rateStr) ?? 0.0;
  double get _qty => double.tryParse(_qtyStr) ?? 0.0;
  double get _directAmt => double.tryParse(_directAmtStr) ?? 0.0;

  double get _totalPayable {
    if (_mode == QuickSaleMode.direct) {
      return _directAmt;
    }
    return _rate * _qty;
  }

  void _onDigit(String d) {
    SoundService.instance.playClick();

    setState(() {
      if (_mode == QuickSaleMode.direct) {
        if (d == '.' && _directAmtStr.contains('.')) return;
        if (_directAmtStr.length >= 8) return;
        if (_directAmtStr.isEmpty && (d == '0' || d == '00')) return;
        if (_directAmtStr.isEmpty && d == '.') {
          _directAmtStr = '0.';
          return;
        }
        _directAmtStr += d;
      } else {
        if (_activeInput == ActiveInput.rate) {
          if (d == '.' && _rateStr.contains('.')) return;
          if (_rateStr.length >= 7) return;
          if (_rateStr.isEmpty && (d == '0' || d == '00')) return;
          if (_rateStr.isEmpty && d == '.') {
            _rateStr = '0.';
            return;
          }
          _rateStr += d;
        } else {
          // Qty / Weight
          if (d == '.' && _qtyStr.contains('.')) return;
          if (_qtyStr.length >= 6) return;
          if (_qtyStr == '0' && d != '.') {
            _qtyStr = d;
            return;
          }
          if (_qtyStr.isEmpty && d == '.') {
            _qtyStr = '0.';
            return;
          }
          _qtyStr += d;
        }
      }
    });
  }

  void _onBackspace() {
    SoundService.instance.playClick();
    setState(() {
      if (_mode == QuickSaleMode.direct) {
        if (_directAmtStr.isNotEmpty) {
          _directAmtStr = _directAmtStr.substring(0, _directAmtStr.length - 1);
        }
      } else {
        if (_activeInput == ActiveInput.rate) {
          if (_rateStr.isNotEmpty) {
            _rateStr = _rateStr.substring(0, _rateStr.length - 1);
          }
        } else {
          if (_qtyStr.isNotEmpty) {
            _qtyStr = _qtyStr.substring(0, _qtyStr.length - 1);
          }
        }
      }
    });
  }

  void _onClear() {
    SoundService.instance.playClick();
    setState(() {
      if (_mode == QuickSaleMode.direct) {
        _directAmtStr = '';
      } else {
        if (_activeInput == ActiveInput.rate && _rateStr.isNotEmpty) {
          _rateStr = '';
        } else if (_activeInput == ActiveInput.qty && _qtyStr.isNotEmpty && _qtyStr != '1') {
          _qtyStr = '';
        } else {
          _rateStr = '';
          _qtyStr = '1';
        }
      }
    });
  }

  void _setPresetWeight(double weightInKg) {
    SoundService.instance.playClick();
    setState(() {
      _unit = 'kg';
      if (weightInKg < 1) {
        // e.g. 0.1, 0.25, 0.5
        _qtyStr = weightInKg.toString();
      } else {
        _qtyStr = weightInKg.toInt().toString();
      }
      // If user hasn't entered rate yet, keep rate active; else focus qty
      if (_rateStr.isEmpty) {
        _activeInput = ActiveInput.rate;
      }
    });
  }

  void _onAddItem() {
    final total = _totalPayable;
    if (total <= 0) {
      SoundService.instance.playError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया सही भाव या राशि दर्ज करें (Amount must be > ₹0)'),
          duration: Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final cart = context.read<CartProvider>();
    final itemName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (_mode == QuickSaleMode.rateQty ? 'सब्जी / फल' : 'Quick Item');

    final CartItem newItem;
    if (_mode == QuickSaleMode.direct) {
      newItem = CartItem(
        productId: 'quick_${DateTime.now().millisecondsSinceEpoch}',
        name: itemName,
        unit: 'item',
        price: total,
        qty: 1.0,
        icon: 'zap',
      );
    } else {
      newItem = CartItem(
        productId: 'quick_${DateTime.now().millisecondsSinceEpoch}',
        name: itemName,
        unit: _unit,
        price: _rate,
        qty: _qty > 0 ? _qty : 1.0,
        icon: _unit == 'kg' ? 'apple' : 'zap',
      );
    }

    cart.addLine(newItem);
    SoundService.instance.playProductAdd();

    setState(() {
      _directAmtStr = '';
      _rateStr = '';
      _qtyStr = '1';
      _activeInput = ActiveInput.rate;
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // 🔀 Mode Selector: Rate x Qty VS Direct ₹
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    SoundService.instance.playClick();
                    setState(() {
                      _mode = QuickSaleMode.rateQty;
                      _activeInput = ActiveInput.rate;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _mode == QuickSaleMode.rateQty
                          ? const Color(0xFF00875A)
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _mode == QuickSaleMode.rateQty
                            ? const Color(0xFF00875A)
                            : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.scale_rounded,
                          size: 16,
                          color: _mode == QuickSaleMode.rateQty ? Colors.white : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'भाव × वजन (Rate × Qty)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _mode == QuickSaleMode.rateQty ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    SoundService.instance.playClick();
                    setState(() {
                      _mode = QuickSaleMode.direct;
                      _activeInput = ActiveInput.direct;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _mode == QuickSaleMode.direct
                          ? const Color(0xFF2563EB)
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _mode == QuickSaleMode.direct
                            ? const Color(0xFF2563EB)
                            : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.currency_rupee_rounded,
                          size: 16,
                          color: _mode == QuickSaleMode.direct ? Colors.white : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'सीधा रुपया (Direct ₹)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _mode == QuickSaleMode.direct ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 📟 Display / LCD Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_mode == QuickSaleMode.rateQty) ...[
                  // Rate & Qty Dual Inputs
                  Row(
                    children: [
                      // Rate Input Box
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            SoundService.instance.playClick();
                            setState(() => _activeInput = ActiveInput.rate);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: _activeInput == ActiveInput.rate
                                  ? (isDark ? const Color(0xFF0F291E) : const Color(0xFFE8F5E9))
                                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _activeInput == ActiveInput.rate
                                    ? const Color(0xFF00875A)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'भाव (Rate ₹/$_unit)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _activeInput == ActiveInput.rate ? const Color(0xFF00875A) : Colors.grey,
                                      ),
                                    ),
                                    if (_activeInput == ActiveInput.rate)
                                      const Icon(Icons.edit, size: 12, color: Color(0xFF00875A)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹ ${_rateStr.isEmpty ? "0" : _rateStr}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                    color: _activeInput == ActiveInput.rate
                                        ? const Color(0xFF00875A)
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('×', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      // Qty / Weight Input Box
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            SoundService.instance.playClick();
                            setState(() => _activeInput = ActiveInput.qty);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: _activeInput == ActiveInput.qty
                                  ? (isDark ? const Color(0xFF0F291E) : const Color(0xFFE8F5E9))
                                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _activeInput == ActiveInput.qty
                                    ? const Color(0xFF00875A)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'वजन / मात्रा ($_unit)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _activeInput == ActiveInput.qty ? const Color(0xFF00875A) : Colors.grey,
                                      ),
                                    ),
                                    if (_activeInput == ActiveInput.qty)
                                      const Icon(Icons.edit, size: 12, color: Color(0xFF00875A)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_qtyStr.isEmpty ? "0" : _qtyStr} $_unit',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                    color: _activeInput == ActiveInput.qty
                                        ? const Color(0xFF00875A)
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Unit Toggle Chip
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          SoundService.instance.playClick();
                          setState(() {
                            _unit = (_unit == 'kg') ? 'pc' : 'kg';
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                          ),
                          child: Text(
                            _unit.toUpperCase(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF00875A)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Quick Weight Preset Chips (100g, 250g, 500g, 1kg, 2kg, 5kg)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip('100g', 0.1, isDark),
                        _buildPresetChip('250g', 0.25, isDark),
                        _buildPresetChip('500g', 0.5, isDark),
                        _buildPresetChip('1 kg', 1.0, isDark),
                        _buildPresetChip('2 kg', 2.0, isDark),
                        _buildPresetChip('5 kg', 5.0, isDark),
                      ],
                    ),
                  ),

                  const Divider(height: 16),

                  // Live Math Calculation Result Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'कुल मूल्य (Total Payable):',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '₹ ${_totalPayable.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00875A),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Direct ₹ Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text(
                        '₹',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _directAmtStr.isEmpty ? '0.00' : _directAmtStr,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: _directAmtStr.isEmpty ? Colors.grey.shade400 : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 6),

                // Item Name Quick Bar
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'सामान का नाम (e.g. आलू, प्याज, दाल, चीनी)',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 🔢 Keypad Grid
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
                    const SizedBox(height: 6),

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
                    const SizedBox(height: 6),

                    // Row 3 & 4: Left 3 cols (1 2 3, 0 00 .) & Right 1 col (Add Item Button)
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
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
                                const SizedBox(height: 6),
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
                          const SizedBox(width: 6),

                          // Right Column: Big "Add Item" Button
                          Expanded(
                            flex: 1,
                            child: Material(
                              color: _mode == QuickSaleMode.rateQty
                                  ? const Color(0xFF00875A)
                                  : const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(12),
                              elevation: 2,
                              child: InkWell(
                                onTap: _onAddItem,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 26),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'बिल में जोड़ें',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '(Add Item)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
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

  Widget _buildPresetChip(String label, double weight, bool isDark) {
    final isSelected = (_qtyStr == weight.toString() || (_qtyStr == weight.toInt().toString() && weight >= 1));
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => _setPresetWeight(weight),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00875A)
                : (isDark ? const Color(0xFF0F172A) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF00875A) : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumBtn(String text, bool isDark) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 1,
          child: InkWell(
            onTap: () => _onDigit(text),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              alignment: Alignment.center,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 24,
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
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 1,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
