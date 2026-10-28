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
  late FocusNode _qtyFocusNode;
  late double _qty;
  late double _rate;
  final bool _showNumpad = true; // Default Open as requested

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty > 0 ? widget.initialQty : 1.0;
    _rate = widget.product.price;
    _qtyController = TextEditingController(text: _formatQty(_qty));
    _rateController = TextEditingController(text: _rate.toStringAsFixed(2));
    _qtyFocusNode = FocusNode();

    // Auto-focus quantity field on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _qtyFocusNode.requestFocus();
      }
    });
  }

  String _formatQty(double q) {
    if (q % 1 == 0) return q.toInt().toString();
    return q.toString();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _rateController.dispose();
    _qtyFocusNode.dispose();
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

  void _confirmAndSubmit() {
    if (_qty <= 0) return;
    SoundService.instance.playSuccess();
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
  }

  @override
  Widget build(BuildContext context) {
    final isKg = widget.product.unit.toLowerCase() == 'kg';
    final totalAmount = _qty * _rate;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HEADER (Product Info & Close)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Row(
                children: [
                  ProductImageView(
                    imageUrl: widget.product.imageUrl,
                    fallbackIcon: widget.product.icon,
                    size: 42,
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
                        const SizedBox(height: 2),
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
                    icon: const Icon(Icons.close, color: AppColors.lightTextSecondary, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 2. SCROLLABLE BODY (Qty, Rate, Tactile Numpad)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Quantity Selector Row
                    Text(
                      'मात्रा / Quantity (${widget.product.unit})',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => _adjustQty(isKg ? -0.25 : -1.0),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Icon(Icons.remove, size: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _qtyController,
                            focusNode: _qtyFocusNode,
                            inputFormatters: [PosNumberSoundFormatter()],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primaryDark),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Icon(Icons.add, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Rate per unit
                    Text(
                      'दर / Rate (₹ प्रति ${widget.product.unit})',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _rateController,
                      inputFormatters: [PosNumberSoundFormatter()],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val) ?? widget.product.price;
                        setState(() {
                          _rate = parsed;
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    // Tactile POS Touch Keypad (Always Visible)
                    if (_showNumpad) ...[
                      const Text(
                        'टच कीपैड (Tactile Pad)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.lightTextSecondary),
                      ),
                      const SizedBox(height: 4),
                      PosNumpad(controller: _qtyController),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // 3. PERSISTENT BOTTOM ACTION BAR (Never scrolls off screen)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Total Amount Preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'कुल राशि / Amount:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        CurrencyFormatter.format(totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Big Sticky Add to Bill Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text(
                      'बिल में जोड़ें / Add to Bill',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    onPressed: _confirmAndSubmit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
