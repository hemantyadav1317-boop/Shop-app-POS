import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/sound_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/expense.dart';
import '../../data/models/sale.dart';
import '../../data/services/local_db_service.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';

class DailyProfitScreen extends StatefulWidget {
  const DailyProfitScreen({super.key});

  @override
  State<DailyProfitScreen> createState() => _DailyProfitScreenState();
}

class _DailyProfitScreenState extends State<DailyProfitScreen> {
  String _selectedRange = 'today'; // 'today', 'yesterday', 'last7'
  bool _isLoading = true;
  List<Sale> _filteredSales = [];
  List<Expense> _filteredExpenses = [];

  @override
  void initState() {
    super.initState();
    _loadProfitData();
  }

  Future<void> _loadProfitData() async {
    setState(() => _isLoading = true);
    final shop = context.read<ShopProvider>().shop;

    try {
      final localSales = await LocalDbService.instance.getSales(shop.id);
      final salesSource = localSales.isNotEmpty ? localSales : SupabaseService.instance.currentLocalSales;
      final expensesSource = SupabaseService.instance.currentLocalExpenses;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      final last7Start = todayStart.subtract(const Duration(days: 6));

      List<Sale> sList = [];
      List<Expense> eList = [];

      if (_selectedRange == 'today') {
        sList = salesSource.where((s) => s.createdAt.isAfter(todayStart)).toList();
        eList = expensesSource.where((e) => e.spentOn.isAfter(todayStart)).toList();
      } else if (_selectedRange == 'yesterday') {
        sList = salesSource.where((s) => s.createdAt.isAfter(yesterdayStart) && s.createdAt.isBefore(todayStart)).toList();
        eList = expensesSource.where((e) => e.spentOn.isAfter(yesterdayStart) && e.spentOn.isBefore(todayStart)).toList();
      } else {
        sList = salesSource.where((s) => s.createdAt.isAfter(last7Start)).toList();
        eList = expensesSource.where((e) => e.spentOn.isAfter(last7Start)).toList();
      }

      if (mounted) {
        setState(() {
          _filteredSales = sList;
          _filteredExpenses = eList;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _shareSummaryOnWhatsApp(double revenue, double cost, double expense, double profit, double margin) {
    SoundService.instance.playButtonClick();
    final shop = context.read<ShopProvider>().shop;
    final rangeText = _selectedRange == 'today'
        ? 'आज की'
        : (_selectedRange == 'yesterday' ? 'कल की' : 'पिछले 7 दिनों की');

    final dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());

    final msg = '🏪 *${shop.name}*\n'
        '📊 *$rangeText कमाई रिपोर्ट ($dateStr)*\n'
        '----------------------------------\n'
        '🛒 *कुल बिक्री (Sales):* ${CurrencyFormatter.format(revenue)}\n'
        '📦 *सामान की लागत (Cost):* ${CurrencyFormatter.format(cost)}\n'
        '☕ *दुकान खर्च (Expenses):* ${CurrencyFormatter.format(expense)}\n'
        '----------------------------------\n'
        '🎯 *शुद्ध मुनाफा (Net Profit):* ${CurrencyFormatter.format(profit)}\n'
        '📈 *मुनाफा मार्जिन (Margin):* ${margin.toStringAsFixed(1)}%\n'
        '🧾 *कुल बिल:* ${_filteredSales.length}\n'
        '----------------------------------\n'
        '✓ BillZo POS द्वारा जनरेट किया गया हिसाब।';

    SharePlus.instance.share(
      ShareParams(
        text: msg,
        subject: '${shop.name} Daily Profit Report',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final products = context.watch<ProductProvider>().products;
    final productLookup = {for (var p in products) p.id: p};
    final nameLookup = {for (var p in products) p.name.trim().toLowerCase(): p};

    double totalRevenue = 0.0;
    double totalCost = 0.0;
    final Map<String, _ProfitItemSummary> itemMap = {};

    for (final sale in _filteredSales) {
      totalRevenue += sale.total;
      for (final item in sale.items) {
        final prod = (item.productId != null ? productLookup[item.productId] : null) ??
            nameLookup[item.name.trim().toLowerCase()];

        final purchasePrice = prod?.purchasePrice;
        final costPrice = (purchasePrice != null && purchasePrice > 0)
            ? purchasePrice
            : (item.price * 0.75);

        final lineRevenue = item.total;
        final lineCost = costPrice * item.qty;
        final lineProfit = lineRevenue - lineCost;

        totalCost += lineCost;

        final key = item.productId ?? item.name.trim().toLowerCase();
        if (!itemMap.containsKey(key)) {
          itemMap[key] = _ProfitItemSummary(
            name: item.name,
            qty: item.qty,
            unit: item.unit,
            revenue: lineRevenue,
            profit: lineProfit,
          );
        } else {
          itemMap[key]!.qty += item.qty;
          itemMap[key]!.revenue += lineRevenue;
          itemMap[key]!.profit += lineProfit;
        }
      }
    }

    final totalExpense = _filteredExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final netProfit = (totalRevenue - totalCost) - totalExpense;
    final overallMargin = totalRevenue > 0 ? ((totalRevenue - totalCost) / totalRevenue) * 100 : 0.0;

    final sortedItems = itemMap.values.toList()..sort((a, b) => b.profit.compareTo(a.profit));

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.monetization_on_rounded, color: Color(0xFFFBBF24), size: 22),
            SizedBox(width: 8),
            Text('आज की कमाई (Net Profit)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'WhatsApp पर शेयर करें',
            onPressed: () => _shareSummaryOnWhatsApp(totalRevenue, totalCost, totalExpense, netProfit, overallMargin),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadProfitData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              children: [
                // Date Range Selector
                Row(
                  children: [
                    _buildRangeChip('आज (Today)', 'today', isDark),
                    const SizedBox(width: 8),
                    _buildRangeChip('कल (Yesterday)', 'yesterday', isDark),
                    const SizedBox(width: 8),
                    _buildRangeChip('7 दिन (7 Days)', 'last7', isDark),
                  ],
                ),
                const SizedBox(height: 12),

                // Hero Profit Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF065F46), Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.stars_rounded, color: Color(0xFFFDE68A), size: 18),
                              SizedBox(width: 6),
                              Text(
                                'शुद्ध मुनाफा (NET PROFIT)',
                                style: TextStyle(
                                  color: Color(0xFFD1FAE5),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${overallMargin.toStringAsFixed(1)}% मार्जिन',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        CurrencyFormatter.format(netProfit),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        netProfit >= 0
                            ? 'बिक्री में से खरीद लागत और दुकान खर्च घटाकर बचा असली लाभ ✓'
                            : 'आज का खर्च और लागत बिक्री से अधिक है।',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11.5,
                        ),
                      ),
                      const Divider(height: 20, color: Colors.white24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildHeroSubMetric('कुल बिक्री', CurrencyFormatter.format(totalRevenue)),
                          _buildHeroSubMetric('खरीद लागत', '-${CurrencyFormatter.format(totalCost)}'),
                          _buildHeroSubMetric('दुकान खर्च', '-${CurrencyFormatter.format(totalExpense)}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4 Summary Metrics Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.shopping_bag_outlined,
                        iconColor: const Color(0xFF2563EB),
                        title: 'कुल बिक्री',
                        value: CurrencyFormatter.format(totalRevenue),
                        subtitle: '${_filteredSales.length} बिल काटे',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.inventory_2_outlined,
                        iconColor: const Color(0xFFD97706),
                        title: 'सामान लागत',
                        value: CurrencyFormatter.format(totalCost),
                        subtitle: 'अनुमानित थोक भाव',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.receipt_long_outlined,
                        iconColor: const Color(0xFFDC2626),
                        title: 'दुकान खर्च',
                        value: CurrencyFormatter.format(totalExpense),
                        subtitle: '${_filteredExpenses.length} प्रविष्टियां दर्ज',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.trending_up_rounded,
                        iconColor: const Color(0xFF16A34A),
                        title: 'सकल मार्जिन',
                        value: '${overallMargin.toStringAsFixed(1)}%',
                        subtitle: 'बिक्री पर बचत दर',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Top Profitable Produce / Products Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'सामान अनुसार मुनाफा (Item Breakdown)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '${sortedItems.length} उत्पाद',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (sortedItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'इस समयावधि में कोई बिक्री दर्ज नहीं है।',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ),
                  )
                else
                  ...sortedItems.map((item) {
                    final itemMargin = item.revenue > 0 ? (item.profit / item.revenue) * 100 : 0.0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.12),
                            child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'बिका: ${item.qty.toStringAsFixed(item.unit == 'kg' ? 2 : 0)} ${item.unit} • कुल: ${CurrencyFormatter.format(item.revenue)}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '+${CurrencyFormatter.format(item.profit)}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF16A34A)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${itemMargin.toStringAsFixed(0)}% मार्जिन',
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  Widget _buildRangeChip(String label, String value, bool isDark) {
    final isSelected = _selectedRange == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      selected: isSelected,
      onSelected: (_) {
        SoundService.instance.playButtonClick();
        setState(() => _selectedRange = value);
        _loadProfitData();
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildHeroSubMetric(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 10.5)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

class _ProfitItemSummary {
  final String name;
  double qty;
  final String unit;
  double revenue;
  double profit;

  _ProfitItemSummary({
    required this.name,
    required this.qty,
    required this.unit,
    required this.revenue,
    required this.profit,
  });
}
