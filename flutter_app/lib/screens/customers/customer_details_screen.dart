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
import '../../data/services/supabase_service.dart';
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
  final bool isDebit; // true: उधार दिया (+), false: जमा लिया (-)
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

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Customer _currentCustomer;
  List<Sale> _customerSales = [];
  List<CustomerPayment> _customerPayments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final shop = context.read<ShopProvider>().shop;

    // Load both sales and payments from database
    final allSales = await SupabaseService.instance.getSales(shop.id);
    final payments = await SupabaseService.instance.getCustomerPayments(_currentCustomer.id);

    final filteredSales = allSales.where((s) {
      if (s.customerId != null && s.customerId == _currentCustomer.id) return true;
      if (_currentCustomer.phone != null &&
          _currentCustomer.phone!.isNotEmpty &&
          s.customerPhone == _currentCustomer.phone) {
        return true;
      }
      return false;
    }).toList();

    filteredSales.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (mounted) {
      setState(() {
        _customerSales = filteredSales;
        _customerPayments = payments;
        _isLoading = false;
      });
    }
  }

  double get _totalSaleAmount =>
      _customerSales.fold(0.0, (sum, s) => sum + s.total);

  double get _avgPurchase =>
      _customerSales.isEmpty ? 0.0 : (_totalSaleAmount / _customerSales.length);

  double get _last30DaysSale {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return _customerSales
        .where((s) => s.createdAt.isAfter(thirtyDaysAgo))
        .fold(0.0, (sum, s) => sum + s.total);
  }

  List<_CreditTransactionItem> get _ledgerEntries {
    final List<_CreditTransactionItem> items = [];

    // 1. Credit Sales (उधार दिया)
    for (final s in _customerSales) {
      if (s.paymentMode == 'credit' || s.due > 0) {
        final amt = s.due > 0 ? s.due : s.total;
        items.add(_CreditTransactionItem(
          id: s.id,
          date: s.createdAt,
          title: 'बिल #${s.billNo > 0 ? s.billNo : s.id.substring(0, 6)} (उधार सामान)',
          subtitle: '${s.items.length} सामान • कुल बिल: ${CurrencyFormatter.format(s.total)}',
          amount: amt,
          isDebit: true,
          mode: 'credit',
          saleRef: s,
        ));
      }
    }

    // 2. Customer Payments Received (जमा प्राप्त)
    for (final p in _customerPayments) {
      items.add(_CreditTransactionItem(
        id: p.id,
        date: p.createdAt,
        title: 'खाता जमा प्राप्त (${p.mode.toUpperCase()})',
        subtitle: p.note != null && p.note!.isNotEmpty
            ? p.note!
            : 'बकाया राशि चुकता दर्ज की गई',
        amount: p.amount,
        isDebit: false,
        mode: p.mode,
      ));
    }

    // Calculate Running Balance in Chronological Order (Oldest -> Newest)
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

    // Reverse to Newest First for Display
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
    final msg = customText ??
        'नमस्ते ${_currentCustomer.name} जी, आपकी दुकान का खाता विवरण: कुल बकाया राशि ₹${_currentCustomer.balance.toStringAsFixed(2)} है। धन्यवाद!';
    final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // 🎯 Open Full Bill Receipt
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

  // 🛡️ Set or Update Customer Credit Limit
  void _showSetCreditLimitDialog() {
    final limitCtrl = TextEditingController(
      text: _currentCustomer.creditLimit > 0 ? _currentCustomer.creditLimit.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.speed_rounded, color: Color(0xFF2563EB), size: 24),
            SizedBox(width: 8),
            Text('क्रेडिट लिमिट (उधार सीमा)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ग्राहक: ${_currentCustomer.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'वर्तमान बकाया: ₹${_currentCustomer.balance.toStringAsFixed(2)}',
              style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: limitCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'अधिकतम उधार सीमा (Credit Limit) *',
                hintText: 'उदा. 1000, 2000 या 0 (हटाने के लिए)',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '💡 इस लिमिट से ज्यादा उधार होने पर बिलिंग पर ऑटो अलर्ट मिलेगा ताकि बिना मंजूरी उधारी न बढ़े।',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () async {
              final newLimit = double.tryParse(limitCtrl.text.trim()) ?? 0.0;
              await context.read<CustomerProvider>().setCreditLimit(_currentCustomer.id, newLimit);
              SoundService.instance.playSuccess();
              setState(() {
                _currentCustomer = _currentCustomer.copyWith(creditLimit: newLimit);
              });
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF2563EB),
                    behavior: SnackBarBehavior.floating,
                    content: Text(
                      newLimit > 0
                          ? 'क्रेडिट लिमिट ₹${newLimit.toStringAsFixed(0)} सेट कर दी गई'
                          : 'क्रेडिट लिमिट हटा दी गई (Unlimited)',
                    ),
                  ),
                );
              }
            },
            child: const Text('Save Limit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 💰 Record Payment / Collect Due
  void _showReceiveCashDialog() {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedMode = 'cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.payments_rounded, color: Color(0xFF00875A), size: 24),
                SizedBox(width: 8),
                Text('जमा लें / Receive Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ग्राहक: ${_currentCustomer.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'वर्तमान बकाया: ₹${_currentCustomer.balance.toStringAsFixed(2)}',
                    style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'प्राप्त राशि (Received Amount) *',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.money_rounded, size: 14),
                              SizedBox(width: 4),
                              Text('नकद (Cash)'),
                            ],
                          ),
                          selected: selectedMode == 'cash',
                          onSelected: (val) {
                            if (val) setDialogState(() => selectedMode = 'cash');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_rounded, size: 14),
                              SizedBox(width: 4),
                              Text('ऑनलाइन (UPI)'),
                            ],
                          ),
                          selected: selectedMode == 'upi',
                          onSelected: (val) {
                            if (val) setDialogState(() => selectedMode = 'upi');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'नोट / विवरण (Optional)',
                      hintText: 'उदा. नकद दिया, Google Pay',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00875A)),
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
                        backgroundColor: const Color(0xFF00875A),
                        behavior: SnackBarBehavior.floating,
                        content: Text('₹$amt जमा दर्ज किया गया। नया बकाया: ₹${newBal.toStringAsFixed(2)}'),
                      ),
                    );
                  }
                },
                child: const Text('Record Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ✏️ Edit Customer Dialog
  void _showEditCustomerDialog() {
    final nameCtrl = TextEditingController(text: _currentCustomer.name);
    final phoneCtrl = TextEditingController(text: _currentCustomer.phone ?? '');
    final addressCtrl = TextEditingController(text: _currentCustomer.address ?? '');
    final limitCtrl = TextEditingController(
      text: _currentCustomer.creditLimit > 0 ? _currentCustomer.creditLimit.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ग्राहक विवरण एडिट करें / Edit Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'नाम (Name) *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'फ़ोन नंबर (Phone)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'पता (Address)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: limitCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'क्रेडिट लिमिट (Credit Limit ₹)',
                  hintText: '0 = Unlimited',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;

              final updated = _currentCustomer.copyWith(
                name: newName,
                phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                creditLimit: double.tryParse(limitCtrl.text.trim()) ?? 0.0,
              );

              await context.read<CustomerProvider>().updateCustomer(updated);
              SoundService.instance.playSuccess();
              setState(() => _currentCustomer = updated);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ग्राहक विवरण अपडेट हो गया')),
                );
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  // 🗑️ Delete Customer Check
  void _confirmDeleteCustomer() {
    if (_currentCustomer.balance > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text('खाता डिलीट नहीं हो सकता!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ग्राहक: ${_currentCustomer.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'इस ग्राहक के खाते में ₹${_currentCustomer.balance.toStringAsFixed(2)} का उधार बकाया है।',
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'नियम: जब तक बकाया शून्य (₹0.00) नहीं हो जाता, खाता सुरक्षा कारणों से डिलीट नहीं किया जा सकता। कृपया पहले "जमा लें" पर जाकर पूरा हिसाब चुकता करें।',
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
              child: const Text('हिसाब चुकता करें (Receive Cash)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ठीक है (OK)'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ग्राहक हटाएं / Delete Customer?'),
        content: Text('क्या आप वाकई ${_currentCustomer.name} का खाता हटाना चाहते हैं?'),
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
                  SnackBar(content: Text('${_currentCustomer.name} को हटा दिया गया')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Customer Details: ', style: TextStyle(fontSize: 14, color: Colors.grey)),
            Flexible(
              child: Text(
                _currentCustomer.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload Data',
            onPressed: _loadData,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 👤 1. Top Customer Profile Card
          _buildProfileHeaderCard(isDark),

          const SizedBox(height: 14),

          // 💰 2. Top Metric KPI Cards (Balance & Sales + Credit Limit Badge)
          _buildTopMetricKpis(isDark),

          const SizedBox(height: 14),

          // ⚡ 3. Direct Action Buttons (Credit Limit, Receive Payment, Reminder)
          _buildActionButtonsRow(),

          const SizedBox(height: 14),

          // 📊 4. Customer Insights Grid
          _buildInsightsGrid(isDark),

          const SizedBox(height: 18),

          // 📑 5. Segmented Navigation Tabs (Bill History, Credit Transactions, Ledger)
          _buildTabsSection(isDark),

          const SizedBox(height: 14),

          // 📋 6. Content according to active tab
          _buildTabContent(isDark),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ==========================================
  // 1. PROFILE HEADER CARD (Fully Responsive)
  // ==========================================
  Widget _buildProfileHeaderCard(bool isDark) {
    final phone = _currentCustomer.phone;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: _currentCustomer.balance > 0
                      ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                      : const Color(0xFF00875A).withValues(alpha: 0.15),
                  child: Text(
                    _currentCustomer.name.isNotEmpty
                        ? _currentCustomer.name.substring(0, 1).toUpperCase()
                        : 'C',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _currentCustomer.balance > 0 ? const Color(0xFFEF4444) : const Color(0xFF00875A),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentCustomer.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      if (phone != null && phone.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 13, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      if (_currentCustomer.address != null && _currentCustomer.address!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 13, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _currentCustomer.address!,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // Responsive Action Chips (Call, WhatsApp, Edit, Delete, Credit Limit)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (phone != null && phone.isNotEmpty) ...[
                  InkWell(
                    onTap: () => _makeCall(phone),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.call_rounded, size: 14, color: Color(0xFF2563EB)),
                          SizedBox(width: 5),
                          Text('कॉल (Call)', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _openWhatsApp(phone),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                          SizedBox(width: 5),
                          Text('व्हाट्सएप', style: TextStyle(color: Color(0xFF16A34A), fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
                InkWell(
                  onTap: _showEditCustomerDialog,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 14, color: Color(0xFF475569)),
                        SizedBox(width: 5),
                        Text('एडिट (Edit)', style: TextStyle(color: Color(0xFF475569), fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: _confirmDeleteCustomer,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                        SizedBox(width: 5),
                        Text('हटाएं (Delete)', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 2. TOP METRIC KPI CARDS
  // ==========================================
  Widget _buildTopMetricKpis(bool isDark) {
    final hasLimit = _currentCustomer.creditLimit > 0;
    final isOverLimit = hasLimit && _currentCustomer.balance >= _currentCustomer.creditLimit;

    return Row(
      children: [
        // Total Balance (Udhar)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3F1B1B) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFCA5A5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 13),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'बकाया (Due)',
                        style: TextStyle(color: Color(0xFF991B1B), fontSize: 12, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '₹ ${_currentCustomer.balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFDC2626),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Credit Limit Indicator
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOverLimit
                          ? const Color(0xFFDC2626)
                          : (hasLimit ? const Color(0xFF2563EB).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      hasLimit
                          ? (isOverLimit
                              ? '⚠️ लिमिट पार! (Max: ₹${_currentCustomer.creditLimit.toStringAsFixed(0)})'
                              : 'लिमिट: ₹${_currentCustomer.creditLimit.toStringAsFixed(0)} (शेष: ₹${(_currentCustomer.creditLimit - _currentCustomer.balance).toStringAsFixed(0)})')
                          : 'लिमिट: सेट नहीं है',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isOverLimit ? Colors.white : (hasLimit ? const Color(0xFF1D4ED8) : Colors.grey.shade700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Total Sale Amount (Lifetime)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF93C5FD)),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 13),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'कुल बिक्री (Sales)',
                        style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '₹ ${_totalSaleAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1D4ED8),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'लाइफटाइम (Lifetime Sales)',
                  style: TextStyle(color: Color(0xFF1E40AF), fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. ACTION BUTTONS ROW
  // ==========================================
  Widget _buildActionButtonsRow() {
    return Row(
      children: [
        // Credit Limit Set Button
        Expanded(
          child: ElevatedButton(
            onPressed: _showSetCreditLimitDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 1,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.speed_rounded, size: 15),
                SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'क्रेडिट लिमिट',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Receive Payment Button
        Expanded(
          child: ElevatedButton(
            onPressed: _showReceiveCashDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00875A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 1,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payments_rounded, size: 15),
                SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'जमा लें',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Send Credit Reminder
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              if (_currentCustomer.phone != null && _currentCustomer.phone!.isNotEmpty) {
                _openWhatsApp(_currentCustomer.phone!);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No phone number added for this customer')),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD97706),
              side: const BorderSide(color: Color(0xFFD97706), width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_active_outlined, size: 15),
                SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'तगादा (Remind)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 4. CUSTOMER INSIGHTS GRID
  // ==========================================
  Widget _buildInsightsGrid(bool isDark) {
    final dateFormat = DateFormat('dd-MM-yyyy');

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth > 500;

            if (isTablet) {
              return Column(
                children: [
                  Row(
                    children: [
                      _buildMetricTile('कुल बिल (Invoices)', '${_customerSales.length} बिल', Icons.receipt_long_rounded),
                      _buildMetricTile('बकाया उधार (Open Credit)', '₹ ${_currentCustomer.balance.toStringAsFixed(2)}', Icons.money_off_rounded),
                      _buildMetricTile('ग्राहक कब से (Since)', dateFormat.format(_currentCustomer.createdAt), Icons.calendar_today_rounded),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      _buildMetricTile('औसत खरीद (Avg Bill)', '₹ ${_avgPurchase.toStringAsFixed(2)}', Icons.analytics_outlined),
                      _buildMetricTile('30 दिन बिक्री (Last 30D)', '₹ ${_last30DaysSale.toStringAsFixed(2)}', Icons.date_range_rounded),
                      _buildMetricTile('खाता स्थिति (Status)', _currentCustomer.balance > 0 ? 'बकाया (Due)' : 'चुकता (Clear)', Icons.verified_user_outlined),
                    ],
                  ),
                ],
              );
            }

            // Mobile: 2-column clean layout
            return Column(
              children: [
                Row(
                  children: [
                    _buildMetricTile('कुल बिल (Invoices)', '${_customerSales.length} बिल', Icons.receipt_long_rounded),
                    const SizedBox(width: 12),
                    _buildMetricTile('बकाया (Due Balance)', '₹ ${_currentCustomer.balance.toStringAsFixed(2)}', Icons.money_off_rounded),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    _buildMetricTile('औसत खरीद (Avg Bill)', '₹ ${_avgPurchase.toStringAsFixed(2)}', Icons.analytics_outlined),
                    const SizedBox(width: 12),
                    _buildMetricTile('30 दिन बिक्री (30D)', '₹ ${_last30DaysSale.toStringAsFixed(2)}', Icons.date_range_rounded),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    _buildMetricTile('ग्राहक कब से (Since)', dateFormat.format(_currentCustomer.createdAt), Icons.calendar_today_rounded),
                    const SizedBox(width: 12),
                    _buildMetricTile('स्थिति (Status)', _currentCustomer.balance > 0 ? 'बकाया (Due)' : 'चुकता (Clear)', Icons.verified_user_outlined),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. TABS SECTION
  // ==========================================
  Widget _buildTabsSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF00875A),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF00875A),
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabs: [
          Tab(
            text: 'बिल इतिहास (${_customerSales.length})',
            icon: const Icon(Icons.receipt_rounded, size: 18),
          ),
          Tab(
            text: 'उधार लेन-देन (${_ledgerEntries.length})',
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          ),
          const Tab(
            text: 'पासबुक खाता',
            icon: Icon(Icons.menu_book_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 6. DYNAMIC TAB CONTENT SWITCHER
  // ==========================================
  Widget _buildTabContent(bool isDark) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    switch (_tabController.index) {
      case 0:
        return _buildBillHistoryTab(isDark);
      case 1:
        return _buildCreditTransactionsTab(isDark);
      case 2:
        return _buildPassbookLedgerTab(isDark);
      default:
        return _buildBillHistoryTab(isDark);
    }
  }

  // ------------------------------------------
  // TAB 0: बिल इतिहास (Bill History)
  // ------------------------------------------
  Widget _buildBillHistoryTab(bool isDark) {
    if (_customerSales.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.receipt_outlined, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text('इस ग्राहक का कोई बिल रिकॉर्ड नहीं मिला', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'बिल इतिहास / Invoices',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  '${_customerSales.length} बिल (टच करके खोलें)',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
            const Divider(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _customerSales.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final sale = _customerSales[i];
                final dateStr = DateFormat('dd-MM-yyyy hh:mm a').format(sale.createdAt);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  onTap: () => _openBillReceipt(sale),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: sale.paymentMode == 'credit'
                        ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                        : const Color(0xFF00875A).withValues(alpha: 0.15),
                    child: Icon(
                      sale.paymentMode == 'credit' ? Icons.receipt_long : Icons.check_circle_outline,
                      size: 18,
                      color: sale.paymentMode == 'credit' ? const Color(0xFFEF4444) : const Color(0xFF00875A),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        'Invoice #${sale.billNo > 0 ? sale.billNo : sale.id.substring(0, 6)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: sale.paymentMode == 'credit'
                              ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                              : const Color(0xFF00875A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          sale.paymentMode.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: sale.paymentMode == 'credit' ? const Color(0xFFDC2626) : const Color(0xFF00875A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '$dateStr · ${sale.items.length} items',
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        CurrencyFormatter.format(sale.total),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.receipt_rounded, size: 20, color: Color(0xFF00875A)),
                        tooltip: 'View Receipt',
                        onPressed: () => _openBillReceipt(sale),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------
  // TAB 1: उधार लेन-देन (Credit Transactions)
  // ------------------------------------------
  Widget _buildCreditTransactionsTab(bool isDark) {
    final entries = _ledgerEntries;

    if (entries.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.swap_horiz_rounded, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text('कोई उधार या जमा लेन-देन दर्ज नहीं है', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'उधार व जमा लेन-देन',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  '${entries.length} रिकॉर्ड',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const Divider(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final e = entries[i];
                final dateStr = DateFormat('dd-MM-yyyy hh:mm a').format(e.date);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  onTap: () {
                    if (e.saleRef != null) {
                      _openBillReceipt(e.saleRef!);
                    }
                  },
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: e.isDebit
                        ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                        : const Color(0xFF00875A).withValues(alpha: 0.15),
                    child: Icon(
                      e.isDebit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 18,
                      color: e.isDebit ? const Color(0xFFEF4444) : const Color(0xFF00875A),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: e.isDebit
                              ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                              : const Color(0xFF00875A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          e.isDebit ? 'उधार (+)' : 'जमा (-)',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: e.isDebit ? const Color(0xFFDC2626) : const Color(0xFF00875A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '$dateStr · ${e.subtitle}',
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                  trailing: Text(
                    '${e.isDebit ? "+ " : "- "}₹${e.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: e.isDebit ? const Color(0xFFDC2626) : const Color(0xFF00875A),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------
  // TAB 2: पासबुक खाता (Passbook / Ledger Statement)
  // ------------------------------------------
  Widget _buildPassbookLedgerTab(bool isDark) {
    final entries = _ledgerEntries;

    if (entries.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.menu_book_rounded, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text('इस खाते में कोई पासबुक एंट्री उपलब्ध नहीं है', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    final totalDebit = entries.where((e) => e.isDebit).fold(0.0, (s, e) => s + e.amount);
    final totalCredit = entries.where((e) => !e.isDebit).fold(0.0, (s, e) => s + e.amount);

    return Column(
      children: [
        // Passbook Header Summary Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('कुल उधार दिया', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '₹ ${totalDebit.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.grey.withValues(alpha: 0.2)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('कुल जमा प्राप्त', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '₹ ${totalCredit.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF00875A)),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.grey.withValues(alpha: 0.2)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('बकाया शेष', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '₹ ${_currentCustomer.balance.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Passbook Statement Table
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('खाता पासबुक / Statement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${entries.length} प्रविष्टियां (Entries)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const Divider(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    final dateStr = DateFormat('dd/MM/yyyy hh:mm a').format(e.date);

                    return InkWell(
                      onTap: () {
                        if (e.saleRef != null) {
                          _openBillReceipt(e.saleRef!);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: e.isDebit
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                                    : const Color(0xFF00875A).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                e.isDebit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                size: 16,
                                color: e.isDebit ? const Color(0xFFDC2626) : const Color(0xFF00875A),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${e.isDebit ? "+" : "-"} ₹${e.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: e.isDebit ? const Color(0xFFDC2626) : const Color(0xFF00875A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'शेष: ₹${e.balanceAfter.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
