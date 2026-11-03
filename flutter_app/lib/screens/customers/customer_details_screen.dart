import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/sound_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/customer.dart';
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

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Customer _currentCustomer;
  List<Sale> _customerSales = [];
  bool _isLoadingSales = true;

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
    _tabController = TabController(length: 3, vsync: this);
    _loadSales();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoadingSales = true);
    final shop = context.read<ShopProvider>().shop;
    final allSales = await SupabaseService.instance.getSales(shop.id);

    final filtered = allSales.where((s) {
      if (s.customerId != null && s.customerId == _currentCustomer.id) return true;
      if (_currentCustomer.phone != null &&
          _currentCustomer.phone!.isNotEmpty &&
          s.customerPhone == _currentCustomer.phone) {
        return true;
      }
      return false;
    }).toList();

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (mounted) {
      setState(() {
        _customerSales = filtered;
        _isLoadingSales = false;
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

  void _showAddCreditDialog() {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_card_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('उधार जोड़ें / Add Credit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ग्राहक: ${_currentCustomer.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'उधार राशि (Amount) *',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'विवरण / Note (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (amt <= 0) return;

              await context.read<CustomerProvider>().addCredit(_currentCustomer.id, amt);
              SoundService.instance.playButtonClick();
              setState(() {
                _currentCustomer = _currentCustomer.copyWith(
                  balance: _currentCustomer.balance + amt,
                );
              });
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    content: Text('₹$amt उधार सफलतापूर्वक जोड़ा गया'),
                  ),
                );
              }
            },
            child: const Text('Add Credit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showReceiveCashDialog() {
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.payments_rounded, color: Color(0xFF00875A)),
            SizedBox(width: 8),
            Text('जमा लें / Receive Cash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ग्राहक: ${_currentCustomer.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'वर्तमान बकाया: ₹${_currentCustomer.balance.toStringAsFixed(2)}',
              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13),
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
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00875A)),
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (amt <= 0) return;

              await context.read<CustomerProvider>().recordPayment(_currentCustomer.id, amt);
              SoundService.instance.playSuccess();
              final newBal = (_currentCustomer.balance - amt) > 0 ? (_currentCustomer.balance - amt) : 0.0;
              setState(() {
                _currentCustomer = _currentCustomer.copyWith(balance: newBal);
              });
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF00875A),
                    behavior: SnackBarBehavior.floating,
                    content: Text('₹$amt जमा दर्ज किया गया। शेष: ₹${newBal.toStringAsFixed(2)}'),
                  ),
                );
              }
            },
            child: const Text('Record Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditCustomerDialog() {
    final nameCtrl = TextEditingController(text: _currentCustomer.name);
    final phoneCtrl = TextEditingController(text: _currentCustomer.phone ?? '');
    final addrCtrl = TextEditingController(text: _currentCustomer.address ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ग्राहक विवरण बदलें / Edit Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'नाम *')),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'मोबाइल नंबर')),
            const SizedBox(height: 10),
            TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'पता / Address')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final updated = _currentCustomer.copyWith(
                name: name,
                phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                address: addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
              );

              await context.read<CustomerProvider>().updateCustomer(updated);
              setState(() => _currentCustomer = updated);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCustomer() {
    if (_currentCustomer.balance > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.error, size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text('खाता नहीं हटाया जा सकता', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ग्राहक "${_currentCustomer.name}" के खाते में ₹${_currentCustomer.balance.toStringAsFixed(2)} का बकाया (उधार) शेष है।',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'खाता हटाने से पहले कृपया \'जमा लें (Receive Cash)\' बटन से पूरा बकाया शून्य (₹0) करें।',
                        style: TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('समझ गया (OK)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('ग्राहक हटाएं / Delete Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('क्या आप "${_currentCustomer.name}" को खाता से डिलीट करना चाहते हैं?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await context.read<CustomerProvider>().deleteCustomer(_currentCustomer.id);
              if (mounted) {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Back to customer list
              }
            },
            child: const Text('हाँ, हटाएं', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            tooltip: 'Reload Bills',
            onPressed: _loadSales,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 👤 1. Top Customer Profile Card
          _buildProfileHeaderCard(isDark),

          const SizedBox(height: 14),

          // 💰 2. Top Metric KPI Cards (Balance Amount & Total Sale Amount)
          _buildTopMetricKpis(isDark),

          const SizedBox(height: 14),

          // ⚡ 3. Direct Action Buttons (Add Credit, Receive Cash, Reminder)
          _buildActionButtonsRow(),

          const SizedBox(height: 14),

          // 📊 4. Customer Insights Grid
          _buildInsightsGrid(isDark),

          const SizedBox(height: 18),

          // 📑 5. Segmented Navigation Tabs (Bill History, Credit Transactions, Ledger)
          _buildTabsSection(isDark),

          const SizedBox(height: 14),

          // 📋 6. Content according to active tab or Recent Sales Table
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
            // Responsive Action Chips (Call, WhatsApp, Edit, Delete)
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
                          Text('व्हाट्सएप (WhatsApp)', style: TextStyle(color: Color(0xFF16A34A), fontSize: 11.5, fontWeight: FontWeight.bold)),
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
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 14, color: Colors.blueGrey),
                        SizedBox(width: 5),
                        Text('एडिट (Edit)', style: TextStyle(color: Colors.blueGrey, fontSize: 11.5, fontWeight: FontWeight.bold)),
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
                      color: const Color(0xFFEF4444).withValues(alpha: 0.08),
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
  // 2. TOP METRIC KPI CARDS (Responsive with FittedBox)
  // ==========================================
  Widget _buildTopMetricKpis(bool isDark) {
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
                const SizedBox(height: 2),
                Text(
                  _currentCustomer.balance > 0 ? 'उधार शेष (Unpaid)' : 'पूरा चुकता (Clear)',
                  style: TextStyle(
                    color: _currentCustomer.balance > 0 ? const Color(0xFFB91C1C) : const Color(0xFF16A34A),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
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
                const SizedBox(height: 2),
                const Text(
                  'लाइफटाइम (Lifetime)',
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
  // 3. ACTION BUTTONS ROW (Equal Height & Single Line)
  // ==========================================
  Widget _buildActionButtonsRow() {
    return Row(
      children: [
        // Add Credit (उधार दें)
        Expanded(
          child: ElevatedButton(
            onPressed: _showAddCreditDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 1,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, size: 15),
                SizedBox(width: 5),
                Flexible(
                  child: Text(
                    '+ उधार दें',
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

        // Receive Cash (जमा लें)
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
                Icon(Icons.arrow_downward_rounded, size: 15),
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
  // 4. CUSTOMER INSIGHTS GRID (Responsive)
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

            // Mobile: 2-column clean layout so labels NEVER truncate!
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
              Icon(icon, size: 14, color: Colors.grey),
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
  // 5. TABS SECTION (Clean Bilingual TabBar)
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
          const Tab(
            text: 'उधार लेन-देन',
            icon: Icon(Icons.swap_horiz_rounded, size: 18),
          ),
          const Tab(
            text: 'पासबुक खाता',
            icon: Icon(Icons.menu_book_rounded, size: 18),
          ),
        ],
        onTap: (_) => setState(() {}),
      ),
    );
  }

  // ==========================================
  // 6. TAB CONTENT (Recent Sales / Bills Table)
  // ==========================================
  Widget _buildTabContent(bool isDark) {
    if (_isLoadingSales) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

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
                Text('No sales records found for this customer yet.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    // Bill History Table matching Image 1
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
                  'Recent Sales / Invoices',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  '${_customerSales.length} Invoices',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.receipt_rounded, size: 20, color: Color(0xFF00875A)),
                        tooltip: 'View Receipt',
                        onPressed: () {
                          final shop = context.read<ShopProvider>().shop;
                          final dateFormat = DateFormat('dd/MM/yyyy, hh:mm a');
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        },
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
}
