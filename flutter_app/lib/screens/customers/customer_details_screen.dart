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
  // 1. PROFILE HEADER CARD
  // ==========================================
  Widget _buildProfileHeaderCard(bool isDark) {
    final phone = _currentCustomer.phone;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _currentCustomer.balance > 0
                  ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                  : const Color(0xFF00875A).withValues(alpha: 0.15),
              child: Text(
                _currentCustomer.name.isNotEmpty
                    ? _currentCustomer.name.substring(0, 1).toUpperCase()
                    : 'C',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _currentCustomer.balance > 0 ? const Color(0xFFEF4444) : const Color(0xFF00875A),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _currentCustomer.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _showEditCustomerDialog,
                        child: const Text('Edit', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const Text(' · ', style: TextStyle(color: Colors.grey)),
                      InkWell(
                        onTap: _confirmDeleteCustomer,
                        child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (phone != null && phone.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(phone, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (_currentCustomer.address != null && _currentCustomer.address!.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
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
            if (phone != null && phone.isNotEmpty) ...[
              // Quick Call & WhatsApp Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _makeCall(phone),
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call, color: Color(0xFF2563EB), size: 18),
                    ),
                    tooltip: 'Call Customer',
                  ),
                  IconButton(
                    onPressed: () => _openWhatsApp(phone),
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF16A34A), size: 18),
                    ),
                    tooltip: 'WhatsApp Reminder',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 2. TOP METRIC KPI CARDS
  // ==========================================
  Widget _buildTopMetricKpis(bool isDark) {
    return Row(
      children: [
        // Total Balance (Udhar)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Total Balance Amount',
                        style: TextStyle(color: Color(0xFF991B1B), fontSize: 11.5, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Rs ${_currentCustomer.balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '(Unpaid Amount)',
                  style: TextStyle(color: Color(0xFFB91C1C), fontSize: 10.5),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Total Sale Amount (Lifetime)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF93C5FD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Total Sale Amount',
                        style: TextStyle(color: Color(0xFF1E40AF), fontSize: 11.5, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Rs ${_totalSaleAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '(Total Sale of User)',
                  style: TextStyle(color: Color(0xFF1E40AF), fontSize: 10.5),
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
        // Add Credit (उधार दें)
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showAddCreditDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: const Text('Add Credit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),

        const SizedBox(width: 10),

        // Receive Cash (जमा लें)
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showReceiveCashDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00875A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.arrow_downward_rounded, size: 16),
            label: const Text('Receive Cash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),

        const SizedBox(width: 10),

        // Send Credit Reminder
        Expanded(
          child: OutlinedButton.icon(
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
              side: const BorderSide(color: Color(0xFFD97706)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.notifications_active_outlined, size: 16),
            label: const Text('Reminder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
        child: Column(
          children: [
            Row(
              children: [
                _buildMetricTile('Total Invoices Created', '${_customerSales.length}', Icons.receipt_long_rounded),
                _buildMetricTile('Total Open Credit', 'Rs ${_currentCustomer.balance.toStringAsFixed(2)}', Icons.money_off_rounded),
                _buildMetricTile('Customer Since', dateFormat.format(_currentCustomer.createdAt), Icons.calendar_today_rounded),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                _buildMetricTile('Average Purchase', 'Rs ${_avgPurchase.toStringAsFixed(2)}', Icons.analytics_outlined),
                _buildMetricTile('Last 30 Days', 'Rs ${_last30DaysSale.toStringAsFixed(2)}', Icons.date_range_rounded),
                _buildMetricTile('Status', _currentCustomer.balance > 0 ? 'Due Pending' : 'Clear', Icons.verified_user_outlined),
              ],
            ),
          ],
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
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. TABS SECTION (Bill History, Credit Transactions, Ledger)
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
        tabs: [
          Tab(
            text: 'Bill History (${_customerSales.length})',
            icon: const Icon(Icons.receipt_rounded, size: 18),
          ),
          const Tab(
            text: 'Credit Activity',
            icon: Icon(Icons.swap_horiz_rounded, size: 18),
          ),
          const Tab(
            text: 'Passbook Ledger',
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
