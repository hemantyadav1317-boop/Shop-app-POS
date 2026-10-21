import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/pos_sound_formatter.dart';
import '../../../../data/models/product.dart';
import '../../../../data/models/cart_item.dart';
import 'package:shop_pos/screens/widgets/product_image_view.dart';
import 'pos_numpad.dart';

class QtyRateDialog extends StatefulWidget {
  final Product product;
  final double initialQty;
  final Function(CartItem) onConfirm;

  const QtyRateDialog({
    super.key,
    required this.product,
    this.initialQty = 1.0,
    required this.onConfirm,
  });

  @override
  State<QtyRateDialog> createState() => _QtyRateDialogState();
}

class _QtyRateDialogState extends State<QtyRateDialog> {
  late TextEditingController _qtyController;
  late TextEditingController _rateController;
  late double _qty;
  late double _rate;
  bool _showNumpad = true;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty > 0 ? widget.initialQty : 1.0;
    _rate = widget.product.price;
    _qtyController = TextEditingController(text: _formatQty(_qty));
    _rateController = TextEditingController(text: _rate.toStringAsFixed(2));
  }

  String _formatQty(double q) {
    if (q % 1 == 0) return q.toInt().toString();
    return q.toString();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _adjustQty(double delta) {
    SoundService.instance.playClick();
    setState(() {
      _qty = (_qty + delta);
      if (_qty < 0.1) _qty = 0.1;
      _qty = double.parse(_qty.toStringAsFixed(3));
      _qtyController.text = _formatQty(_qty);
    });
  }

  void _setDirectQty(double val) {
    SoundService.instance.playClick();
    setState(() {
      _qty = val;
      _qtyController.text = _formatQty(_qty);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isKg = widget.product.unit.toLowerCase() == 'kg';
    final quickButtons = isKg ? [0.25, 0.5, 1.0, 2.0, 5.0] : [1.0, 2.0, 5.0, 10.0, 12.0];
    final totalAmount = _qty * _rate;

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
              // Header
              Row(
                children: [
                  ProductImageView(
                    imageUrl: widget.product.imageUrl,
                    fallbackIcon: widget.product.icon,
                    size: 40,
                    borderRadius: 8,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Stock: ${widget.product.stock} ${widget.product.unit}',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.product.isLowStock ? AppColors.error : AppColors.lightTextSecondary,
                            fontWeight: widget.product.isLowStock ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quantity Selector
              Text('मात्रा / Quantity (${widget.product.unit})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => _adjustQty(isKg ? -0.25 : -1.0),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      inputFormatters: [PosNumberSoundFormatter()],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      onChanged: (val) {
                        final parsed = double.tryParse(val) ?? 1.0;
                        setState(() {
                          _qty = parsed;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _adjustQty(isKg ? 0.25 : 1.0),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Quick Quantity Chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: quickButtons.map((btnVal) {
                  final isSelected = (_qty - btnVal).abs() < 0.01;
                  return ChoiceChip(
                    label: Text('${_formatQty(btnVal)} ${widget.product.unit}'),
                    selected: isSelected,
                    onSelected: (_) => _setDirectQty(btnVal),
                    selectedColor: AppColors.primarySurface,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : null,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Rate per unit
              Text('दर / Rate (₹ प्रति ${widget.product.unit})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _rateController,
                inputFormatters: [PosNumberSoundFormatter()],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val) ?? widget.product.price;
                  setState(() {
                    _rate = parsed;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Tactile POS Quick Touch Numpad Header & Widget
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('टच कीपैड (Tactile Pad)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  TextButton(
                    onPressed: () => setState(() => _showNumpad = !_showNumpad),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
                    child: Text(_showNumpad ? 'छुपाएं (Hide)' : 'दिखाएं (Show)', style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                  ),
                ],
              ),
              if (_showNumpad) ...[
                const SizedBox(height: 4),
                PosNumpad(controller: _qtyController),
              ],
              const SizedBox(height: 14),

              // Total Amount Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('कुल राशि / Amount:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      CurrencyFormatter.format(totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Submit Button
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('बिल में जोड़ें / Add to Bill'),
                onPressed: () {
                  if (_qty <= 0) return;
                  widget.onConfirm(CartItem(
                    productId: widget.product.id,
                    name: widget.product.name,
                    unit: widget.product.unit,
                    price: _rate,
                    qty: _qty,
                    imageUrl: widget.product.imageUrl,
                    icon: widget.product.icon,
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
