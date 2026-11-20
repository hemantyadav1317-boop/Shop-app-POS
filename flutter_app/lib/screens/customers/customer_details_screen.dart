import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/sound_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/customer.dart';
import '../../data/models/customer_payment.dart';
import '../../data/models/sale.dart';
import '../../data/services/local_db_service.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/shop_provider.dart';
import '../pos/widgets/bill_receipt_card.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailsScreen({super.key, required this.customer});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CreditTransactionItem {
  final String id;
  final DateTime date;
  final String title;
  final String subtitle;
  final double amount;
  final bool isDebit; // true: Debit (+), false: Credit (-)
  final String mode; // 'credit', 'cash', 'upi'
  final Sale? saleRef;
  double balanceAfter = 0.0;

  _CreditTransactionItem({
    required this.id,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isDebit,
    required this.mode,
    this.saleRef,
  });
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  late Customer _currentCustomer;
  List<Sale> _customerSales = [];
  List<CustomerPayment> _customerPayments = [];
  bool _isLoading = false; // ⚡ Instant 0ms load - never block user with full spinner
  String? _expandedSection; // 'bills', 'credit', 'ledger' or null

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
    _initLocalData();
    _loadData();
  }

  void _initLocalData() {
    // 1. Immediately read RAM cached sales for 0ms instant screen display
    final cachedSales = SupabaseService.instance.currentLocalSales;
    if (cachedSales.isNotEmpty) {
      final filteredSales = cachedSales.where((s) {
        if (s.customerId != null && s.customerId == _currentCustomer.id) return true;
        if (_currentCustomer.phone != null &&
            _currentCustomer.phone!.isNotEmpty &&
            s.customerPhone == _currentCustomer.phone) {
          return true;
        }
        return false;
      }).toList();
      filteredSales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _customerSales = filteredSales;
    }
  }

  Future<void> _loadData() async {
    final shop = context.read<ShopProvider>().shop;

    try {
      // 1. If RAM cache was empty, check local SQLite database (offline-first, zero internet delay)
      if (_customerSales.isEmpty) {
        final dbSales = await LocalDbService.instance.getSales(shop.id);
        if (dbSales.isNotEmpty && mounted) {
          final filteredSales = dbSales.where((s) {
            if (s.customerId != null && s.customerId == _currentCustomer.id) return true;
            if (_currentCustomer.phone != null &&
                _currentCustomer.phone!.isNotEmpty &&
                s.customerPhone == _currentCustomer.phone) {
              return true;
            }
            return false;
          }).toList();
          filteredSales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (mounted && filteredSales.isNotEmpty) {
            setState(() {
              _customerSales = filteredSales;
            });
          }
        }
      }

      // 2. Fetch payments for this specific customer
      final payments = await SupabaseService.instance.getCustomerPayments(_currentCustomer.id);

      if (mounted) {
        setState(() {
          _customerPayments = payments;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalSaleAmount =>
      _customerSales.fold(0.0, (sum, s) => sum + s.total);

  List<_CreditTransactionItem> get _ledgerEntries {
    final List<_CreditTransactionItem> items = [];

    // 1. Credit Sales
    for (final s in _customerSales) {
      if (s.paymentMode == 'credit' || s.due > 0) {
        final amt = s.due > 0 ? s.due : s.total;
        items.add(_CreditTransactionItem(
          id: s.id,
          date: s.createdAt,
          title: 'Invoice #${s.billNo > 0 ? s.billNo : s.id.substring(0, 6)} (Credit Sale)',
          subtitle: '${s.items.length} items • Bill: ${CurrencyFormatter.format(s.total)}',
          amount: amt,
          isDebit: true,
          mode: 'credit',
          saleRef: s,
        ));
      }
    }

    // 2. Customer Payments Received
    for (final p in _customerPayments) {
      items.add(_CreditTransactionItem(
        id: p.id,
        date: p.createdAt,
        title: 'Payment Received (${p.mode.toUpperCase()})',
        subtitle: p.note != null && p.note!.isNotEmpty
            ? p.note!
            : 'Payment received against balance',
        amount: p.amount,
        isDebit: false,
        mode: p.mode,
      ));
    }

    // Sort Chronological
    items.sort((a, b) => a.date.compareTo(b.date));
    double running = 0.0;
    for (final it in items) {
      if (it.isDebit) {
        running += it.amount;
      } else {
        running = (running - it.amount) > 0 ? (running - it.amount) : 0.0;
      }
      it.balanceAfter = running;
    }

    // Reverse for display
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  Future<void> _makeCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, {String? customText}) async {
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length == 10) clean = '91$clean';

    final shop = context.read<ShopProvider>().shop;
    final dueAmt = _currentCustomer.balance.toStringAsFixed(2);
    final shopName = shop.name;
    final upiId = (shop.upiId != null && shop.upiId!.trim().isNotEmpty) ? shop.upiId!.trim() : null;
    final upiPayee = (shop.upiPayeeName != null && shop.upiPayeeName!.trim().isNotEmpty)
        ? shop.upiPayeeName!.trim()
        : shopName;

    String upiPaymentBlock = '';
    if (upiId != null) {
      final upiUri = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(upiPayee)}&am=$dueAmt&cu=INR&tn=${Uri.encodeComponent("Khata Payment $shopName")}';
      final qrLink = 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(upiUri)}';
      upiPaymentBlock = '\n\n💳 Pay via UPI ID:\n👉 $upiId\n\n⚡ Tap to pay via GPay/PhonePe:\n👉 $upiUri\n\n📷 UPI QR Code:\n👉 $qrLink';
    }

    final msg = customText ??
        '🏪 *$shopName*\n${shop.phone != null && shop.phone!.isNotEmpty ? "📞 " + shop.phone! + "\n" : ""}${shop.address != null && shop.address!.isNotEmpty ? "📍 " + shop.address! + "\n" : ""}----------------------------------\nHello *${_currentCustomer.name}*,\nAccount statement:\n💰 *Total Due Balance: ₹$dueAmt*$upiPaymentBlock\n\nThank you! 🙏';

    final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openBillReceipt(Sale sale) {
    SoundService.instance.playButtonClick();
    final shop = context.read<ShopProvider>().shop;
    final dateFormat = DateFormat('dd/MM/yyyy, hh:mm a');
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: BillReceiptCard(
              shopName: shop.name,
              shopAddress: shop.address,
              shopPhone: shop.phone,
              gstin: shop.gstin,
              billNo: '${sale.billNo}',
              dateString: dateFormat.format(sale.createdAt.toLocal()),
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
              upiId: shop.upiId,
            ),
          ),
        ),
      ),
    );
  }

  void _showAddCreditDialog() {
    SoundService.instance.playButtonClick();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (bottomSheetCtx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

          void addChipAmount(double val) {
            final curr = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
            final updated = curr + val;
            amountCtrl.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toStringAsFixed(2);
            setSheetState(() {});
          }

          return Container(
            padding: EdgeInsets.only(bottom: bottomInset + 16, left: 20, right: 20, top: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pull Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header with Billiez Blue Theme
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A4B8E).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.credit_card_rounded, color: Color(0xFF1A4B8E), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add Credit (उधार जोड़ें)',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A4B8E),
                              ),
                            ),
                            Text(
                              'ग्राहक: ${_currentCustomer.name}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Current Balance Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'वर्तमान बकाया (Current Due):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                        ),
                        Text(
                          '₹${_currentCustomer.balance.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount Input Field
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'उधार राशि (Credit Amount) *',
                      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF1A4B8E), fontWeight: FontWeight.w600),
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A4B8E)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1A4B8E), width: 2)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 10),

                  // Quick Suggestion Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [100.0, 200.0, 500.0, 1000.0, 2000.0].map((amt) {
                      return InkWell(
                        onTap: () => addChipAmount(amt),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A4B8E).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF1A4B8E).withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            '+₹${amt.toInt()}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1A4B8E)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Note Input
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: 'टिप्पणी / विवरण (Note - Optional)',
                      hintText: 'उदा. राशन सामान उधार लिया',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A4B8E), width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text('उधार जोड़ें (Save Credit)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A4B8E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      onPressed: () async {
                        final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        if (amt <= 0) return;

                        await context.read<CustomerProvider>().addCredit(_currentCustomer.id, amt);
                        SoundService.instance.playSuccess();
                        final newBal = _currentCustomer.balance + amt;
                        setState(() {
                          _currentCustomer = _currentCustomer.copyWith(balance: newBal);
                        });
                        await _loadData();
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF1A4B8E),
                              content: Text('✓ ₹$amt उधार जोड़ा गया। नया कुल बकाया: ₹${newBal.toStringAsFixed(2)}'),
                            ),
                          );
                        }
                      },
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

  void _showReceiveCashDialog() {
    SoundService.instance.playButtonClick();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedMode = 'cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (bottomSheetCtx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

          void setFullBalance() {
            amountCtrl.text = _currentCustomer.balance % 1 == 0
                ? _currentCustomer.balance.toInt().toString()
                : _currentCustomer.balance.toStringAsFixed(2);
            setSheetState(() {});
          }

          void addChipAmount(double val) {
            final curr = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
            final updated = curr + val;
            amountCtrl.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toStringAsFixed(2);
            setSheetState(() {});
          }

          return Container(
            padding: EdgeInsets.only(bottom: bottomInset + 16, left: 20, right: 20, top: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pull Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header with Billiez Styling
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.payments_rounded, color: Color(0xFF16A34A), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Receive Payment (भुगतान प्राप्त करें)',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                            Text(
                              'ग्राहक: ${_currentCustomer.name}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Current Balance Banner with Full Balance Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'कुल बकाया राशि (Total Due):',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                            ),
                            Text(
                              '₹${_currentCustomer.balance.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                        if (_currentCustomer.balance > 0)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.flash_on_rounded, size: 14),
                            label: const Text('पूरा बकाया', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: setFullBalance,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount Input
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'प्राप्त राशि (Received Amount) *',
                      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 10),

                  // Quick Suggestion Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [100.0, 200.0, 500.0, 1000.0, 2000.0].map((amt) {
                      return InkWell(
                        onTap: () => addChipAmount(amt),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            '+₹${amt.toInt()}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Payment Mode Selector (Cash vs UPI Online)
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setSheetState(() => selectedMode = 'cash'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedMode == 'cash' ? const Color(0xFF16A34A) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedMode == 'cash' ? const Color(0xFF16A34A) : Colors.grey.shade300,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.money_rounded, size: 18, color: selectedMode == 'cash' ? Colors.white : Colors.grey.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'Cash (नकद)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: selectedMode == 'cash' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setSheetState(() => selectedMode = 'upi'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedMode == 'upi' ? const Color(0xFF1A4B8E) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedMode == 'upi' ? const Color(0xFF1A4B8E) : Colors.grey.shade300,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_rounded, size: 18, color: selectedMode == 'upi' ? Colors.white : Colors.grey.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'UPI Online',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: selectedMode == 'upi' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Note Input
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: 'टिप्पणी / नोट (Note - Optional)',
                      hintText: 'उदा. नकद प्राप्त, PhonePe/GPay',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text('भुगतान दर्ज करें (Record Payment)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      onPressed: () async {
                        final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        if (amt <= 0) return;

                        final shop = context.read<ShopProvider>().shop;
                        await context.read<CustomerProvider>().recordPayment(
                          _currentCustomer.id,
                          amt,
                          shopId: shop.id,
                          mode: selectedMode,
                          note: noteCtrl.text.trim(),
                        );
                        SoundService.instance.playSuccess();
                        final newBal = (_currentCustomer.balance - amt) > 0 ? (_currentCustomer.balance - amt) : 0.0;
                        setState(() {
                          _currentCustomer = _currentCustomer.copyWith(balance: newBal);
                        });
                        await _loadData();
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF16A34A),
                              content: Text('✓ ₹$amt का भुगतान दर्ज किया गया। नया बकाया: ₹${newBal.toStringAsFixed(2)}'),
                            ),
                          );
                        }
                      },
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

  void _showEditCustomerDialog() {
    SoundService.instance.playButtonClick();
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Staff cannot edit customer details.'),
        ),
      );
      return;
    }
    final nameCtrl = TextEditingController(text: _currentCustomer.name);
    final phoneCtrl = TextEditingController(text: _currentCustomer.phone ?? '');
    final addressCtrl = TextEditingController(text: _currentCustomer.address ?? '');
    final emailCtrl = TextEditingController(text: _currentCustomer.email ?? '');
    final gstCtrl = TextEditingController(text: _currentCustomer.gstNo ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Customer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Customer Name *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email id', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: gstCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'GST No', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;

              final updated = _currentCustomer.copyWith(
                name: newName,
                phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                gstNo: gstCtrl.text.trim().isEmpty ? null : gstCtrl.text.trim().toUpperCase(),
                address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
              );

              await context.read<CustomerProvider>().updateCustomer(updated);
              SoundService.instance.playSuccess();
              setState(() => _currentCustomer = updated);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Customer details updated')),
                );
              }
            },
            child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCustomer() {
    SoundService.instance.playButtonClick();
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Staff cannot delete customer records.'),
        ),
      );
      return;
    }
    if (_currentCustomer.balance > 0.009) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text('Cannot Delete Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer "${_currentCustomer.name}" has an outstanding due balance of ₹${_currentCustomer.balance.toStringAsFixed(2)}.',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Rule: You cannot delete a customer with pending credit. Please settle the dues first.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00875A)),
              onPressed: () {
                Navigator.pop(ctx);
                _showReceiveCashDialog();
              },
              child: const Text('Receive Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text('Are you sure you want to permanently delete "${_currentCustomer.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await context.read<CustomerProvider>().deleteCustomer(_currentCustomer.id);
              if (mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${_currentCustomer.name} deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'C';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = _getInitials(_currentCustomer.name);
    final phone = _currentCustomer.phone;
    final hasPhone = phone != null && phone.trim().isNotEmpty;

    final lastPaymentDate = _customerPayments.isNotEmpty
        ? DateFormat('dd MMM yyyy').format(_customerPayments.first.createdAt)
        : '--';
    final lastSaleDate = _customerSales.isNotEmpty
        ? DateFormat('dd MMM yyyy').format(_customerSales.first.createdAt)
        : '--';
    final customerSince = DateFormat('dd MMM yyyy').format(_currentCustomer.createdAt);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Customer Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reload',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              children: [
                // 1. TOP PROFILE CARD matching Billiez Image 4
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Initials Box: [ VV ]
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Name and Edit | Delete buttons
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentCustomer.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: _showEditCustomerDialog,
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                        child: Text(
                                          'Edit',
                                          style: TextStyle(
                                            color: Color(0xFF2563EB),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: Text('|', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                                    ),
                                    InkWell(
                                      onTap: _confirmDeleteCustomer,
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                        child: Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Right Circular Action Buttons [ 📞 ] [ 💬 ]
                          if (hasPhone) ...[
                            InkWell(
                              onTap: () => _makeCall(phone),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFDBEAFE)),
                                ),
                                child: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF2563EB)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _openWhatsApp(phone),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFDCFCE7)),
                                ),
                                child: const Icon(Icons.chat_outlined, size: 18, color: Color(0xFF16A34A)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 10),

                      // Rows of Phone, GST No, Email
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Phone Number', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                const SizedBox(height: 1),
                                Text(
                                  phone ?? '--',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('GST No', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                const SizedBox(height: 1),
                                Text(
                                  _currentCustomer.gstNo ?? '--',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Email', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                const SizedBox(height: 1),
                                Text(
                                  _currentCustomer.email ?? '--',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Address', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                const SizedBox(height: 1),
                                Text(
                                  _currentCustomer.address ?? '--',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 2. TWO KPI CARDS (Pink Total Balance & Blue Total Sale) matching Image 4
                Row(
                  children: [
                    // Pink Card: Total Balance Amount
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: Color(0xFFDC2626)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Balance Amount',
                                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹ ${_currentCustomer.balance.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                  const Text(
                                    'Credit Amount',
                                    style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Blue Card: Total Sale Amount
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.trending_up_rounded, size: 20, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Sale Amount',
                                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹ ${_totalSaleAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                  const Text(
                                    '(Total Sale till now)',
                                    style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3. TWO ACTION CARDS [ Add Credit ] & [ Recieve Cash ] matching Image 4
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _showAddCreditDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.credit_card_rounded, size: 28, color: Color(0xFF2563EB)),
                              SizedBox(height: 6),
                              Text(
                                'Add Credit',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: _showReceiveCashDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.payments_rounded, size: 28, color: Color(0xFF16A34A)),
                              SizedBox(height: 6),
                              Text(
                                'Recieve Cash',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 4. NAVIGABLE MENU SECTIONS matching Image 4
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Item 1: Bill History
                      ListTile(
                        leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFF1E3A8A)),
                        title: const Text('Bill History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                        subtitle: Text('Customer\'s previous bills (${_customerSales.length})', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        trailing: Icon(
                          _expandedSection == 'bills' ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_right,
                          color: const Color(0xFF94A3B8),
                        ),
                        onTap: () {
                          SoundService.instance.playButtonClick();
                          setState(() {
                            _expandedSection = _expandedSection == 'bills' ? null : 'bills';
                          });
                        },
                      ),
                      if (_expandedSection == 'bills') _buildBillsExpandedView(isDark),
                      const Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: Color(0xFFF1F5F9)),

                      // Item 2: Credit Transactions
                      ListTile(
                        leading: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF0284C7)),
                        title: const Text('Credit Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                        subtitle: Text('Customer credit activities (${_ledgerEntries.where((e) => e.isDebit).length})', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        trailing: Icon(
                          _expandedSection == 'credit' ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_right,
                          color: const Color(0xFF94A3B8),
                        ),
                        onTap: () {
                          SoundService.instance.playButtonClick();
                          setState(() {
                            _expandedSection = _expandedSection == 'credit' ? null : 'credit';
                          });
                        },
                      ),
                      if (_expandedSection == 'credit') _buildCreditExpandedView(isDark),
                      const Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: Color(0xFFF1F5F9)),

                      // Item 3: Ledger
                      ListTile(
                        leading: const Icon(Icons.menu_book_rounded, color: Color(0xFF0F766E)),
                        title: const Text('Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                        subtitle: const Text('Customer account statement', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        trailing: Icon(
                          _expandedSection == 'ledger' ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_right,
                          color: const Color(0xFF94A3B8),
                        ),
                        onTap: () {
                          SoundService.instance.playButtonClick();
                          setState(() {
                            _expandedSection = _expandedSection == 'ledger' ? null : 'ledger';
                          });
                        },
                      ),
                      if (_expandedSection == 'ledger') _buildLedgerExpandedView(isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 5. 2x2 QUICK INFO GRID matching Image 4
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              icon: Icons.calendar_month_outlined,
                              label: 'Last Payment Date',
                              value: lastPaymentDate,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoItem(
                              icon: Icons.calendar_today_outlined,
                              label: 'Last Sale Date',
                              value: lastSaleDate,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              icon: Icons.event_note_outlined,
                              label: 'Customer Since',
                              value: customerSince,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoItem(
                              icon: Icons.wallet_outlined,
                              label: 'Payment Preference',
                              value: 'All Mode',
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Inline Expanded Sections ---

  Widget _buildBillsExpandedView(bool isDark) {
    if (_customerSales.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text('No bills found for this customer', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
      );
    }

    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        children: _customerSales.map((sale) {
          final isCredit = sale.paymentMode == 'credit' || sale.due > 0;
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invoice #${sale.billNo > 0 ? sale.billNo : sale.id.substring(0, 6)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(sale.createdAt),
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${sale.items.length} items • ${sale.paymentMode.toUpperCase()}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(sale.total),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isCredit ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _openBillReceipt(sale),
                      child: const Text('Receipt', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB))),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCreditExpandedView(bool isDark) {
    final creditEntries = _ledgerEntries.where((e) => e.isDebit).toList();
    if (creditEntries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text('No credit transactions found', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
      );
    }

    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        children: creditEntries.map((item) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(item.date),
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(item.subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                Text(
                  '+ ₹${item.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLedgerExpandedView(bool isDark) {
    final entries = _ledgerEntries;
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text('No ledger entries recorded yet', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
      );
    }

    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        children: entries.map((item) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: item.isDebit ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.isDebit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 16,
                    color: item.isDebit ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(item.date),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Balance after: ₹${item.balanceAfter.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${item.isDebit ? "+" : "-"} ₹${item.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: item.isDebit ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
