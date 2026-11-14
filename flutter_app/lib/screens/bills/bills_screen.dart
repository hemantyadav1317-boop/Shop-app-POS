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
import '../../data/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../core/services/sound_service.dart';
import '../pos/widgets/bill_receipt_card.dart';
import '../../core/services/ai_quote_service.dart';

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

  String _getDateHeaderTitle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) {
      return '📅 आज (Today) · ${DateFormat('dd MMM yyyy').format(date)}';
    } else if (d == yesterday) {
      return '📅 कल (Yesterday) · ${DateFormat('dd MMM yyyy').format(date)}';
    } else {
      return '📅 ${DateFormat('dd MMM yyyy (EEEE)').format(date)}';
    }
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
    setState(() => _isLoading = true);
    final shop = context.read<ShopProvider>().shop;
    final list = await SupabaseService.instance.getSales(shop.id);
    setState(() {
      _sales = list;
      _isLoading = false;
    });
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
                                  'Invoice #${currentSale.billNo}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
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
                              await ReceiptPrintService.shareReceipt(sale: currentSale, shop: shop, imageBytes: imageBytes);
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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, hh:mm a');
    final filtered = _filteredSales;

    return Scaffold(
      appBar: AppBar(
        title: const Text('बिल हिस्ट्री / Bills History', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'रिफ्रेश करें',
            onPressed: _loadSales,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar (Search by Bill #, Customer Name, Customer Phone)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'बिल नंबर या ग्राहक का नाम / फोन खोजें...',
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
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),

          // 2. Date Quick Filters Row (All, Today, Yesterday, This Week, Pick Date)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Row(
              children: [
                _buildDateChip('all', 'सभी दिन (All)'),
                const SizedBox(width: 6),
                _buildDateChip('today', 'आज (Today)'),
                const SizedBox(width: 6),
                _buildDateChip('yesterday', 'कल (Yesterday)'),
                const SizedBox(width: 6),
                _buildDateChip('this_week', 'इस हफ्ते (This Week)'),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: Icon(
                    Icons.calendar_month_rounded,
                    size: 15,
                    color: _dateFilter == 'custom' ? Colors.white : AppColors.primary,
                  ),
                  label: Text(
                    _dateFilter == 'custom' && _customSelectedDate != null
                        ? DateFormat('dd MMM yyyy').format(_customSelectedDate!)
                        : '📅 तारीख चुनें',
                  ),
                  backgroundColor: _dateFilter == 'custom' ? AppColors.primary : Colors.grey.shade100,
                  labelStyle: TextStyle(
                    color: _dateFilter == 'custom' ? Colors.white : AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                  onPressed: _pickCustomDate,
                ),
                if (_dateFilter == 'custom') ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    tooltip: 'तारीख फिल्टर हटाएं',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () {
                      setState(() {
                        _dateFilter = 'all';
                        _customSelectedDate = null;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),

          // 3. Payment Mode Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Row(
              children: [
                _buildFilterChip('all', 'All Bills (${filtered.length})'),
                const SizedBox(width: 6),
                _buildFilterChip('cash', 'Cash'),
                const SizedBox(width: 6),
                _buildFilterChip('online', 'UPI Online'),
                const SizedBox(width: 6),
                _buildFilterChip('credit', 'उधार (Credit)'),
              ],
            ),
          ),

          // 4. Sales List with Date Section Headers
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
                                    Text('कोई बिल नहीं मिला (No bills found)', style: TextStyle(color: AppColors.lightTextSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
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
                                final dayTotal = daySales.fold<double>(0.0, (sum, s) => sum + s.total);
                                dateHeaderWidget = _buildDateHeader(dayDate, daySales.length, dayTotal);
                              }

                              final billCard = Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: sale.due > 0 ? AppColors.error.withValues(alpha: 0.15) : AppColors.primarySurface,
                                    child: Icon(
                                      sale.due > 0 ? Icons.book : Icons.receipt,
                                      color: sale.due > 0 ? AppColors.error : AppColors.primary,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Text('#${sale.billNo}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      if (sale.isEdited) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.amber.shade600, width: 0.8),
                                          ),
                                          child: Text(
                                            sale.editedTagText,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          sale.customerName ?? 'Walk-in Customer',
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${sale.items.length} items · ${dateFormat.format(sale.createdAt.toLocal())} · ${sale.paymentMode.toUpperCase()}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            CurrencyFormatter.format(sale.total),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          if (sale.effectiveUpiPayable > 0.009)
                                            Text(
                                              'UPI Pending: ${CurrencyFormatter.format(sale.effectiveUpiPayable)}',
                                              style: TextStyle(color: Colors.amber.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                                            )
                                          else if (sale.due > 0)
                                            Text(
                                              'Due: ${CurrencyFormatter.format(sale.due)}',
                                              style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                        ],
                                      ),
                                      if (!context.read<AuthProvider>().isStaffSession) ...[
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
                                          tooltip: 'Cart में एडिट करें',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          onPressed: () => _editBillInCart(sale),
                                        ),
                                      ],
                                    ],
                                  ),
                                  onTap: () => _showBillDetails(sale),
                                ),
                              );

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
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date, int count, double total) {
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 10, 2, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                _getDateHeaderTitle(date),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          Text(
            '$count बिल  •  ${CurrencyFormatter.format(total)}',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String key, String label) {
    final isSelected = _dateFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primarySurface,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.lightTextSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11.5,
      ),
      onSelected: (_) {
        setState(() {
          _dateFilter = key;
          if (key != 'custom') _customSelectedDate = null;
        });
      },
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primarySurface,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.lightTextSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11.5,
      ),
      onSelected: (_) {
        setState(() => _filter = key);
      },
    );
  }
}
