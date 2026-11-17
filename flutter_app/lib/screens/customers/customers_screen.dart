import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/sound_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/customer.dart';
import '../../data/services/local_db_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/shop_provider.dart';
import 'add_customer_screen.dart';
import 'customer_details_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _sortOption = 'name_asc'; // 'name_asc', 'balance_desc', 'sale_desc'
  Map<String, double> _customerTotalSales = {};
  bool _isLoadingSales = false;

  @override
  void initState() {
    super.initState();
    _loadCustomerSales();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerSales() async {
    setState(() => _isLoadingSales = true);
    try {
      final shop = context.read<ShopProvider>().shop;
      final sales = await LocalDbService.instance.getSales(shop.id);
      final Map<String, double> totals = {};
      for (final s in sales) {
        if (s.customerId != null && s.customerId!.isNotEmpty) {
          totals[s.customerId!] = (totals[s.customerId!] ?? 0.0) + s.total;
        }
        if (s.customerPhone != null && s.customerPhone!.isNotEmpty) {
          totals[s.customerPhone!] = (totals[s.customerPhone!] ?? 0.0) + s.total;
        }
      }
      if (mounted) {
        setState(() {
          _customerTotalSales = totals;
          _isLoadingSales = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSales = false);
    }
  }

  double _getCustomerSales(Customer c) {
    if (_customerTotalSales.containsKey(c.id)) {
      return _customerTotalSales[c.id]!;
    }
    if (c.phone != null && _customerTotalSales.containsKey(c.phone!)) {
      return _customerTotalSales[c.phone!]!;
    }
    return 0.0;
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'C';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _showSortModal() {
    SoundService.instance.playButtonClick();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sort Customers By',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.sort_by_alpha),
                  title: const Text('Name (A to Z)'),
                  trailing: _sortOption == 'name_asc' ? const Icon(Icons.check, color: AppColors.primary) : null,
                  onTap: () {
                    setState(() => _sortOption = 'name_asc');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.trending_down, color: AppColors.error),
                  title: const Text('Due Balance (Highest First)'),
                  trailing: _sortOption == 'balance_desc' ? const Icon(Icons.check, color: AppColors.primary) : null,
                  onTap: () {
                    setState(() => _sortOption = 'balance_desc');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
                  title: const Text('Total Sale Amount (Highest First)'),
                  trailing: _sortOption == 'sale_desc' ? const Icon(Icons.check, color: AppColors.primary) : null,
                  onTap: () {
                    setState(() => _sortOption = 'sale_desc');
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportCustomerReport(List<Customer> list) async {
    SoundService.instance.playButtonClick();
    if (list.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('Customer Khata Report - ${DateTime.now().toLocal()}');
    buffer.writeln('--------------------------------------------------');
    double totalDue = 0.0;
    for (final c in list) {
      final saleAmt = _getCustomerSales(c);
      totalDue += c.balance;
      buffer.writeln('${c.name} | Phone: ${c.phone ?? "N/A"} | Due: ₹${c.balance.toStringAsFixed(2)} | Total Sales: ₹${saleAmt.toStringAsFixed(2)}');
    }
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('Total Customers: ${list.length} | Total Due: ₹${totalDue.toStringAsFixed(2)}');

    try {
      await Share.share(buffer.toString(), subject: 'Customer Khata Report');
    } catch (_) {}
  }

  void _confirmDeleteCustomer(BuildContext context, Customer customer) {
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('सुरक्षा नियम: केवल दुकान मालिक ग्राहक को डिलीट कर सकते हैं।'),
        ),
      );
      return;
    }
    if (customer.balance > 0) {
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
                'ग्राहक "${customer.name}" के खाते में ${CurrencyFormatter.format(customer.balance)} का बकाया (उधार) शेष है।',
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
                        'खाता हटाने से पहले कृपया पूरा बकाया शून्य (₹0) करें। उधार शेष रहते खाता डिलीट नहीं किया जा सकता।',
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
            Expanded(
              child: Text(
                'Delete Customer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${customer.name}" from customer records?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await context.read<CustomerProvider>().deleteCustomer(customer.id);
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.error,
                    content: Text('${customer.name} deleted'),
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final custProvider = context.watch<CustomerProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<Customer> list = List.from(custProvider.filteredCustomers);
    if (_sortOption == 'name_asc') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sortOption == 'balance_desc') {
      list.sort((a, b) => b.balance.compareTo(a.balance));
    } else if (_sortOption == 'sale_desc') {
      list.sort((a, b) => _getCustomerSales(b).compareTo(_getCustomerSales(a)));
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Customer Management',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white, letterSpacing: 0.3),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () async {
              final shop = context.read<ShopProvider>().shop;
              await context.read<CustomerProvider>().loadCustomers(shop.id);
              await _loadCustomerSales();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Search & Filter Bar matching Billiez Image 2
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Rounded Search Box: Contact/Name/GST No
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Contact/Name/GST No',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        suffixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
                      ),
                      onChanged: (q) => custProvider.setSearchQuery(q),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Sort Button Icon [ ≡⇡ ]
                IconButton(
                  icon: const Icon(Icons.sort_rounded, size: 24, color: Color(0xFF64748B)),
                  tooltip: 'Sort List',
                  onPressed: _showSortModal,
                ),

                // Export Button Icon [ 📥 ]
                IconButton(
                  icon: const Icon(Icons.download_rounded, size: 24, color: Color(0xFF64748B)),
                  tooltip: 'Export List',
                  onPressed: () => _exportCustomerReport(list),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Customers List matching Billiez cards
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final shop = context.read<ShopProvider>().shop;
                await context.read<CustomerProvider>().loadCustomers(shop.id);
                await _loadCustomerSales();
              },
              child: list.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 140),
                        Center(
                          child: Text(
                            'No customers found',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 14,
                        endIndent: 14,
                        color: Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, i) {
                        final customer = list[i];
                        final initials = _getInitials(customer.name);
                        final totalSale = _getCustomerSales(customer);
                        final hasDue = customer.balance > 0.009;

                        return Material(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          child: InkWell(
                            onTap: () {
                              SoundService.instance.playButtonClick();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomerDetailsScreen(customer: customer),
                                ),
                              ).then((_) {
                                final shop = context.read<ShopProvider>().shop;
                                context.read<CustomerProvider>().loadCustomers(shop.id);
                                _loadCustomerSales();
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Left Initials Box: [ VV ]
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initials,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Middle Info Column: Name, Phone, Total Sale Amount
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          customer.name,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          customer.phone ?? '--',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Total Sale Amount : ₹ ${totalSale.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Right Credit Amount Column
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Credit Amount',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹ ${customer.balance.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                          color: hasDue ? const Color(0xFFE11D48) : (isDark ? Colors.white70 : const Color(0xFF0F172A)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      // Central Floating Action Button (+) matching reference
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          SoundService.instance.playButtonClick();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
          ).then((added) {
            if (added == true) {
              final shop = context.read<ShopProvider>().shop;
              context.read<CustomerProvider>().loadCustomers(shop.id);
              _loadCustomerSales();
            }
          });
        },
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}
