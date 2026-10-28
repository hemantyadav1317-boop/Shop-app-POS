import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/sale.dart';
import '../../data/models/product.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/shop_provider.dart';
import '../../providers/product_provider.dart';
import '../../core/services/sound_service.dart';

enum AnalyticsPeriod { today, week, month }

class ItemPerformance {
  final String productName;
  final String? productId;
  final String unit;
  double quantity;
  double revenue;
  double profit;
  double previousQuantity;

  ItemPerformance({
    required this.productName,
    this.productId,
    required this.unit,
    this.quantity = 0.0,
    this.revenue = 0.0,
    this.profit = 0.0,
    this.previousQuantity = 0.0,
  });

  double get marginPercent => revenue > 0 ? (profit / revenue) * 100 : 0.0;

  double get growthPercent {
    if (previousQuantity <= 0) {
      return quantity > 0 ? 100.0 : 0.0;
    }
    return ((quantity - previousQuantity) / previousQuantity) * 100;
  }
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.today;
  bool _isLoading = true;
  List<Sale> _allSales = [];
  bool _showLeastSelling = false;

  @override
  void initState() {
    super.initState();
    _loadSalesData();
  }

  Future<void> _loadSalesData() async {
    setState(() => _isLoading = true);
    final shop = context.read<ShopProvider>().shop;
    final sales = await SupabaseService.instance.getSales(shop.id);
    if (mounted) {
      setState(() {
        _allSales = sales;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final products = context.watch<ProductProvider>().products;

    // Filter sales by selected period and previous comparison period
    final now = DateTime.now();
    DateTime currentStart;
    DateTime previousStart;
    DateTime previousEnd;

    switch (_selectedPeriod) {
      case AnalyticsPeriod.today:
        currentStart = DateTime(now.year, now.month, now.day);
        previousStart = currentStart.subtract(const Duration(days: 1));
        previousEnd = currentStart;
        break;
      case AnalyticsPeriod.week:
        currentStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
        previousStart = currentStart.subtract(const Duration(days: 7));
        previousEnd = currentStart;
        break;
      case AnalyticsPeriod.month:
        currentStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
        previousStart = currentStart.subtract(const Duration(days: 30));
        previousEnd = currentStart;
        break;
    }

    final currentSales = _allSales.where((s) => s.createdAt.isAfter(currentStart)).toList();
    final previousSales = _allSales.where((s) => s.createdAt.isAfter(previousStart) && s.createdAt.isBefore(previousEnd)).toList();

    // Aggregate Metrics
    double totalRevenue = 0.0;
    double totalProfit = 0.0;
    double totalUnitsSold = 0.0;
    final Map<String, ItemPerformance> itemMap = {};

    // Map existing products for quick Cost Price lookup
    final Map<String, Product> productLookup = {for (var p in products) p.id: p};
    final Map<String, Product> nameLookup = {for (var p in products) p.name.toLowerCase(): p};

    for (final sale in currentSales) {
      totalRevenue += sale.total;
      for (final item in sale.items) {
        totalUnitsSold += item.qty;
        final key = item.productId ?? item.name.toLowerCase();

        Product? prod = item.productId != null ? productLookup[item.productId] : nameLookup[item.name.toLowerCase()];
        // Estimated or actual cost price
        final costPrice = prod?.purchasePrice ?? (item.price * 0.75);
        final itemProfit = (item.price - costPrice) * item.qty;
        totalProfit += itemProfit;

        if (!itemMap.containsKey(key)) {
          itemMap[key] = ItemPerformance(
            productName: item.name,
            productId: item.productId,
            unit: item.unit,
            quantity: item.qty,
            revenue: item.total,
            profit: itemProfit,
          );
        } else {
          itemMap[key]!.quantity += item.qty;
          itemMap[key]!.revenue += item.total;
          itemMap[key]!.profit += itemProfit;
        }
      }
    }

    // Previous period performance for Trend Analysis
    for (final sale in previousSales) {
      for (final item in sale.items) {
        final key = item.productId ?? item.name.toLowerCase();
        if (itemMap.containsKey(key)) {
          itemMap[key]!.previousQuantity += item.qty;
        }
      }
    }

    final List<ItemPerformance> itemsList = itemMap.values.toList();
    itemsList.sort((a, b) => _showLeastSelling
        ? a.quantity.compareTo(b.quantity)
        : b.quantity.compareTo(a.quantity));

    final overallMargin = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('बिक्री व मुनाफा रिपोर्ट / Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'रिफ्रेश करें',
            onPressed: _loadSalesData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSalesData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Period Selector Tabs (Today, Week, Month)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildPeriodButton('आज (Today)', AnalyticsPeriod.today),
                          _buildPeriodButton('इस हफ्ते (7 Days)', AnalyticsPeriod.week),
                          _buildPeriodButton('इस महीने (30 Days)', AnalyticsPeriod.month),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. High-Level KPI Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            title: 'कुल बिक्री (Revenue)',
                            value: CurrencyFormatter.format(totalRevenue),
                            icon: Icons.currency_rupee_rounded,
                            color: const Color(0xFF2563EB),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            title: 'कुल मुनाफा (Profit)',
                            value: CurrencyFormatter.format(totalProfit),
                            subtitle: '${overallMargin.toStringAsFixed(1)}% मार्जिन',
                            icon: Icons.trending_up_rounded,
                            color: const Color(0xFF00875A),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            title: 'कुल बिल (Invoices)',
                            value: '${currentSales.length}',
                            icon: Icons.receipt_long_outlined,
                            color: const Color(0xFF7C3AED),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            title: 'आइटम्स बिके (Qty)',
                            value: '${totalUnitsSold.toStringAsFixed(1)} Units',
                            icon: Icons.inventory_2_outlined,
                            color: const Color(0xFFEA580C),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 3. Top-Selling vs Least-Selling Header Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _showLeastSelling ? '📉 कम बिकने वाले सामान (Slow-Moving)' : '🔥 सबसे ज्यादा बिकने वाले (Top-Selling)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            SoundService.instance.playButtonClick();
                            setState(() => _showLeastSelling = !_showLeastSelling);
                          },
                          icon: Icon(_showLeastSelling ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
                          label: Text(_showLeastSelling ? 'Top देखें' : 'Least देखें', style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 4. Item-wise Performance & Trend Table
                    if (itemsList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(28),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.bar_chart_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            const Text('इस समयावधि में कोई बिक्री दर्ज नहीं है', style: TextStyle(color: AppColors.lightTextSecondary)),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: itemsList.length > 20 ? 20 : itemsList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final item = itemsList[idx];
                          final growth = item.growthPercent;
                          final isPositive = growth >= 0;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Rank Badge
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: idx < 3 && !_showLeastSelling
                                        ? const Color(0xFF00875A).withOpacity(0.15)
                                        : Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '#${idx + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: idx < 3 && !_showLeastSelling
                                          ? const Color(0xFF00875A)
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Product Name & Stats
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'बिक्री: ${item.quantity.toStringAsFixed(1)} ${item.unit} • कुल: ${CurrencyFormatter.format(item.revenue)}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                                      ),
                                    ],
                                  ),
                                ),

                                // Profit & Trend Badge
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '+${CurrencyFormatter.format(item.profit)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF00875A),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isPositive ? Icons.trending_up : Icons.trending_down,
                                            size: 11,
                                            color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${isPositive ? "+" : ""}${growth.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodButton(String title, AnalyticsPeriod period) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          SoundService.instance.playButtonClick();
          setState(() => _selectedPeriod = period);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00875A) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
          ],
        ],
      ),
    );
  }
}

