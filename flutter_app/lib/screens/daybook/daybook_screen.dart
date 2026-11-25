import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/sale.dart';
import '../../data/models/expense.dart';
import '../../data/services/local_db_service.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/shop_provider.dart';
import '../../providers/locale_provider.dart';
import '../../core/services/sound_service.dart';
import '../analytics/analytics_screen.dart';
import '../reports/daily_profit_screen.dart';
import '../main_shell.dart';

class DaybookScreen extends StatefulWidget {
  final bool isMainTab;

  const DaybookScreen({super.key, this.isMainTab = false});

  @override
  State<DaybookScreen> createState() => _DaybookScreenState();
}

class _DaybookScreenState extends State<DaybookScreen> {
  List<Sale> _todaySales = [];
  List<Expense> _todayExpenses = [];
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todaySales = SupabaseService.instance.currentLocalSales.where((s) {
      return s.createdAt.year == now.year &&
          s.createdAt.month == now.month &&
          s.createdAt.day == now.day;
    }).toList();
    _todayExpenses = SupabaseService.instance.currentLocalExpenses.where((e) {
      return e.spentOn.year == now.year &&
          e.spentOn.month == now.month &&
          e.spentOn.day == now.day;
    }).toList();
    _loadDaybook();
  }

  Future<void> _loadDaybook() async {
    final shop = context.read<ShopProvider>().shop;
    final now = _selectedDate;

    // ⚡ 1. INSTANT LOCAL LOAD (<10ms): Read immediately from local storage and memory
    final localSales = await LocalDbService.instance.getSales(shop.id);
    final salesSource = localSales.isNotEmpty ? localSales : SupabaseService.instance.currentLocalSales;
    final expensesSource = SupabaseService.instance.currentLocalExpenses;

    final initialTodaySales = salesSource.where((s) {
      return s.createdAt.year == now.year &&
          s.createdAt.month == now.month &&
          s.createdAt.day == now.day;
    }).toList();

    final initialTodayExpenses = expensesSource.where((e) {
      return e.spentOn.year == now.year &&
          e.spentOn.month == now.month &&
          e.spentOn.day == now.day;
    }).toList();

    if (mounted) {
      setState(() {
        _todaySales = initialTodaySales;
        _todayExpenses = initialTodayExpenses;
        _isLoading = false;
      });
    }

    // ⚡ 2. QUIET BACKGROUND REFRESH: fetch latest cloud updates without blocking the UI
    unawaited(Future(() async {
      try {
        final allSales = await SupabaseService.instance.getSales(shop.id).timeout(const Duration(seconds: 4));
        final allExpenses = await SupabaseService.instance.getExpenses(shop.id).timeout(const Duration(seconds: 4));

        final refreshedTodaySales = allSales.where((s) {
          return s.createdAt.year == now.year &&
              s.createdAt.month == now.month &&
              s.createdAt.day == now.day;
        }).toList();

        final refreshedTodayExpenses = allExpenses.where((e) {
          return e.spentOn.year == now.year &&
              e.spentOn.month == now.month &&
              e.spentOn.day == now.day;
        }).toList();

        if (mounted) {
          setState(() {
            _todaySales = refreshedTodaySales;
            _todayExpenses = refreshedTodayExpenses;
          });
        }
      } catch (_) {}
    }));
  }

  Future<void> _pickDate() async {
    SoundService.instance.playButtonClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadDaybook();
    }
  }

  void _showAddExpenseDialog() {
    SoundService.instance.playButtonClick();
    final isHindi = context.read<LocaleProvider>().localeCode == 'hi';
    final catCtrl = TextEditingController(text: isHindi ? 'चाय-नाश्ता' : 'Tea/Snacks');
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    void attachTypeSound(TextEditingController ctrl) {
      String prev = ctrl.text;
      ctrl.addListener(() {
        if (ctrl.text != prev) {
          prev = ctrl.text;
          SoundService.instance.playTypeKey();
        }
      });
    }

    attachTypeSound(catCtrl);
    attachTypeSound(amtCtrl);
    attachTypeSound(noteCtrl);

    final categories = isHindi
        ? ['☕ चाय-नाश्ता', '🏠 दुकान किराया', '⚡ बिजली बिल', '🚚 माल भाड़ा', '🧹 साफ-सफाई', '📦 अन्य खर्च']
        : ['☕ Tea/Snacks', '🏠 Shop Rent', '⚡ Electricity', '🚚 Freight', '🧹 Cleaning', '📦 Misc'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.error, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? 'दुकान खर्च जोड़ें' : 'Add Shop Expense',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      isHindi ? 'दैनिक खर्चे का हिसाब रखें' : 'Record daily cash out',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHindi ? 'खर्च का प्रकार (Category):' : 'Expense Category:',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: categories.map((cat) {
                    final isSel = catCtrl.text == cat;
                    return InkWell(
                      onTap: () {
                        SoundService.instance.playButtonClick();
                        setDlgState(() => catCtrl.text = cat);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFFF5722).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSel ? const Color(0xFFFF5722) : Colors.transparent),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? const Color(0xFFFF5722) : null,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: isHindi ? 'रुपया / Amount *' : 'Amount *',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: isHindi ? 'विवरण (वैकल्पिक)' : 'Note (Optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final amt = double.tryParse(amtCtrl.text) ?? 0.0;
                if (amt <= 0) return;
                final shop = context.read<ShopProvider>().shop;

                await SupabaseService.instance.addExpense(
                  Expense(
                    id: const Uuid().v4(),
                    shopId: shop.id,
                    category: catCtrl.text.trim().isEmpty ? (isHindi ? 'दुकान खर्च' : 'Shop Expense') : catCtrl.text.trim(),
                    amount: amt,
                    note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                    spentOn: DateTime.now(),
                    createdAt: DateTime.now(),
                  ),
                );
                SoundService.instance.playSuccess();

                if (context.mounted) {
                  Navigator.pop(ctx);
                  _loadDaybook();
                }
              },
              child: Text(isHindi ? 'खर्च सेव करें' : 'Save Expense', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHindi = context.watch<LocaleProvider>().localeCode == 'hi';

    final cashIn = _todaySales
        .where((s) => s.paymentMode == 'cash' || s.paymentMode == 'split')
        .fold(0.0, (sum, s) => sum + s.paid);
    final upiIn = _todaySales
        .where((s) => s.paymentMode == 'online')
        .fold(0.0, (sum, s) => sum + s.paid);
    final cashOut = _todayExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final netDrawer = cashIn - cashOut;

    final dateFormat = DateFormat('hh:mm a');
    final canPop = !widget.isMainTab && Navigator.canPop(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isHindi ? 'रोकड़ बही' : 'Daybook',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFF5722),
        foregroundColor: Colors.white,
        elevation: 0,
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
                tooltip: 'Menu',
                onPressed: () {
                  SoundService.instance.playButtonClick();
                  MainShell.openDrawer(context);
                },
              ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
              ),
              child: const Icon(Icons.currency_rupee_rounded, size: 16, color: Colors.white),
            ),
            tooltip: isHindi ? 'आज की कमाई' : 'Profit Report',
            onPressed: () {
              SoundService.instance.playButtonClick();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyProfitScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            tooltip: 'Sales Analytics',
            onPressed: () {
              SoundService.instance.playButtonClick();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.post_add_rounded, color: Colors.white),
            tooltip: isHindi ? 'खर्च जोड़ें' : 'Add Expense',
            onPressed: _showAddExpenseDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: isHindi ? 'रिफ्रेश' : 'Refresh',
            onPressed: () {
              SoundService.instance.playButtonClick();
              _loadDaybook();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5722)))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 850;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWide ? 850 : double.infinity),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),

                        // 1. Sales & Profit Analytics Banner (Peach Card with Trending Icon)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Material(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF3ED),
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                SoundService.instance.playButtonClick();
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyProfitScreen()));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFFFE0D2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6D00),
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isHindi ? 'बिक्री व मुनाफा एनालिटिक्स' : 'Sales & Profit Analytics',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isHindi
                                                ? 'अपनी बिक्री, मुनाफा मार्जिन और ट्रेंड्स देखें'
                                                : 'View your sales, profit margins and trends',
                                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 22),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 2. Net Drawer Cash Hero Card (Clean White Rounded Card with 3 Pastel Tiles)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header inside Hero Card
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF6D00).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFFF6D00), size: 18),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isHindi ? 'गल्ला कैश' : 'Net Drawer Cash',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.5,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Date Selector Pill
                                  InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: _pickDate,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFFFF3ED),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFFFF6D00)),
                                          const SizedBox(width: 5),
                                          Text(
                                            DateFormat('dd MMM yyyy').format(_selectedDate),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFFF6D00),
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFFFF6D00)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Big Orange / Neutral Amount
                              Text(
                                CurrencyFormatter.format(netDrawer),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 34,
                                  color: Color(0xFFFF5722),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // 3 Pastel Metric Cards inside Hero Card
                              Row(
                                children: [
                                  // 1. नकद आया (Cash In)
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 18,
                                                height: 18,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF16A34A),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.arrow_downward_rounded, size: 12, color: Colors.white),
                                              ),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  isHindi ? 'नकद आया' : 'Cash In',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF166534),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              CurrencyFormatter.format(cashIn),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14,
                                                color: Color(0xFF166534),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // 2. ऑनलाइन (Online / UPI)
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 18,
                                                height: 18,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF0284C7),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.qr_code_2_rounded, size: 12, color: Colors.white),
                                              ),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  isHindi ? 'ऑनलाइन' : 'Online',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF075985),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              CurrencyFormatter.format(upiIn),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14,
                                                color: Color(0xFF075985),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // 3. कुल खर्च (Expenses)
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 18,
                                                height: 18,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFDC2626),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.arrow_upward_rounded, size: 12, color: Colors.white),
                                              ),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  isHindi ? 'कुल खर्च' : 'Expense',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF991B1B),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              CurrencyFormatter.format(cashOut),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14,
                                                color: Color(0xFF991B1B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 3. Today's Entries Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 3.5,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF5722),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isHindi ? "आज के लेनदेन (Today's Entries)" : "Today's Entries",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_todaySales.length + _todayExpenses.length} लेनदेन',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        // 4. Transactions List or Illustrated Empty State
                        Expanded(
                          child: (_todaySales.isEmpty && _todayExpenses.isEmpty)
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.assignment_outlined, size: 36, color: Color(0xFF94A3B8)),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        isHindi ? 'आज अभी तक कोई लेनदेन नहीं हुआ' : 'No transactions recorded today',
                                        style: TextStyle(
                                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  children: [
                                    ..._todaySales.map((sale) => Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.025),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 17,
                                                backgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                                child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF16A34A), size: 18),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'बिल #${sale.billNo} • ${sale.customerName ?? "Walk-in Customer"}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13.5,
                                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          dateFormat.format(sale.createdAt),
                                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                          decoration: BoxDecoration(
                                                            color: (sale.paymentMode == 'cash'
                                                                    ? const Color(0xFF16A34A)
                                                                    : const Color(0xFF0284C7))
                                                                .withValues(alpha: 0.12),
                                                            borderRadius: BorderRadius.circular(5),
                                                          ),
                                                          child: Text(
                                                            sale.paymentMode.toUpperCase(),
                                                            style: TextStyle(
                                                              fontSize: 9.5,
                                                              fontWeight: FontWeight.bold,
                                                              color: sale.paymentMode == 'cash'
                                                                  ? const Color(0xFF16A34A)
                                                                  : const Color(0xFF0284C7),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                '+ ${CurrencyFormatter.format(sale.paid)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF16A34A),
                                                  fontSize: 14.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                    ..._todayExpenses.map((exp) => Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.025),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 17,
                                                backgroundColor: const Color(0xFFDC2626).withValues(alpha: 0.12),
                                                child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFFDC2626), size: 18),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      exp.category,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13.5,
                                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${dateFormat.format(exp.spentOn)}${exp.note != null ? " • ${exp.note}" : ""}',
                                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                '- ${CurrencyFormatter.format(exp.amount)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFFDC2626),
                                                  fontSize: 14.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                  ],
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
