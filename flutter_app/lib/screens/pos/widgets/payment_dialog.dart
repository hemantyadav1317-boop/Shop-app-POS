import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/receipt_print_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/sale.dart';
import '../../../../data/models/shop.dart';
import '../../../../data/services/supabase_service.dart';
import '../../../../data/services/upi_service.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../providers/shop_provider.dart';
import 'bill_receipt_card.dart';

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
  late int _billNo;
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartProvider>();
    _paidController = TextEditingController(text: cart.total.toStringAsFixed(2));
    _billNo = DateTime.now().millisecondsSinceEpoch % 100000;
  }

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }

  void _onModeChanged(String mode) {
    SoundService.instance.playClick();
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

  Sale _buildCurrentSale(Shop shop, CartProvider cart) {
    if (_completedSale != null) return _completedSale!;

    final paidAmount = double.tryParse(_paidController.text) ?? 0.0;
    final dueAmount = (cart.total - paidAmount) > 0 ? (cart.total - paidAmount) : 0.0;

    return Sale(
      id: const Uuid().v4(),
      shopId: shop.id,
      billNo: _billNo,
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
        billNo: _billNo,
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

      SoundService.instance.playSuccess();

      cart.clear();
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

  Future<void> _handlePrint() async {
    SoundService.instance.playButtonClick();
    final shop = context.read<ShopProvider>().shop;
    final cart = context.read<CartProvider>();
    final sale = _completedSale ?? _buildCurrentSale(shop, cart);

    try {
      final imageBytes = await _screenshotController.capture(pixelRatio: 2.0);
      await ReceiptPrintService.printReceipt(
        sale: sale,
        shop: shop,
        imageBytes: imageBytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('प्रिंट एरर: $e')),
        );
      }
    }
  }

  Future<void> _handleShare() async {
    SoundService.instance.playButtonClick();
    final shop = context.read<ShopProvider>().shop;
    final cart = context.read<CartProvider>();
    final sale = _completedSale ?? _buildCurrentSale(shop, cart);

    try {
      final imageBytes = await _screenshotController.capture(pixelRatio: 2.0);
      await ReceiptPrintService.shareReceipt(
        sale: sale,
        shop: shop,
        imageBytes: imageBytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('शेयर एरर: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final shop = context.watch<ShopProvider>().shop;
    final userEmail = SupabaseService.instance.client?.auth.currentUser?.email;

    final paidAmount = double.tryParse(_paidController.text) ?? 0.0;
    final changeDue = (paidAmount - cart.total) > 0 ? (paidAmount - cart.total) : 0.0;
    final remainingUdhar = (cart.total - paidAmount) > 0 ? (cart.total - paidAmount) : 0.0;

    final upiUri = UpiService.generateUpiUri(
      upiId: shop.upiId ?? '9876543210@upi',
      payeeName: shop.upiPayeeName ?? shop.name,
      amount: _paymentMode == 'split' ? remainingUdhar : cart.total,
      note: 'Bill #$_billNo',
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SafeArea(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 720),
          child: _completedSale == null
              ? _buildCheckoutStep(
                  context: context,
                  cart: cart,
                  shop: shop,
                  userEmail: userEmail,
                  paidAmount: paidAmount,
                  changeDue: changeDue,
                  remainingUdhar: remainingUdhar,
                  upiUri: upiUri,
                )
              : _buildCompletedReceiptStep(
                  context: context,
                  shop: shop,
                  userEmail: userEmail,
                ),
        ),
      ),
    );
  }

  /// STEP 1: PAYMENT & CHECKOUT VIEW (Payment options + Bill preview + Complete Bill button)
  Widget _buildCheckoutStep({
    required BuildContext context,
    required CartProvider cart,
    required Shop shop,
    required String? userEmail,
    required double paidAmount,
    required double changeDue,
    required double remainingUdhar,
    required String upiUri,
  }) {
    return Column(
      children: [
        // 1. Header Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.payment, size: 20, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'चेकआउट व भुगतान (Payment)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 2. Scrollable Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Total Payable Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'कुल देय राशि (Total Payable)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(cart.total),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              '${cart.lines.length} सामान (Items)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                          if (cart.customer != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'ग्राहक: ${cart.customer!.name}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Mode Selection Title
                const Text(
                  'भुगतान का तरीका चुनें (Payment Mode):',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 8),

                // Payment Mode Tabs
                Row(
                  children: [
                    _buildModeTab('cash', 'नकद (Cash)'),
                    const SizedBox(width: 6),
                    _buildModeTab('online', 'ऑनलाइन (UPI)'),
                    const SizedBox(width: 6),
                    _buildModeTab('credit', 'उधार (Khata)'),
                    const SizedBox(width: 6),
                    _buildModeTab('split', 'Split'),
                  ],
                ),
                const SizedBox(height: 14),

                // Mode Specific Views:
                // 1. Online UPI QR
                if (_paymentMode == 'online' || (_paymentMode == 'split' && remainingUdhar > 0)) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text('UPI QR कोड स्कैन करें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                        const SizedBox(height: 8),
                        Center(
                          child: shop.qrImageUrl != null && shop.qrImageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: shop.qrImageUrl!.startsWith('data:image')
                                      ? Image.memory(
                                          base64Decode(shop.qrImageUrl!.split(',').last),
                                          width: 150,
                                          height: 150,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) => QrImageView(data: upiUri, size: 140.0, backgroundColor: Colors.white),
                                        )
                                      : shop.qrImageUrl!.startsWith('http')
                                          ? Image.network(
                                              shop.qrImageUrl!,
                                              width: 150,
                                              height: 150,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) => QrImageView(data: upiUri, size: 140.0, backgroundColor: Colors.white),
                                            )
                                          : (!kIsWeb
                                              ? Image.file(
                                                  File(shop.qrImageUrl!),
                                                  width: 150,
                                                  height: 150,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (context, error, stackTrace) => QrImageView(data: upiUri, size: 140.0, backgroundColor: Colors.white),
                                                )
                                              : QrImageView(data: upiUri, size: 140.0, backgroundColor: Colors.white)),
                                )
                              : QrImageView(data: upiUri, size: 140.0, backgroundColor: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          CurrencyFormatter.format(_paymentMode == 'split' ? remainingUdhar : cart.total),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                        ),
                        Text('UPI ID: ${shop.upiId ?? "9876543210@upi"}', style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
                        const SizedBox(height: 6),
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

                // 2. Khata Notice
                if (_paymentMode == 'credit') ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cart.customer != null
                                ? 'ग्राहक: ${cart.customer!.name} के खाते में ${CurrencyFormatter.format(cart.total)} जुड़ेगा।'
                                : 'कृपया पहले ग्राहक (Customer) सेलेक्ट करें।',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 3. Cash Inputs
                if (_paymentMode == 'cash' || _paymentMode == 'split') ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _paymentMode == 'split' ? 'Cash प्राप्त (₹)' : 'Customer दिया Cash (₹)',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _paidController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              decoration: const InputDecoration(
                                prefixText: '₹ ',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                      if (_paymentMode == 'cash' && changeDue > 0) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
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
                  const SizedBox(height: 12),
                ],

                // 4. Bill Receipt Preview (loaded right below the payment inputs)
                const SizedBox(height: 8),
                const Divider(thickness: 1.2),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.receipt_long, size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 6),
                    Text(
                      'बिल रसीद (Bill Preview):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                BillReceiptCard(
                  shopName: shop.name,
                  shopAddress: shop.address,
                  shopPhone: shop.phone,
                  shopEmail: (userEmail != null && userEmail.isNotEmpty) ? userEmail : null,
                  gstin: shop.gstin,
                  billNo: '$_billNo',
                  dateString: DateFormat('dd-MM-yyyy h:mm a').format(DateTime.now()),
                  customerName: cart.customer?.name,
                  customerPhone: cart.customer?.phone,
                  items: cart.lines,
                  subtotal: cart.subtotal,
                  discount: cart.discount,
                  total: cart.total,
                  paid: paidAmount > cart.total ? cart.total : paidAmount,
                  due: (cart.total - paidAmount) > 0 ? (cart.total - paidAmount) : 0.0,
                  paymentMode: _paymentMode,
                  footerMessage: shop.receiptFooter,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        const Divider(height: 1),

        // 3. Bottom Action Bar for Step 1: Cancel + Big Complete Bill Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey.shade50,
          child: Row(
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('रद्द करें (Cancel)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 1,
                  ),
                  onPressed: _isSaving ? null : _processCheckout,
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          'बिल पूरा करें · ${CurrencyFormatter.format(cart.total)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// STEP 2: BILL COMPLETED VIEW (Shows full BillReceiptCard + Print/Share/New Sale buttons)
  Widget _buildCompletedReceiptStep({
    required BuildContext context,
    required Shop shop,
    required String? userEmail,
  }) {
    final sale = _completedSale!;
    final dateString = DateFormat('dd-MM-yyyy h:mm a').format(sale.createdAt);

    return Column(
      children: [
        // 1. Header Bar with Success Badge
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'बिल पूरा हो गया (Invoice #${sale.billNo})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSaleCompleted();
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 2. Scrollable Bill Receipt Card
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Screenshot(
              controller: _screenshotController,
              child: BillReceiptCard(
                shopName: shop.name,
                shopAddress: shop.address,
                shopPhone: shop.phone,
                shopEmail: (userEmail != null && userEmail.isNotEmpty) ? userEmail : null,
                gstin: shop.gstin,
                billNo: '${sale.billNo}',
                dateString: dateString,
                customerName: sale.customerName,
                customerPhone: sale.customerPhone,
                items: sale.items,
                subtotal: sale.subtotal,
                discount: sale.discount,
                total: sale.total,
                paid: sale.paid,
                due: sale.due,
                paymentMode: sale.paymentMode,
                footerMessage: shop.receiptFooter,
              ),
            ),
          ),
        ),

        const Divider(height: 1),

        // 3. Bottom 3 Action Buttons (Only shown AFTER bill is completed!)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.grey.shade50,
          child: Row(
            children: [
              // Back / New Sale Button (Closes dialog and readies next cart)
              Expanded(
                child: InkWell(
                  onTap: () {
                    SoundService.instance.playButtonClick();
                    Navigator.pop(context);
                    widget.onSaleCompleted();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, color: Color(0xFF2563EB), size: 24),
                        SizedBox(height: 4),
                        Text(
                          'वापस / नया बिल',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Share Bill Button
              Expanded(
                child: InkWell(
                  onTap: () {
                    SoundService.instance.playButtonClick();
                    _handleShare();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share, color: Color(0xFF2563EB), size: 24),
                        SizedBox(height: 4),
                        Text(
                          'शेयर (Share Bill)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Print Bill Button
              Expanded(
                child: InkWell(
                  onTap: () {
                    SoundService.instance.playButtonClick();
                    _handlePrint();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.print, color: Color(0xFF2563EB), size: 24),
                        SizedBox(height: 4),
                        Text(
                          'प्रिंट (Print Bill)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeTab(String mode, String label) {
    final isSelected = _paymentMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          SoundService.instance.playButtonClick();
          _onModeChanged(mode);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.lightMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.lightBorder),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
