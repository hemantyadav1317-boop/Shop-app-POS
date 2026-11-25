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
import '../../providers/locale_provider.dart';
import '../../core/localization/multilingual_catalog.dart';

class DailyProfitScreen extends StatefulWidget {
  const DailyProfitScreen({super.key});

  @override
  State<DailyProfitScreen> createState() => _DailyProfitScreenState();
}

class _DailyProfitScreenState extends State<DailyProfitScreen> {
  String _selectedRange = 'today'; // 'today', 'yesterday', 'last7'
  bool _isLoading = true;
  bool _showItemBreakdownList = false;
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
        sList = salesSource.where((s) => !s.createdAt.toLocal().isBefore(todayStart)).toList();
        eList = expensesSource.where((e) => !e.spentOn.toLocal().isBefore(todayStart)).toList();
      } else if (_selectedRange == 'yesterday') {
        sList = salesSource.where((s) {
          final local = s.createdAt.toLocal();
          return !local.isBefore(yesterdayStart) && local.isBefore(todayStart);
        }).toList();
        eList = expensesSource.where((e) {
          final local = e.spentOn.toLocal();
          return !local.isBefore(yesterdayStart) && local.isBefore(todayStart);
        }).toList();
      } else {
        sList = salesSource.where((s) => !s.createdAt.toLocal().isBefore(last7Start)).toList();
        eList = expensesSource.where((e) => !e.spentOn.toLocal().isBefore(last7Start)).toList();
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

  Future<void> _pickCustomDate() async {
    SoundService.instance.playButtonClick();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _isLoading = true);
      final shop = context.read<ShopProvider>().shop;
      final localSales = await LocalDbService.instance.getSales(shop.id);
      final salesSource = localSales.isNotEmpty ? localSales : SupabaseService.instance.currentLocalSales;
      final expensesSource = SupabaseService.instance.currentLocalExpenses;

      final startOfDay = DateTime(picked.year, picked.month, picked.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final sList = salesSource.where((s) {
        final local = s.createdAt.toLocal();
        return !local.isBefore(startOfDay) && local.isBefore(endOfDay);
      }).toList();
      final eList = expensesSource.where((e) {
        final local = e.spentOn.toLocal();
        return !local.isBefore(startOfDay) && local.isBefore(endOfDay);
      }).toList();

      if (mounted) {
        setState(() {
          _selectedRange = 'custom';
          _filteredSales = sList;
          _filteredExpenses = eList;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final products = context.watch<ProductProvider>().products;
    final localeCode = context.watch<LocaleProvider>().localeCode;
    final isHindi = localeCode == 'hi';

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

    final subtitleText = _selectedRange == 'last7'
        ? (isHindi ? 'पिछले 7 दिनों में आपके व्यवसाय का शुद्ध लाभ' : 'Net profit for the last 7 days')
        : (_selectedRange == 'yesterday'
            ? (isHindi ? 'कल के व्यवसाय का शुद्ध लाभ' : 'Net profit for yesterday')
            : (isHindi ? 'आज के व्यवसाय का शुद्ध लाभ' : 'Net profit for today'));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF0A2540),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Back',
          onPressed: () {
            SoundService.instance.playButtonClick();
            Navigator.pop(context);
          },
        ),
        title: Text(
          isHindi ? 'आज की कमाई' : 'Net Profit & Earnings',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            tooltip: 'WhatsApp पर शेयर करें',
            onPressed: () => _shareSummaryOnWhatsApp(totalRevenue, totalCost, totalExpense, netProfit, overallMargin),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'रिफ्रेश',
            onPressed: () {
              SoundService.instance.playButtonClick();
              _loadProfitData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
                children: [
                // 1. Date Range Filter Pills + Calendar Icon Button
                Row(
                  children: [
                    _buildRangePill('आज', 'today', isDark),
                    const SizedBox(width: 8),
                    _buildRangePill('कल', 'yesterday', isDark),
                    const SizedBox(width: 8),
                    _buildRangePill('7 दिन', 'last7', isDark),
                    const Spacer(),
                    // Calendar Picker Button
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _pickCustomDate,
                      child: Container(
                        width: 42,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedRange == 'custom'
                                ? const Color(0xFF0A2540)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          color: isDark ? Colors.white70 : const Color(0xFF0A2540),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2. Emerald Gradient Hero Card with 3D Growth Chart
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF047857), Color(0xFF065F46), Color(0xFF064E3B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Star Pill & Margin Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 16),
                                const SizedBox(width: 5),
                                Text(
                                  isHindi ? 'शुद्ध मुनाफा' : 'Net Profit',
                                  style: const TextStyle(
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.trending_up_rounded, color: Colors.white, size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  '${overallMargin.toStringAsFixed(1)}% मार्जिन',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Middle Section: Amount & 3D Growth Bars Graphic
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  CurrencyFormatter.format(netProfit),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 32,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitleText,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Vector 3D Rising Bar Chart with Gold Arrow
                          const _RisingGrowthGraphic(),
                        ],
                      ),

                      const SizedBox(height: 14),
                      Divider(height: 1, thickness: 0.8, color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 12),

                      // Bottom 3-Column Summary Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeroSubMetric(
                              isHindi ? 'कुल बिक्री' : 'Total Sales',
                              CurrencyFormatter.format(totalRevenue),
                            ),
                          ),
                          Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.2)),
                          Expanded(
                            child: _buildHeroSubMetric(
                              isHindi ? 'कुल लागत' : 'Total Cost',
                              CurrencyFormatter.format(totalCost),
                            ),
                          ),
                          Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.2)),
                          Expanded(
                            child: _buildHeroSubMetric(
                              isHindi ? 'कुल मुनाफा' : 'Total Profit',
                              CurrencyFormatter.format(netProfit),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. 2x2 Soft Pastel Metric Grid Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildPastelMetricCard(
                        isDark: isDark,
                        bgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                        iconBgColor: const Color(0xFF1D4ED8),
                        icon: Icons.shopping_bag_rounded,
                        title: isHindi ? 'कुल बिक्री' : 'Total Sales',
                        value: CurrencyFormatter.format(totalRevenue),
                        subtitle: isHindi ? '${_filteredSales.length} बिल तक' : '${_filteredSales.length} Bills',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildPastelMetricCard(
                        isDark: isDark,
                        bgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF7ED),
                        iconBgColor: const Color(0xFFEA580C),
                        icon: Icons.currency_rupee_rounded,
                        title: isHindi ? 'सामान लागत' : 'Cost of Goods',
                        value: CurrencyFormatter.format(totalCost),
                        subtitle: isHindi ? 'अनुमानित मोल भाव' : 'Estimated Wholesale',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildPastelMetricCard(
                        isDark: isDark,
                        bgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF2F2),
                        iconBgColor: const Color(0xFFDC2626),
                        icon: Icons.receipt_long_rounded,
                        title: isHindi ? 'दुकान खर्च' : 'Expenses',
                        value: CurrencyFormatter.format(totalExpense),
                        subtitle: isHindi ? '${_filteredExpenses.length} प्रविष्टियां दर्ज' : '${_filteredExpenses.length} Entries',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildPastelMetricCard(
                        isDark: isDark,
                        bgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
                        iconBgColor: const Color(0xFF16A34A),
                        icon: Icons.trending_up_rounded,
                        title: isHindi ? 'माल का मार्जिन' : 'Gross Margin',
                        value: '${overallMargin.toStringAsFixed(1)}%',
                        subtitle: isHindi ? 'देखें पर बचत दर' : 'Profit % on sales',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Item Breakdown Accordion Pill Card
                Material(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      SoundService.instance.playButtonClick();
                      setState(() => _showItemBreakdownList = !_showItemBreakdownList);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.info_rounded, color: Colors.white, size: 17),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isHindi ? 'सामान अनुसार मुनाफा' : 'Item-wise Profit Breakdown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Text(
                            isHindi ? '${sortedItems.length} उत्पाद' : '${sortedItems.length} Items',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF1D4ED8),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showItemBreakdownList ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_right_rounded,
                            size: 20,
                            color: isDark ? Colors.white70 : const Color(0xFF1D4ED8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 5. Empty State or Items List
                if (sortedItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 6),
                          Text(
                            isHindi ? 'इस जानकारी में कोई पिछली दर्ज नहीं है।' : 'No sales recorded for this period.',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_showItemBreakdownList)
                  ...sortedItems.map((item) {
                    final itemMargin = item.revenue > 0 ? (item.profit / item.revenue) * 100 : 0.0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
                                  item.localizedName(localeCode),
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
                  })
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        isHindi ? 'सभी उत्पादों का मुनाफा देखने के लिए ऊपर टैप करें' : 'Tap above to see all items',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  Widget _buildRangePill(String label, String value, bool isDark) {
    final isSelected = _selectedRange == value;
    return Material(
      color: isSelected
          ? (isDark ? Colors.white : const Color(0xFF0A2540))
          : (isDark ? const Color(0xFF1E293B) : Colors.white),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          SoundService.instance.playButtonClick();
          setState(() => _selectedRange = value);
          _loadProfitData();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? (isDark ? Colors.white : const Color(0xFF0A2540))
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: 1.2,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: const Color(0xFF0A2540).withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: isDark ? const Color(0xFF0A2540) : Colors.white,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (isDark ? const Color(0xFF0A2540) : Colors.white)
                      : (isDark ? Colors.white70 : const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSubMetric(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            val,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPastelMetricCard({
    required bool isDark,
    required Color bgColor,
    required Color iconBgColor,
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : iconBgColor.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF0F172A)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Custom Canvas 3D Rising Bar Chart with Gold Growth Arrow
class _RisingGrowthGraphic extends StatelessWidget {
  const _RisingGrowthGraphic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 64,
      child: CustomPaint(
        painter: _RisingBarsPainter(),
      ),
    );
  }
}

class _RisingBarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 5;
    final totalWidth = size.width;
    final maxHeight = size.height - 12;
    final barWidth = 10.0;
    final spacing = (totalWidth - (barCount * barWidth) - 10) / (barCount - 1);

    final heights = [
      maxHeight * 0.30,
      maxHeight * 0.45,
      maxHeight * 0.60,
      maxHeight * 0.78,
      maxHeight * 0.95,
    ];

    // Draw ascending rounded bars with mint glow
    for (int i = 0; i < barCount; i++) {
      final x = 4.0 + (i * (barWidth + spacing));
      final h = heights[i];
      final y = size.height - h;

      final barPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF34D399), Color(0xFF10B981)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(x, y, barWidth, h));

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, h),
        const Radius.circular(4),
      );
      canvas.drawRRect(rrect, barPaint);
    }

    // Draw Golden Upward Growth Arrow
    final arrowPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(6, size.height - heights[0] + 6);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.45,
      size.width - 4,
      8,
    );
    canvas.drawPath(path, arrowPaint);

    // Arrow Head
    final arrowHeadPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.fill;

    final headPath = Path();
    headPath.moveTo(size.width - 2, 6);
    headPath.lineTo(size.width - 12, 8);
    headPath.lineTo(size.width - 6, 14);
    headPath.close();
    canvas.drawPath(headPath, arrowHeadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

  String localizedName([String localeCode = 'hi']) {
    final regional = MultilingualCatalog.lookup(name, localeCode);
    if (regional != null && regional.isNotEmpty) {
      return regional;
    }

    final isEn = localeCode == 'en';
    final parenMatch = RegExp(r'^(.*?)\s*\((.*?)\)\s*$').firstMatch(name);
    if (parenMatch != null) {
      final part1 = parenMatch.group(1)?.trim() ?? '';
      final part2 = parenMatch.group(2)?.trim() ?? '';

      final part1HasHindi = RegExp(r'[\u0900-\u097F]').hasMatch(part1);
      final part2HasHindi = RegExp(r'[\u0900-\u097F]').hasMatch(part2);

      if (isEn) {
        if (!part2HasHindi && part2.isNotEmpty) return part2;
        if (!part1HasHindi && part1.isNotEmpty) return part1;
      } else if (localeCode == 'hi' || localeCode == 'mr') {
        if (part1HasHindi && part1.isNotEmpty) return part1;
        if (part2HasHindi && part2.isNotEmpty) return part2;
      } else {
        if (!part2HasHindi && part2.isNotEmpty) return part2;
        if (!part1HasHindi && part1.isNotEmpty) return part1;
        if (part1HasHindi && part1.isNotEmpty) return part1;
      }
    }
    return name;
  }
}
