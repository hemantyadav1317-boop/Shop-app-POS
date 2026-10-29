import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/product.dart';
import '../../../../data/models/cart_item.dart';
import '../../../../providers/shop_provider.dart';
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
  bool _isEditingRate = false;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty > 0 ? widget.initialQty : 1.0;
    _rate = widget.product.price;
    _qtyController = TextEditingController(text: _formatQty(_qty));
    _rateController = TextEditingController(text: _rate.toStringAsFixed(2));

    _qtyController.addListener(_handleQtyChange);
    _rateController.addListener(_handleRateChange);
  }

  void _handleQtyChange() {
    final text = _qtyController.text.trim();
    if (text.isEmpty || text == '.') {
      setState(() => _qty = 0.0);
      return;
    }
    final parsed = double.tryParse(text);
    if (parsed != null && parsed >= 0) {
      setState(() => _qty = parsed);
    }
  }

  void _handleRateChange() {
    final text = _rateController.text.trim();
    if (text.isEmpty) {
      setState(() => _rate = 0.0);
      return;
    }
    final parsed = double.tryParse(text);
    if (parsed != null && parsed >= 0) {
      setState(() => _rate = parsed);
    }
  }

  String _formatQty(double q) {
    if (q % 1 == 0) return q.toInt().toString();
    return q.toString();
  }

  @override
  void dispose() {
    _qtyController.removeListener(_handleQtyChange);
    _rateController.removeListener(_handleRateChange);
    _qtyController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _adjustQty(double delta) {
    SoundService.instance.playClick();
    double newQty = _qty + delta;
    if (newQty < 0.05) newQty = 0.05;
    newQty = double.parse(newQty.toStringAsFixed(3));
    _qtyController.text = _formatQty(newQty);
  }

  void _setDirectWeight(double val) {
    SoundService.instance.playClick();
    _qtyController.text = _formatQty(val);
  }

  void _confirmAndSubmit() {
    if (_qty <= 0) return;

    final shop = context.read<ShopProvider>().shop;
    if (!shop.allowNegativeStock) {
      if (widget.product.stock <= 0) {
        SoundService.instance.playError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('⚠️ \'${widget.product.name}\' का स्टॉक खत्म है (0 उपलब्ध)!'),
          ),
        );
        return;
      }
      if (_qty > widget.product.stock) {
        SoundService.instance.playError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('⚠️ स्टॉक में केवल ${widget.product.stock} ${widget.product.unit} ही उपलब्ध हैं!'),
          ),
        );
        return;
      }
    }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                          'स्टॉक: ${widget.product.stock} ${widget.product.unit}  •  दर: ₹${widget.product.price.toStringAsFixed(2)}/${widget.product.unit}',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.product.isLowStock ? AppColors.error : AppColors.lightTextSecondary,
                            fontWeight: widget.product.isLowStock ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (widget.product.stock <= 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: const Text(
                              '⚠️ आउट ऑफ स्टॉक / Out of Stock',
                              style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
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

            // 2. SCROLLABLE BODY (Quantity, Rate, Tactile Numpad)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Quantity and Rate selector tabs
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isEditingRate = false),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !_isEditingRate
                                    ? AppColors.primarySurface
                                    : (isDark ? Colors.white10 : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: !_isEditingRate ? AppColors.primary : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'मात्रा (${widget.product.unit})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: !_isEditingRate ? AppColors.primary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _qtyController.text.isNotEmpty ? '${_qtyController.text} ${widget.product.unit}' : '0 ${widget.product.unit}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: !_isEditingRate ? AppColors.primary : (isDark ? Colors.white : Colors.black87),
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
                            onTap: () => setState(() => _isEditingRate = true),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _isEditingRate
                                    ? AppColors.primarySurface
                                    : (isDark ? Colors.white10 : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _isEditingRate ? AppColors.primary : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'दर (₹ प्रति ${widget.product.unit})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _isEditingRate ? AppColors.primary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹ ${_rateController.text}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _isEditingRate ? AppColors.primary : (isDark ? Colors.white : Colors.black87),
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

                    // Quick weight shortcuts if product is in Kg
                    if (isKg && !_isEditingRate) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: [
                          {'label': '100g', 'val': 0.1},
                          {'label': '200g', 'val': 0.2},
                          {'label': '250g', 'val': 0.25},
                          {'label': '500g', 'val': 0.5},
                          {'label': '1 kg', 'val': 1.0},
                          {'label': '2 kg', 'val': 2.0},
                        ].map((w) {
                          final double v = w['val'] as double;
                          final isSel = (_qty - v).abs() < 0.001;
                          return InkWell(
                            onTap: () => _setDirectWeight(v),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSel ? AppColors.primary : (isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                w['label'] as String,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isSel ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Quick +/- stepper
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () => _adjustQty(isKg ? -0.25 : -1.0),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Icon(Icons.remove, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          !_isEditingRate ? '${_formatQty(_qty)} ${widget.product.unit}' : '₹ ${_rate.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 14),
                        OutlinedButton(
                          onPressed: () => _adjustQty(isKg ? 0.25 : 1.0),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Icon(Icons.add, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Tactile POS Touch Keypad (Directly operates without mobile keyboard)
                    PosNumpad(
                      controller: !_isEditingRate ? _qtyController : _rateController,
                      onChanged: (val) {
                        if (!_isEditingRate) {
                          _handleQtyChange();
                        } else {
                          _handleRateChange();
                        }
                      },
                    ),
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
                          fontSize: 22,
                          color: Color(0xFF00875A),
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
                      backgroundColor: const Color(0xFF00875A),
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
