import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/receipt_print_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/payment_qr_helper.dart';
import '../../data/models/sale.dart';
import '../../providers/cart_provider.dart';
import '../../providers/customer_provider.dart';
import '../../data/services/local_db_service.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../core/services/sound_service.dart';
import '../main_shell.dart';
import '../pos/widgets/bill_receipt_card.dart';
import '../../core/services/ai_quote_service.dart';
import '../../providers/locale_provider.dart';

class BillsScreen extends StatefulWidget {
  final VoidCallback? onSwitchToBilling;

  const BillsScreen({super.key, this.onSwitchToBilling});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  List<Sale> _sales = [];
  bool _isLoading = true;
  String _filter = 'all'; // 'all', 'credit', 'online', 'cash'
  String _dateFilter = 'all'; // 'all', 'today', 'yesterday', 'this_week', 'custom'
  DateTime? _customSelectedDate;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _visibleCount = 50;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customSelectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'तारीख के बिल देखें (Select Date)',
      confirmText: 'चुनें (Select)',
      cancelText: 'रद्द करें (Cancel)',
    );
    if (picked != null) {
      setState(() {
        _customSelectedDate = picked;
        _dateFilter = 'custom';
      });
    }
  }

  Future<void> _loadSales() async {
    final shop = context.read<ShopProvider>().shop;

    // ⚡ 1. INSTANT LOCAL LOAD: Read local SQLite in <50ms!
    try {
      final localSales = await LocalDbService.instance.getSales(shop.id);
      if (localSales.isNotEmpty && mounted) {
        setState(() {
          _sales = localSales;
          _isLoading = false;
        });
      }
    } catch (_) {}

    if (_sales.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }

    // 🌐 2. BACKGROUND CLOUD SYNC: Silently sync without blocking the UI
    try {
      final cloudSales = await SupabaseService.instance.getSales(shop.id);
      if (mounted) {
        setState(() {
          _sales = cloudSales;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Bills background sync error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Sale> get _filteredSales {
    final seenIds = <String>{};
    final unique = <Sale>[];
    for (final s in _sales) {
      if (!seenIds.contains(s.id)) {
        seenIds.add(s.id);
        unique.add(s);
      }
    }

    // 1. Sort strictly date-wise: newest bills first
    unique.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    List<Sale> list = unique;

    // 2. Filter by payment mode
    if (_filter == 'credit') {
      list = list.where((s) => s.due > 0).toList();
    } else if (_filter == 'online') {
      list = list.where((s) => s.paymentMode == 'online').toList();
    } else if (_filter == 'cash') {
      list = list.where((s) => s.paymentMode == 'cash').toList();
    }

    // 3. Filter by date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    if (_dateFilter == 'today') {
      list = list.where((s) => _isSameDay(s.createdAt.toLocal(), today)).toList();
    } else if (_dateFilter == 'yesterday') {
      list = list.where((s) => _isSameDay(s.createdAt.toLocal(), yesterday)).toList();
    } else if (_dateFilter == 'this_week') {
      list = list.where((s) => s.createdAt.toLocal().isAfter(weekAgo)).toList();
    } else if (_dateFilter == 'custom' && _customSelectedDate != null) {
      list = list.where((s) => _isSameDay(s.createdAt.toLocal(), _customSelectedDate!)).toList();
    }

    // 4. Filter by search query (invoice number, customer name, customer phone)
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((s) {
        final matchBill = '${s.billNo}'.contains(q);
        final matchCust = (s.customerName ?? '').toLowerCase().contains(q);
        final matchPhone = (s.customerPhone ?? '').contains(q);
        return matchBill || matchCust || matchPhone;
      }).toList();
    }

    return list;
  }

  void _showBillDetails(Sale sale) {
    final shop = context.read<ShopProvider>().shop;
    final userEmail = SupabaseService.instance.client?.auth.currentUser?.email;
    final dateFormat = DateFormat('dd-MM-yyyy h:mm a');
    final screenshotController = ScreenshotController();
    Sale currentSale = sale;
    bool isVerifying = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Text(
                                  'Invoice #${currentSale.billNo} • ${currentSale.customerName?.isNotEmpty == true ? currentSale.customerName! : "Walk-in Customer"}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                                if (currentSale.customerPhone != null && currentSale.customerPhone!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.blue.shade300),
                                    ),
                                    child: Text(
                                      '📞 ${currentSale.customerPhone!}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                if (currentSale.isEdited)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.amber.shade600),
                                    ),
                                    child: Text(
                                      currentSale.editedTagText,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              currentSale.isFullyPaidAndVerified
                                  ? 'Status: Paid ✓'
                                  : (currentSale.effectiveUpiPayable > 0.009
                                      ? 'Status: UPI Pending (₹${currentSale.effectiveUpiPayable.toStringAsFixed(0)})'
                                      : 'Status: Due / उधार (₹${currentSale.due.toStringAsFixed(0)})'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: currentSale.isFullyPaidAndVerified ? const Color(0xFF00875A) : Colors.amber.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!context.read<AuthProvider>().isStaffSession) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 24),
                          tooltip: 'Cart में बिल एडिट करें (Edit in Cart)',
                          onPressed: () {
                            Navigator.pop(ctx);
                            _editBillInCart(currentSale);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                          tooltip: 'बिल डिलीट करें (Delete Bill)',
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmDeleteBill(currentSale);
                          },
                        ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                if (currentSale.effectiveUpiPayable > 0.009)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.qr_code_scanner, size: 18, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'UPI बकाया: ₹${currentSale.effectiveUpiPayable.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00875A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          icon: isVerifying
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.verified_outlined, size: 15),
                          label: const Text('Verify Paid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: isVerifying
                              ? null
                              : () async {
                                  setModalState(() => isVerifying = true);
                                  final pendingUpi = currentSale.effectiveUpiPayable;
                                  final newPaid = PaymentQrHelper.round2(
                                    (currentSale.paid + pendingUpi).clamp(0.0, currentSale.total),
                                  );
                                  final newDue = PaymentQrHelper.round2(
                                    (currentSale.total - newPaid) > 0 ? (currentSale.total - newPaid) : 0.0,
                                  );
                                  final verifiedSale = currentSale.copyWith(
                                    paid: newPaid,
                                    due: newDue,
                                    upiPaid: PaymentQrHelper.round2(currentSale.upiPaid + pendingUpi),
                                    upiPayable: 0.0,
                                    onlineVerified: true,
                                    verificationSource: 'cashier_verified',
                                    paymentStatus: newDue <= 0.009 ? 'completed' : 'pending',
                                  );
                                  await SupabaseService.instance.updateSale(verifiedSale);
                                  SoundService.instance.playSuccess();
                                  setModalState(() {
                                    currentSale = verifiedSale;
                                    isVerifying = false;
                                  });
                                  _loadSales();
                                },
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Screenshot(
                      controller: screenshotController,
                      child: BillReceiptCard(
                        shopName: shop.name,
                        shopAddress: shop.address,
                        shopPhone: shop.phone,
                        shopEmail: (userEmail != null && userEmail.isNotEmpty) ? userEmail : null,
                        gstin: shop.gstin,
                        billNo: '${currentSale.billNo}',
                        dateString: dateFormat.format(currentSale.createdAt.toLocal()),
                        customerName: currentSale.customerName,
                        customerPhone: currentSale.customerPhone,
                        items: currentSale.items,
                        subtotal: currentSale.subtotal,
                        discount: currentSale.discount,
                        total: currentSale.total,
                        paid: currentSale.paid,
                        due: currentSale.due,
                        paymentMode: currentSale.paymentMode,
                        paymentStatus: currentSale.paymentStatus,
                        upiPayableAmount: currentSale.effectiveUpiPayable,
                        onlineVerified: currentSale.onlineVerified,
                        cashPaid: currentSale.cashPaid,
                        upiPaid: currentSale.upiPaid,
                        creditAmount: currentSale.creditAmount,
                        footerMessage: shop.receiptFooter,
                        quoteLine1: AiQuoteService.getQuoteForBillNo(currentSale.billNo).line1,
                        quoteLine2: AiQuoteService.getQuoteForBillNo(currentSale.billNo).line2,
                        upiId: shop.upiId,
                        upiPayeeName: shop.upiPayeeName,
                        googleReviewUrl: shop.googleReviewUrl,
                        editCount: currentSale.editCount,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  color: Colors.grey.shade50,
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.pop(ctx),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.reply, color: Color(0xFF2563EB), size: 22),
                                SizedBox(height: 3),
                                Text('Back', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            try {
                              final imageBytes = await screenshotController.capture(pixelRatio: 2.0);
                              if (ctx.mounted) {
                                await ReceiptPrintService.showWhatsAppShareDialog(
                                  ctx,
                                  sale: currentSale,
                                  shop: shop,
                                  imageBytes: imageBytes,
                                  shopEmail: (userEmail != null && userEmail.isNotEmpty) ? userEmail : null,
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('शेयर एरर: $e')));
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.share, color: Color(0xFF16A34A), size: 22),
                                SizedBox(height: 3),
                                Text('Share Bill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            try {
                              final file = await ReceiptPrintService.downloadReceiptPdf(
                                sale: currentSale,
                                shop: shop,
                                shopEmail: (userEmail != null && userEmail.isNotEmpty) ? userEmail : null,
                              );
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF00875A),
                                    content: Text('PDF सेव: ${file.uri.pathSegments.last}'),
                                    action: SnackBarAction(
                                      label: 'Save / Open',
                                      textColor: Colors.white,
                                      onPressed: () {
                                        ReceiptPrintService.exportReceiptPdf(
                                          sale: currentSale,
                                          shop: shop,
                                          shopEmail: (userEmail != null && userEmail.isNotEmpty) ? userEmail : null,
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(backgroundColor: AppColors.error, content: Text('डाउनलोड एरर: $e')));
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.download_rounded, color: Color(0xFF0284C7), size: 22),
                                SizedBox(height: 3),
                                Text('Download', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            try {
                              final imageBytes = await screenshotController.capture(pixelRatio: 2.0);
                              await ReceiptPrintService.printReceipt(sale: currentSale, shop: shop, imageBytes: imageBytes);
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(backgroundColor: AppColors.error, content: Text('प्रिंट एरर: $e')));
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.print, color: Color(0xFF2563EB), size: 22),
                                SizedBox(height: 3),
                                Text('Print Bill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editBillInCart(Sale sale) async {
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('सुरक्षा नियम: केवल दुकान मालिक बिल एडिट कर सकते हैं।'),
        ),
      );
      return;
    }

    final cart = context.read<CartProvider>();
    final customerProv = context.read<CustomerProvider>();

    // Protect any active new cart items before replacing them with the bill
    if (cart.lines.isNotEmpty && cart.editingSale?.id != sale.id) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (confirmCtx) => AlertDialog(
          title: Text('Bill #${sale.billNo} Cart में लोड करें?'),
          content: const Text(
            'आपके Cart में अभी कुछ आइटम हैं। क्या उन्हें हटाकर इस पुराने बिल को एडिट करने के लिए लोड करें?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(confirmCtx, false),
              child: const Text('रद्द करें'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(confirmCtx, true),
              child: const Text('हाँ, लोड करें'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }

    final matchedCustomer = sale.customerId == null
        ? null
        : customerProv.customers
            .where((c) => c.id == sale.customerId)
            .firstOrNull;

    cart.startEditingSale(sale, resolvedCustomer: matchedCustomer);
    SoundService.instance.playButtonClick();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.amber.shade800,
        duration: const Duration(seconds: 3),
        content: Text(
          'बिल #${sale.billNo} Cart में खुल गया है — बदलाव करके Checkout से सेव करें।',
        ),
      ),
    );
    widget.onSwitchToBilling?.call();
  }

  void _confirmDeleteBill(Sale sale) {
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('सुरक्षा नियम: केवल दुकान मालिक बिल डिलीट कर सकते हैं।'),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (delCtx) => AlertDialog(
        title: const Text('बिल डिलीट करें?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('क्या आप वाकई बिल #${sale.billNo} (${CurrencyFormatter.format(sale.total)}) को डिलीट/रद्द करना चाहते हैं?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(delCtx),
            child: const Text('रद्द करें (Cancel)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              SoundService.instance.playDelete();
              Navigator.pop(delCtx);
              await SupabaseService.instance.deleteSale(sale.id);
              _loadSales();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: AppColors.error, content: Text('बिल डिलीट कर दिया गया।')),
                );
              }
            },
            child: const Text('हाँ, डिलीट करें'),
          ),
        ],
      ),
    );
  }

  void _settleBill(Sale sale) {
    SoundService.instance.playButtonClick();
    final TextEditingController amountCtrl = TextEditingController(text: sale.due.toStringAsFixed(2));
    String paymentMethod = 'cash'; // 'cash' or 'upi'

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payments_rounded, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Settle Bill #${sale.billNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      sale.customerName?.isNotEmpty == true ? sale.customerName! : 'Walk-in Customer',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Due / बाकी उधार:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(
                      CurrencyFormatter.format(sale.due),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('भुगतान राशि (Payment Amount):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              const Text('भुगतान का तरीका (Payment Mode):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('नकद (Cash)')),
                      selected: paymentMethod == 'cash',
                      selectedColor: AppColors.primarySurface,
                      onSelected: (v) => setDialogState(() => paymentMethod = 'cash'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('UPI Online')),
                      selected: paymentMethod == 'upi',
                      selectedColor: AppColors.primarySurface,
                      onSelected: (v) => setDialogState(() => paymentMethod = 'upi'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('रद्द करें (Cancel)'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final enterAmt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (enterAmt <= 0) return;
                Navigator.pop(ctx);

                final payAmt = enterAmt > sale.due ? sale.due : enterAmt;
                final newDue = PaymentQrHelper.round2((sale.due - payAmt).clamp(0.0, sale.total));
                final newPaid = PaymentQrHelper.round2(sale.paid + payAmt);
                final updatedSale = sale.copyWith(
                  paid: newPaid,
                  due: newDue,
                  cashPaid: paymentMethod == 'cash' ? PaymentQrHelper.round2(sale.cashPaid + payAmt) : sale.cashPaid,
                  upiPaid: paymentMethod == 'upi' ? PaymentQrHelper.round2(sale.upiPaid + payAmt) : sale.upiPaid,
                  creditAmount: newDue,
                  paymentStatus: newDue <= 0.009 ? 'completed' : 'pending',
                );

                await SupabaseService.instance.updateSale(updatedSale);
                if (sale.customerId != null && sale.customerId!.isNotEmpty) {
                  try {
                    await context.read<CustomerProvider>().recordPayment(
                      sale.customerId!,
                      payAmt,
                      mode: paymentMethod,
                      note: 'Bill #${sale.billNo} Settlement',
                    );
                  } catch (_) {}
                }
                SoundService.instance.playSuccess();
                _loadSales();
              },
              child: const Text('जमा करें (Settle)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildFilterPopupItem(String key, String title, IconData icon, bool isDark) {
    final isSelected = _filter == key;
    return PopupMenuItem<String>(
      value: key,
      height: 42,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isSelected ? AppColors.primary : Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_rounded, color: AppColors.primary, size: 18),
        ],
      ),
    );
  }

  void _exportReport() {
    SoundService.instance.playButtonClick();
    final filtered = _filteredSales;
    final total = filtered.fold<double>(0.0, (sum, s) => sum + s.total);
    final count = filtered.length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        content: Text('$count Bills · Total: ${CurrencyFormatter.format(total)}'),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildDateHeader(DateTime date, int count, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFEDE6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFFFDCD0),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_rounded, size: 15, color: Color(0xFFFF5722)),
          const SizedBox(width: 8),
          Text(
            '${DateFormat('dd MMM, yyyy').format(date)} – $count Bills',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(Sale sale, DateFormat timeFormat, bool isDark) {
    final bool isUnsettled = sale.due > 0.009;
    final staffOrAdmin = context.read<AuthProvider>().isStaffSession ? 'Staff' : 'Admin';
    final customerDisplay = (sale.customerName != null && sale.customerName!.trim().isNotEmpty)
        ? sale.customerName!.trim()
        : 'Walk-in Customer';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left orange banner if Unsettled matching Image 3
            if (isUnsettled)
              Container(
                width: 26,
                color: const Color(0xFFFF6D00),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: const RotatedBox(
                  quarterTurns: 3,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_outlined, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Unsettled',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Main Content Area
            Expanded(
              child: InkWell(
                onTap: () => _showBillDetails(sale),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Invoice, Time, Customer, Created by
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Invoice : ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  '${sale.billNo}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFFF5722),
                                  ),
                                ),
                                if (sale.isEdited) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'EDITED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  'Time : ${timeFormat.format(sale.createdAt.toLocal())}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  'Customer : ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    customerDisplay,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  'Created by : $staffOrAdmin',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Right Column: Items, Total, Button
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Items : ',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                '${sale.items.length}',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Total : ',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                '₹${sale.total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (isUnsettled)
                            Material(
                              color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFFEDE6),
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _settleBill(sale),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.payments_rounded, size: 14, color: Color(0xFFEA580C)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Settle bill',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFEA580C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            Material(
                              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _showBillDetails(sale),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.receipt_rounded, size: 14, color: Color(0xFF2563EB)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Receipt',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('dd MMM yyyy h:mm a');
    final filtered = _filteredSales;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFF5722),
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () {
                  SoundService.instance.playButtonClick();
                  Navigator.pop(context);
                },
              )
            : IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                tooltip: 'मेन्यू',
                onPressed: () {
                  SoundService.instance.playButtonClick();
                  MainShell.openDrawer(context);
                },
              ),
        title: const Text(
          'Bill History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white, letterSpacing: 0.3),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'रिफ्रेश करें',
            onPressed: () {
              SoundService.instance.playButtonClick();
              _loadSales();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 850;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 850 : double.infinity),
              child: Column(
                children: [
          // Top Controls Bar (Date Dropdown + Search + Filter + Export)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Date filter dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _dateFilter,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(
                            'All Time',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'today',
                          child: Text(
                            'Today',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'yesterday',
                          child: Text(
                            'Yesterday',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'this_week',
                          child: Text(
                            'This Week',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text(
                            _customSelectedDate != null
                                ? DateFormat('dd MMM yyyy').format(_customSelectedDate!)
                                : 'Pick Date...',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == 'custom') {
                          _pickCustomDate();
                        } else if (val != null) {
                          setState(() {
                            _dateFilter = val;
                            _customSelectedDate = null;
                          });
                        }
                      },
                    ),
                  ),
                ),

                // Right: Action Icons (Search, Filter, Export)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.search,
                        color: _showSearch || _searchQuery.isNotEmpty ? AppColors.primary : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                      ),
                      tooltip: 'Search',
                      onPressed: () => setState(() => _showSearch = !_showSearch),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Payment Filter',
                      offset: const Offset(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      elevation: 6,
                      initialValue: _filter,
                      icon: Icon(
                        Icons.tune_rounded,
                        color: _filter != 'all' ? AppColors.primary : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                      ),
                      onSelected: (key) {
                        SoundService.instance.playButtonClick();
                        setState(() => _filter = key);
                      },
                      itemBuilder: (ctx) => [
                        _buildFilterPopupItem('all', 'All Bills (सभी बिल)', Icons.receipt_long, isDark),
                        const PopupMenuDivider(height: 1),
                        _buildFilterPopupItem('cash', 'Cash (नकद बिल)', Icons.payments_outlined, isDark),
                        const PopupMenuDivider(height: 1),
                        _buildFilterPopupItem('online', 'UPI Online (ऑनलाइन बिल)', Icons.qr_code_2, isDark),
                        const PopupMenuDivider(height: 1),
                        _buildFilterPopupItem('credit', 'Unsettled / Credit (उधार बाकी)', Icons.book_outlined, isDark),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.file_download_outlined, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                      tooltip: 'Export',
                      onPressed: _exportReport,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Bar (if opened)
          if (_showSearch || _searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: TextField(
                controller: _searchCtrl,
                autofocus: _showSearch && _searchQuery.isEmpty,
                decoration: InputDecoration(
                  hintText: 'Search by bill # or customer name...',
                  hintStyle: const TextStyle(fontSize: 12.5),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),

          // Active filter indicator chip
          if (_filter != 'all')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Filter: ${_filter.toUpperCase()}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => setState(() => _filter = 'all'),
                          child: const Icon(Icons.close, size: 14, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Sales List with Date Section Headers
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadSales,
                    child: filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.lightTextSecondary),
                                    SizedBox(height: 8),
                                    Text('No bills found', style: TextStyle(color: AppColors.lightTextSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Builder(
                            builder: (context) {
                              final totalCount = filtered.length;
                              final displayedCount = math.min(_visibleCount, totalCount);
                              final hasMore = totalCount > displayedCount;
                              final itemCount = hasMore ? displayedCount + 1 : displayedCount;

                              return ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 20),
                                itemCount: itemCount,
                                itemBuilder: (context, i) {
                                  if (i == displayedCount) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.expand_more, size: 18),
                                            label: const Text('Load More (+50)'),
                                            onPressed: () {
                                              setState(() {
                                                _visibleCount += 50;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  final sale = filtered[i];
                                  final isFirstItem = i == 0;
                                  final isNewDay = isFirstItem ||
                                      !_isSameDay(
                                        filtered[i - 1].createdAt.toLocal(),
                                        sale.createdAt.toLocal(),
                                      );

                                  Widget? dateHeaderWidget;
                                  if (isNewDay) {
                                    final dayDate = sale.createdAt.toLocal();
                                    final daySales = filtered
                                        .where((s) => _isSameDay(s.createdAt.toLocal(), dayDate))
                                        .toList();
                                    dateHeaderWidget = _buildDateHeader(dayDate, daySales.length, isDark);
                                  }

                                  final billCard = _buildBillCard(sale, timeFormat, isDark);

                                  if (dateHeaderWidget != null) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        dateHeaderWidget,
                                        billCard,
                                      ],
                                    );
                                  }
                                  return billCard;
                                },
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
            ),
          );
        },
      ),
    );
  }
}
