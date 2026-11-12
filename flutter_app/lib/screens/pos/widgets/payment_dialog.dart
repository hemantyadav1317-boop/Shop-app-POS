import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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
import '../../../../core/utils/payment_qr_helper.dart';
import '../../../../data/models/sale.dart';
import '../../../../data/models/shop.dart';
import '../../../../data/services/supabase_service.dart';
import '../../../../data/services/upi_service.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../providers/shop_provider.dart';
import '../../../../providers/product_provider.dart';
import 'bill_receipt_card.dart';
import '../../../../core/services/ai_quote_service.dart';

class PaymentDialog extends StatefulWidget {
  final VoidCallback onSaleCompleted;

  const PaymentDialog({super.key, required this.onSaleCompleted});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _paymentMode = 'cash'; // 'cash', 'online', 'credit', 'split'
  late TextEditingController _paidController;
  late TextEditingController _upiController;
  bool _isSaving = false;
  Sale? _completedSale;
  bool _onlinePaymentVerified = false;
  late int _billNo;
  late final String _clientRef = const Uuid().v4();
  final ScreenshotController _screenshotController = ScreenshotController();
  BillQuote? _currentBillQuote;

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartProvider>();
    _paidController = TextEditingController(text: cart.total.toStringAsFixed(2));
    _upiController = TextEditingController(text: '0.00');
    _billNo = DateTime.now().millisecondsSinceEpoch % 100000;
    _loadQuote();
  }

  void _loadQuote() async {
    final quote = await AiQuoteService.getUniqueQuoteForBill();
    if (mounted) {
      setState(() {
        _currentBillQuote = quote;
      });
    }
  }

  @override
  void dispose() {
    _paidController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  void _onModeChanged(String mode) {
    SoundService.instance.playClick();
    final cart = context.read<CartProvider>();
    setState(() {
      _paymentMode = mode;
      _onlinePaymentVerified = false;
      if (mode == 'cash') {
        _paidController.text = cart.total.toStringAsFixed(2);
        _upiController.text = '0.00';
      } else if (mode == 'online') {
        _paidController.text = '0.00';
        _upiController.text = cart.total.toStringAsFixed(2);
      } else if (mode == 'credit') {
        _paidController.text = '0.00';
        _upiController.text = '0.00';
      } else if (mode == 'split') {
        final halfCash = PaymentQrHelper.round2(cart.total / 2);
        final remUpi = PaymentQrHelper.round2(math.max(0.0, cart.total - halfCash));
        _paidController.text = halfCash.toStringAsFixed(2);
        _upiController.text = remUpi.toStringAsFixed(2);
      }
    });
  }

  PaymentBreakdown _computeBreakdown(CartProvider cart) {
    final cashInput = double.tryParse(_paidController.text.trim()) ?? 0.0;
    final upiInput = double.tryParse(_upiController.text.trim()) ?? 0.0;
    return PaymentQrHelper.calculateBreakdown(
      total: cart.total,
      paymentMode: _paymentMode,
      cashAmount: cashInput,
      upiAmount: upiInput,
      onlineVerified: _onlinePaymentVerified,
      verificationSource: _paymentMode == 'online' || (_paymentMode == 'split' && upiInput > 0)
          ? (_onlinePaymentVerified ? 'cashier_verified' : 'unverified')
          : null,
    );
  }

  Sale _buildCurrentSale(Shop shop, CartProvider cart) {
    if (_completedSale != null) return _completedSale!;

    final breakdown = _computeBreakdown(cart);

    return Sale(
      id: _clientRef,
      shopId: shop.id,
      billNo: _billNo,
      customerId: cart.customer?.id,
      customerName: cart.customer?.name,
      customerPhone: cart.customer?.phone,
      items: List.from(cart.lines),
      subtotal: cart.subtotal,
      discount: cart.discount,
      total: cart.total,
      paid: breakdown.paid,
      due: breakdown.due,
      paymentMode: _paymentMode,
      paymentStatus: breakdown.paymentStatus,
      cashPaid: breakdown.cashPaid,
      upiPaid: breakdown.upiPaid,
      upiPayable: breakdown.upiPayable,
      creditAmount: breakdown.creditAmount,
      onlineVerified: breakdown.onlineVerified,
      verificationSource: breakdown.verificationSource,
      createdAt: DateTime.now(),
      clientRef: _clientRef,
    );
  }

  Future<void> _processCheckout() async {
    final cart = context.read<CartProvider>();
    final shop = context.read<ShopProvider>().shop;
    final productProv = context.read<ProductProvider>();

    if (cart.lines.isEmpty) return;

    // Validate stock if negative stock is disallowed by shop owner
    if (!shop.allowNegativeStock) {
      for (final item in cart.lines) {
        if (item.productId != null) {
          final prod = productProv.getProductById(item.productId);
          if (prod != null && prod.stock < item.qty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 4),
                content: Text(
                  prod.stock <= 0
                      ? '⚠️ \'${item.name}\' का स्टॉक खत्म है (0 उपलब्ध)! बिल नहीं काटा जा सकता।'
                      : '⚠️ \'${item.name}\' का स्टॉक केवल ${prod.stock} ${item.unit} उपलब्ध है (मांग: ${item.qty})!',
                ),
              ),
            );
            return;
          }
        }
      }
    }

    final isStaff = context.read<AuthProvider>().isStaffSession;
    if (isStaff && (_paymentMode == 'credit' || _paymentMode == 'split')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('सुरक्षा नियम: स्टाफ को उधार (Credit) देने की अनुमति नहीं है। केवल नकद या ऑनलाइन भुगतान लें।'),
        ),
      );
      return;
    }

    if (_paymentMode == 'split') {
      final splitErr = PaymentQrHelper.validateSplitAmounts(
        total: cart.total,
        cashAmount: double.tryParse(_paidController.text.trim()) ?? 0.0,
        upiAmount: double.tryParse(_upiController.text.trim()) ?? 0.0,
      );
      if (splitErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text(splitErr)),
        );
        return;
      }
    }

    final breakdown = _computeBreakdown(cart);

    if (_paymentMode == 'credit' && cart.customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('उधार बिक्री के लिए ग्राहक (Customer) चुनें!'),
        ),
      );
      return;
    }

    if (_paymentMode == 'split' && breakdown.creditAmount > 0.009 && cart.customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Split में उधार (Credit) राशि रखने के लिए ग्राहक (Customer) चुनें या Cash + UPI पूरा करें!'),
        ),
      );
      return;
    }

    final dueAmount = breakdown.due;

    // 🛑 Check Customer Credit Limit
    if ((_paymentMode == 'credit' || breakdown.creditAmount > 0.009) && cart.customer != null) {
      final creditPortion = _paymentMode == 'credit' ? breakdown.due : breakdown.creditAmount;
      final cust = cart.customer!;
      if (cust.creditLimit > 0 && (cust.balance + creditPortion) > cust.creditLimit) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (alertCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text('क्रेडिट लिमिट अलर्ट!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ग्राहक: ${cust.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('तय क्रेडिट लिमिट:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('₹ ${cust.creditLimit.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('वर्तमान बकाया:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('₹ ${cust.balance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFDC2626))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('इस बिल का उधार:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('₹ ${dueAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('नया कुल बकाया:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('₹ ${(cust.balance + dueAmount).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFDC2626))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'यह बिल ग्राहक की तय सीमा से ₹${((cust.balance + dueAmount) - cust.creditLimit).toStringAsFixed(2)} अधिक हो जाएगा। क्या आप फिर भी उधार देना चाहते हैं?',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(alertCtx, false),
                child: const Text('रद्द करें (Cancel)'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                onPressed: () => Navigator.pop(alertCtx, true),
                child: const Text('हाँ, उधार दें', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

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
        paid: breakdown.paid,
        due: breakdown.due,
        paymentMode: _paymentMode,
        paymentStatus: breakdown.paymentStatus,
        cashPaid: breakdown.cashPaid,
        upiPaid: breakdown.upiPaid,
        upiPayable: breakdown.upiPayable,
        creditAmount: breakdown.creditAmount,
        onlineVerified: breakdown.onlineVerified,
        verificationSource: breakdown.verificationSource,
        createdAt: DateTime.now(),
        clientRef: _clientRef,
      );

      final saved = await SupabaseService.instance.createSale(sale);

      // Immediately deduct in UI memory so stock decreases right away on screen
      productProv.deductStock(sale.items);

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

  Future<void> _handleDownload() async {
    SoundService.instance.playButtonClick();
    final shop = context.read<ShopProvider>().shop;
    final cart = context.read<CartProvider>();
    final sale = _completedSale ?? _buildCurrentSale(shop, cart);
    final userEmail = SupabaseService.instance.client?.auth.currentUser?.email;

    try {
      final savedFile = await ReceiptPrintService.downloadReceiptPdf(
        sale: sale,
        shop: shop,
        shopEmail: (userEmail != null && userEmail.isNotEmpty) ? userEmail : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00875A),
            duration: const Duration(seconds: 4),
            content: Text('बिल PDF सेव हो गया: ${savedFile.path.split(Platform.pathSeparator).last}'),
            action: SnackBarAction(
              label: 'Save / Open',
              textColor: Colors.white,
              onPressed: () {
                ReceiptPrintService.exportReceiptPdf(
                  sale: sale,
                  shop: shop,
                  shopEmail: (userEmail != null && userEmail.isNotEmpty) ? userEmail : null,
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('डाउनलोड एरर: $e')),
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

    final cashInput = double.tryParse(_paidController.text.trim()) ?? 0.0;
    final changeDue = (_paymentMode == 'cash' && cashInput > cart.total)
        ? (cashInput - cart.total)
        : 0.0;
    final breakdown = _computeBreakdown(cart);

    final checkoutUpiAmount = _paymentMode == 'online'
        ? cart.total
        : (_paymentMode == 'split' ? breakdown.upiDeclared : 0.0);

    final hasValidUpi = PaymentQrHelper.isValidUpiId(shop.upiId);
    final upiUri = (hasValidUpi && checkoutUpiAmount > 0.009)
        ? UpiService.generateUpiUri(
            upiId: shop.upiId!.trim(),
            payeeName: (shop.upiPayeeName != null && shop.upiPayeeName!.trim().isNotEmpty)
                ? shop.upiPayeeName!.trim()
                : shop.name,
            amount: checkoutUpiAmount,
            note: 'Bill #$_billNo',
            billNo: '$_billNo',
          )
        : null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 520;
            final maxDialogWidth = isTablet ? 520.0 : 440.0;
            return Container(
              constraints: BoxConstraints(maxWidth: maxDialogWidth, maxHeight: 760),
              child: _completedSale == null
                  ? _buildCheckoutStep(
                      context: context,
                      cart: cart,
                      shop: shop,
                      userEmail: userEmail,
                      breakdown: breakdown,
                      changeDue: changeDue,
                      checkoutUpiAmount: checkoutUpiAmount,
                      upiUri: upiUri,
                    )
                  : _buildCompletedReceiptStep(
                      context: context,
                      shop: shop,
                      userEmail: userEmail,
                    ),
            );
          },
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
    required PaymentBreakdown breakdown,
    required double changeDue,
    required double checkoutUpiAmount,
    required String? upiUri,
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
                    if (!context.watch<AuthProvider>().isStaffSession) ...[
                      const SizedBox(width: 6),
                      _buildModeTab('credit', 'उधार (Khata)'),
                      const SizedBox(width: 6),
                      _buildModeTab('split', 'Split'),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // Mode Specific Views:
                // 1. Online / Split UPI QR (Enlarged 1.5x-2x Responsive + Quiet Zone + Verified Toggle)
                if (_paymentMode == 'online' || (_paymentMode == 'split' && checkoutUpiAmount > 0.009)) ...[
                  LayoutBuilder(
                    builder: (context, qrConstraints) {
                      final qrSize = (qrConstraints.maxWidth * 0.68).clamp(210.0, 260.0);
                      final hasStandeeFallback = upiUri == null &&
                          shop.qrImageUrl != null &&
                          shop.qrImageUrl!.trim().isNotEmpty;

                      Widget renderQrVisual() {
                        // Always prioritize live Dynamic Amount UPI QR when valid UPI ID is set
                        if (upiUri != null && upiUri.isNotEmpty) {
                          return QrImageView(
                            data: upiUri,
                            version: QrVersions.auto,
                            size: qrSize,
                            backgroundColor: Colors.white,
                          );
                        }
                        if (hasStandeeFallback) {
                          final imgUrl = shop.qrImageUrl!.trim();
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: imgUrl.startsWith('data:image')
                                ? Image.memory(
                                    base64Decode(imgUrl.split(',').last),
                                    width: qrSize,
                                    height: qrSize,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => _buildNoUpiWarning(),
                                  )
                                : imgUrl.startsWith('http')
                                    ? Image.network(
                                        imgUrl,
                                        width: qrSize,
                                        height: qrSize,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) => _buildNoUpiWarning(),
                                      )
                                    : (!kIsWeb
                                        ? Image.file(
                                            File(imgUrl),
                                            width: qrSize,
                                            height: qrSize,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) => _buildNoUpiWarning(),
                                          )
                                        : _buildNoUpiWarning()),
                          );
                        }
                        return _buildNoUpiWarning();
                      }

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _onlinePaymentVerified ? Colors.green.shade400 : Colors.blue.shade200,
                            width: 1.4,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              _paymentMode == 'split'
                                  ? 'Split UPI QR कोड स्कैन करें (केवल UPI हिस्सा)'
                                  : 'UPI QR कोड स्कैन करें',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue),
                            ),
                            const SizedBox(height: 12),
                            // Center QR with generous Quiet Zone (16px white padding)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: renderQrVisual(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Payable: ${CurrencyFormatter.format(checkoutUpiAmount)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (shop.upiId != null && shop.upiId!.trim().isNotEmpty)
                              Text(
                                'UPI ID: ${shop.upiId!.trim()}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              )
                            else
                              const Text(
                                'UPI ID: सेट नहीं है (Settings में जोड़ें)',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.w600),
                              ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: _onlinePaymentVerified ? Colors.green.shade50 : Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _onlinePaymentVerified ? Colors.green.shade300 : Colors.amber.shade300,
                                ),
                              ),
                              child: CheckboxListTile(
                                title: const Text(
                                  'Payment प्राप्त हो गया (Verified)',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  _onlinePaymentVerified
                                      ? 'भुगतान सत्यापित ✓ — बिल में Google Review QR दिखेगा'
                                      : 'असत्यापित (Pending) — बिल में UPI Payment QR दिखेगा',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: _onlinePaymentVerified ? Colors.green.shade800 : Colors.amber.shade900,
                                  ),
                                ),
                                value: _onlinePaymentVerified,
                                onChanged: (val) {
                                  setState(() {
                                    _onlinePaymentVerified = val ?? false;
                                  });
                                },
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                controlAffinity: ListTileControlAffinity.leading,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // 2. Khata Notice with Credit Limit
                if (_paymentMode == 'credit') ...[
                  Builder(
                    builder: (context) {
                      final hasCustomer = cart.customer != null;
                      final isOverLimit = hasCustomer &&
                          cart.customer!.creditLimit > 0 &&
                          (cart.customer!.balance + cart.total) > cart.customer!.creditLimit;

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isOverLimit ? const Color(0xFFFEF2F2) : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isOverLimit ? const Color(0xFFFCA5A5) : Colors.amber.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isOverLimit ? Icons.warning_amber_rounded : Icons.info_outline,
                              color: isOverLimit ? const Color(0xFFDC2626) : Colors.amber.shade800,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hasCustomer
                                        ? 'ग्राहक: ${cart.customer!.name} के खाते में ${CurrencyFormatter.format(cart.total)} जुड़ेगा।'
                                        : 'कृपया पहले ग्राहक (Customer) सेलेक्ट करें।',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  if (hasCustomer && cart.customer!.creditLimit > 0) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      isOverLimit
                                          ? '⚠️ क्रेडिट लिमिट पार! तय सीमा: ₹${cart.customer!.creditLimit.toStringAsFixed(0)}, नया कुल बकाया: ₹${(cart.customer!.balance + cart.total).toStringAsFixed(0)}'
                                          : 'क्रेडिट लिमिट: ₹${cart.customer!.creditLimit.toStringAsFixed(0)} (शेष लिमिट: ₹${(cart.customer!.creditLimit - (cart.customer!.balance + cart.total)).toStringAsFixed(0)})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isOverLimit ? const Color(0xFFDC2626) : const Color(0xFF00875A),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // 3. Cash & Split Inputs
                if (_paymentMode == 'cash' || _paymentMode == 'split') ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      if (_paymentMode == 'split') ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'UPI राशि (₹)',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _upiController,
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
                      ],
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
                  if (_paymentMode == 'split') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: breakdown.creditAmount > 0 ? Colors.amber.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: breakdown.creditAmount > 0 ? Colors.amber.shade300 : Colors.green.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cash: ₹${breakdown.cashPaid.toStringAsFixed(0)} · UPI: ₹${breakdown.upiDeclared.toStringAsFixed(0)} (${_onlinePaymentVerified ? 'Paid ✓' : 'Pending'})',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'उधार: ₹${breakdown.creditAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: breakdown.creditAmount > 0 ? Colors.red.shade700 : Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  paid: breakdown.paid,
                  due: breakdown.due,
                  paymentMode: _paymentMode,
                  paymentStatus: breakdown.paymentStatus,
                  upiPayableAmount: breakdown.upiPayable,
                  onlineVerified: breakdown.onlineVerified,
                  cashPaid: breakdown.cashPaid,
                  upiPaid: breakdown.upiPaid,
                  creditAmount: breakdown.creditAmount,
                  footerMessage: shop.receiptFooter,
                  upiId: shop.upiId,
                  upiPayeeName: shop.upiPayeeName,
                  googleReviewUrl: shop.googleReviewUrl,
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
        // 1. Header Bar with Accurate Status Badge
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      sale.isFullyPaidAndVerified ? Icons.check_circle : Icons.pending_actions_rounded,
                      color: sale.isFullyPaidAndVerified ? Colors.green : Colors.amber.shade700,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sale.isFullyPaidAndVerified
                            ? 'बिल पूरा हो गया (Paid · #${sale.billNo})'
                            : (sale.effectiveUpiPayable > 0.009
                                ? 'Payment Pending · #${sale.billNo}'
                                : 'बिल सेव (उधार बाकी · #${sale.billNo})'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
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
                paymentStatus: sale.paymentStatus,
                upiPayableAmount: sale.effectiveUpiPayable,
                onlineVerified: sale.onlineVerified,
                cashPaid: sale.cashPaid,
                upiPaid: sale.upiPaid,
                creditAmount: sale.creditAmount,
                footerMessage: shop.receiptFooter,
                quoteLine1: _currentBillQuote?.line1,
                quoteLine2: _currentBillQuote?.line2,
                upiId: shop.upiId,
                upiPayeeName: shop.upiPayeeName,
                googleReviewUrl: shop.googleReviewUrl,
              ),
            ),
          ),
        ),

        const Divider(height: 1),

        // 3. Bottom Action Buttons (Back / Share / Download / Print)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: Colors.grey.shade50,
          child: Row(
            children: [
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
                        Icon(Icons.arrow_back, color: Color(0xFF2563EB), size: 22),
                        SizedBox(height: 3),
                        Text(
                          'नया बिल',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                        Icon(Icons.share, color: Color(0xFF16A34A), size: 22),
                        SizedBox(height: 3),
                        Text(
                          'Share Bill',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: _handleDownload,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_rounded, color: Color(0xFF0284C7), size: 22),
                        SizedBox(height: 3),
                        Text(
                          'Download',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                        Icon(Icons.print, color: Color(0xFF2563EB), size: 22),
                        SizedBox(height: 3),
                        Text(
                          'Print Bill',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
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

  Widget _buildNoUpiWarning() {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 36),
          SizedBox(height: 6),
          Text(
            'UPI QR उपलब्ध नहीं है',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown),
          ),
          SizedBox(height: 4),
          Text(
            'दुकानदार की UPI ID या QR फोटो सेटिंग्स में नहीं है। कृपया सेटिंग्स में दर्ज करें।',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
