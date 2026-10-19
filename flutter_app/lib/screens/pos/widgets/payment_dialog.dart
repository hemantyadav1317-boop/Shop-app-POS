import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/receipt_print_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/sale.dart';
import '../../../../data/services/supabase_service.dart';
import '../../../../data/services/upi_service.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../providers/shop_provider.dart';

class PaymentDialog extends StatefulWidget {
  final VoidCallback onSaleCompleted;

  const PaymentDialog({super.key, required this.onSaleCompleted});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _paymentMode = 'cash'; // 'cash', 'online', 'credit', 'split'
  late TextEditingController _paidController;
  bool _isSaving = false;
  Sale? _completedSale;
  bool _onlinePaymentVerified = false;

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartProvider>();
    _paidController = TextEditingController(text: cart.total.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }

  void _onModeChanged(String mode) {
    final cart = context.read<CartProvider>();
    setState(() {
      _paymentMode = mode;
      if (mode == 'cash') {
        _paidController.text = cart.total.toStringAsFixed(2);
      } else if (mode == 'online') {
        _paidController.text = cart.total.toStringAsFixed(2);
      } else if (mode == 'credit') {
        _paidController.text = '0.00';
      } else if (mode == 'split') {
        _paidController.text = (cart.total / 2).toStringAsFixed(2);
      }
    });
  }

  Future<void> _processCheckout() async {
    final cart = context.read<CartProvider>();
    final shop = context.read<ShopProvider>().shop;

    if (cart.lines.isEmpty) return;

    if (_paymentMode == 'credit' && cart.customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('उधार बिक्री के लिए ग्राहक (Customer) चुनें!'),
        ),
      );
      return;
    }

    final paidAmount = double.tryParse(_paidController.text) ?? 0.0;
    final dueAmount = (cart.total - paidAmount) > 0 ? (cart.total - paidAmount) : 0.0;

    setState(() {
      _isSaving = true;
    });

    try {
      final sale = Sale(
        id: const Uuid().v4(),
        shopId: shop.id,
        billNo: DateTime.now().millisecondsSinceEpoch % 100000,
        customerId: cart.customer?.id,
        customerName: cart.customer?.name,
        customerPhone: cart.customer?.phone,
        items: List.from(cart.lines),
        subtotal: cart.subtotal,
        discount: cart.discount,
        total: cart.total,
        paid: paidAmount > cart.total ? cart.total : paidAmount,
        due: dueAmount,
        paymentMode: _paymentMode,
        paymentStatus: dueAmount == 0 ? 'completed' : 'pending',
        createdAt: DateTime.now(),
        clientRef: const Uuid().v4(),
      );

      final saved = await SupabaseService.instance.createSale(sale);

      setState(() {
        _completedSale = saved;
        _isSaving = false;
      });

      cart.clear();
      widget.onSaleCompleted();
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Error saving sale: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final shop = context.watch<ShopProvider>().shop;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: _completedSale != null
              ? _buildCompletedView(_completedSale!, shop)
              : _buildCheckoutView(cart, shop),
        ),
      ),
    );
  }

  Widget _buildCheckoutView(CartProvider cart, shop) {
    final paidAmount = double.tryParse(_paidController.text) ?? 0.0;
    final changeDue = (paidAmount - cart.total) > 0 ? (paidAmount - cart.total) : 0.0;
    final remainingUdhar = (cart.total - paidAmount) > 0 ? (cart.total - paidAmount) : 0.0;

    // Generate UPI QR String
    final upiUri = UpiService.generateUpiUri(
      upiId: shop.upiId ?? '9876543210@upi',
      payeeName: shop.upiPayeeName ?? shop.name,
      amount: _paymentMode == 'split' ? remainingUdhar : cart.total,
      note: 'Bill Payment',
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'भुगतान / Checkout',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Total Amount Banner
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${cart.itemCount} Items (${cart.totalQty} Qty)', style: const TextStyle(fontSize: 12, color: AppColors.primaryDark)),
                  if (cart.discount > 0)
                    Text('Discount: ${CurrencyFormatter.format(cart.discount)}', style: const TextStyle(fontSize: 11, color: AppColors.error)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('कुल देय / Total Payable', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                  Text(
                    CurrencyFormatter.format(cart.total),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppColors.primaryDark),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Payment Mode Selector Tabs
        Row(
          children: [
            _buildModeTab('cash', '💵 Cash', Icons.money),
            const SizedBox(width: 6),
            _buildModeTab('online', '📲 UPI QR', Icons.qr_code),
            const SizedBox(width: 6),
            _buildModeTab('credit', '📒 उधार', Icons.book),
            const SizedBox(width: 6),
            _buildModeTab('split', '⚡ Split', Icons.call_split),
          ],
        ),
        const SizedBox(height: 16),

        // Online UPI QR Display
        if (_paymentMode == 'online' || (_paymentMode == 'split' && remainingUdhar > 0)) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightBorder),
            ),
            child: Column(
              children: [
                const Text('UPI QR कोड स्कैन करके भुगतान करें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.lightTextPrimary)),
                const SizedBox(height: 8),
                Center(
                  child: shop.qrImageUrl != null && (shop.qrImageUrl as String).isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: (shop.qrImageUrl as String).startsWith('http')
                              ? Image.network(
                                  shop.qrImageUrl as String,
                                  width: 170,
                                  height: 170,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => QrImageView(
                                    data: upiUri,
                                    version: QrVersions.auto,
                                    size: 160.0,
                                    backgroundColor: Colors.white,
                                  ),
                                )
                              : Image.file(
                                  File(shop.qrImageUrl as String),
                                  width: 170,
                                  height: 170,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => QrImageView(
                                    data: upiUri,
                                    version: QrVersions.auto,
                                    size: 160.0,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                        )
                      : QrImageView(
                          data: upiUri,
                          version: QrVersions.auto,
                          size: 160.0,
                          backgroundColor: Colors.white,
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.format(_paymentMode == 'split' ? remainingUdhar : cart.total),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                ),
                Text('UPI ID: ${shop.upiId ?? "9876543210@upi"}', style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
                const SizedBox(height: 10),
                CheckboxListTile(
                  title: const Text('Payment प्राप्त हो गया (Verified)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  value: _onlinePaymentVerified,
                  onChanged: (val) {
                    setState(() {
                      _onlinePaymentVerified = val ?? false;
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Credit (Khata) Mode Details
        if (_paymentMode == 'credit') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cart.customer != null
                        ? 'ग्राहक: ${cart.customer!.name} के खाते में ${CurrencyFormatter.format(cart.total)} जुड़ेगा।'
                        : 'कृपया कार्ट में ग्राहक (Customer) सेलेक्ट करें।',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Paid Amount Input (For Cash / Split)
        if (_paymentMode == 'cash' || _paymentMode == 'split') ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_paymentMode == 'split' ? 'Cash प्राप्त' : 'Customer दिया Cash', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _paidController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      decoration: const InputDecoration(prefixText: '₹ '),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              if (_paymentMode == 'cash' && changeDue > 0) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Change वापसी:', style: TextStyle(fontSize: 11, color: Colors.blue)),
                        Text(CurrencyFormatter.format(changeDue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Confirm Bill Button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _isSaving ? null : _processCheckout,
          child: _isSaving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('बिल पूरा करें · ${CurrencyFormatter.format(cart.total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildModeTab(String mode, String label, IconData icon) {
    final isSelected = _paymentMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => _onModeChanged(mode),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.lightMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.lightBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedView(Sale sale, shop) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: AppColors.primary, size: 54),
        const SizedBox(height: 8),
        const Text('बिल सफलतापूर्वक बन गया!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text('Invoice #${sale.billNo}', style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13)),
        const SizedBox(height: 16),

        // Mini Receipt Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.lightMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightBorder),
          ),
          child: Column(
            children: [
              Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              if (shop.phone != null) Text(shop.phone!, style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
              const Divider(),
              ...sale.items.map((it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('${it.name} (${it.qty} ${it.unit})', style: const TextStyle(fontSize: 12))),
                        Text(CurrencyFormatter.format(it.total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('कुल राशि / Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(CurrencyFormatter.format(sale.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mode: ${sale.paymentMode.toUpperCase()}', style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
                  Text('Paid: ${CurrencyFormatter.format(sale.paid)}', style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Action Buttons: Print Bill, Share, and New Sale
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.print, size: 20),
            label: const Text(
              'बिल प्रिंट करें (Print Bill)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            onPressed: () async {
              try {
                await ReceiptPrintService.printReceipt(sale: sale, shop: shop);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: AppColors.error, content: Text('प्रिंट एरर: $e')),
                  );
                }
              }
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share PDF'),
                onPressed: () async {
                  try {
                    await ReceiptPrintService.shareReceipt(sale: sale, shop: shop);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('शेयर एरर: $e')),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: const Text('नया बिल (Next)'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
