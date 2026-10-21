import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/pos_sound_formatter.dart';
import '../../../../data/models/cart_item.dart';

class QuickSellDialog extends StatefulWidget {
  final Function(CartItem) onConfirm;

  const QuickSellDialog({super.key, required this.onConfirm});

  @override
  State<QuickSellDialog> createState() => _QuickSellDialogState();
}

class _QuickSellDialogState extends State<QuickSellDialog> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _rateController = TextEditingController();
  String _selectedUnit = 'kg';

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qty = double.tryParse(_qtyController.text) ?? 1.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final total = qty * rate;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '⚡ Quick Sell (त्वरित बिक्री)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Item Name
              const Text('सामान का नाम / Item Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'जैसे: स्पेशल आर्डर, साबुन, तेल',
                ),
              ),
              const SizedBox(height: 12),

              // Qty and Rate
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('मात्रा / Qty', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _qtyController,
                          inputFormatters: [PosNumberSoundFormatter()],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('दर / Rate', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _rateController,
                          inputFormatters: [PosNumberSoundFormatter()],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(prefixText: '₹ '),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Unit selector
              const Text('इकाई / Unit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: ['kg', 'pc', 'litre', 'pkt'].map((u) {
                  final isSelected = _selectedUnit == u;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(u.toUpperCase()),
                      selected: isSelected,
                      selectedColor: AppColors.primarySurface,
                      onSelected: (_) {
                        setState(() {
                          _selectedUnit = u;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Total preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Amount:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      CurrencyFormatter.format(total),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add to Bill'),
                onPressed: () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty || rate <= 0 || qty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('कृपया सही नाम, मात्रा और दर दर्ज करें')),
                    );
                    return;
                  }

                  widget.onConfirm(CartItem(
                    name: name,
                    unit: _selectedUnit,
                    price: rate,
                    qty: qty,
                  ));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
