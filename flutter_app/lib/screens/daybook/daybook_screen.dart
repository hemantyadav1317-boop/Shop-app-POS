import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/sale.dart';
import '../../data/models/expense.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/shop_provider.dart';
import '../../core/services/sound_service.dart';
import '../analytics/analytics_screen.dart';

class DaybookScreen extends StatefulWidget {
  const DaybookScreen({super.key});

  @override
  State<DaybookScreen> createState() => _DaybookScreenState();
}

class _DaybookScreenState extends State<DaybookScreen> {
  List<Sale> _todaySales = [];
  List<Expense> _todayExpenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDaybook();
  }

  Future<void> _loadDaybook() async {
    setState(() => _isLoading = true);
    final shop = context.read<ShopProvider>().shop;
    final allSales = await SupabaseService.instance.getSales(shop.id);
    final allExpenses = await SupabaseService.instance.getExpenses(shop.id);

    final now = DateTime.now();
    final todaySales = allSales.where((s) {
      return s.createdAt.year == now.year &&
          s.createdAt.month == now.month &&
          s.createdAt.day == now.day;
    }).toList();

    final todayExpenses = allExpenses.where((e) {
      return e.spentOn.year == now.year &&
          e.spentOn.month == now.month &&
          e.spentOn.day == now.day;
    }).toList();

    setState(() {
      _todaySales = todaySales;
      _todayExpenses = todayExpenses;
      _isLoading = false;
    });
  }

  void _showAddExpenseDialog() {
    final catCtrl = TextEditingController(text: 'चाय-नाश्ता (Tea/Snacks)');
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('दुकान खर्च जोड़ें / Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'खर्च का प्रकार / Category')),
            const SizedBox(height: 10),
            TextField(controller: amtCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'रुपया / Amount *', prefixText: '₹ ')),
            const SizedBox(height: 10),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'विवरण / Note')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amtCtrl.text) ?? 0.0;
              if (amt <= 0) return;
              final shop = context.read<ShopProvider>().shop;

              await SupabaseService.instance.addExpense(
                Expense(
                  id: const Uuid().v4(),
                  shopId: shop.id,
                  category: catCtrl.text.trim(),
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
            child: const Text('Save Expense'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cashIn = _todaySales
        .where((s) => s.paymentMode == 'cash' || s.paymentMode == 'split')
        .fold(0.0, (sum, s) => sum + s.paid);
    final upiIn = _todaySales
        .where((s) => s.paymentMode == 'online')
        .fold(0.0, (sum, s) => sum + s.paid);
    final cashOut = _todayExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final netDrawer = cashIn - cashOut;

    final dateFormat = DateFormat('hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('दैनिक रोकड़ (Daybook)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF00875A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
            tooltip: 'सेल्स व मुनाफा एनालिटिक्स / Analytics',
            onPressed: () {
              SoundService.instance.playButtonClick();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_card, color: Colors.white),
            tooltip: 'Add Expense',
            onPressed: _showAddExpenseDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDaybook,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00875A)))
          : Column(
              children: [
                const SizedBox(height: 10),
                // Analytics Banner Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: InkWell(
                    onTap: () {
                      SoundService.instance.playButtonClick();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00875A), Color(0xFF045D39)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00875A).withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.insights_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'बिक्री व मुनाफा एनालिटिक्स (Sales & Profit Reports)',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Top/Least बिकने वाले सामान, मार्जिन और ट्रेंड रिपोर्ट देखें',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Top Daybook Cash Tally Card (3D Executive Design)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Title on Left, Calendar Badge on Right (Zero Collision)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF00875A), size: 18),
                              SizedBox(width: 6),
                              Text(
                                'गल्ले में शुद्ध नकद (Net Cash)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00875A).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.event_note_rounded, size: 13, color: Color(0xFF00875A)),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd MMM yyyy').format(DateTime.now()),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00875A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Large Net Drawer Cash Display
                      Text(
                        CurrencyFormatter.format(netDrawer),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                          color: netDrawer >= 0 ? const Color(0xFF00875A) : const Color(0xFFDC2626),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3 Separate 3D Stat Cards: Cash In | UPI In | Cash Out
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00875A).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF00875A).withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.arrow_downward_rounded, size: 12, color: Color(0xFF00875A)),
                                      SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          'नकद आया',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF00875A)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      CurrencyFormatter.format(cashIn),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00875A)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.qr_code_rounded, size: 12, color: Color(0xFF2563EB)),
                                      SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          'ऑनलाइन आया',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      CurrencyFormatter.format(upiIn),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.arrow_upward_rounded, size: 12, color: Color(0xFFDC2626)),
                                      SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          'दुकान खर्च',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      CurrencyFormatter.format(cashOut),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFDC2626)),
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
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'आज के लेनदेन (Today\'s Entries)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_todaySales.length + _todayExpenses.length} लेनदेन',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // Transactions timeline
                Expanded(
                  child: (_todaySales.isEmpty && _todayExpenses.isEmpty)
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.4)),
                              const SizedBox(height: 8),
                              const Text('आज अभी तक कोई लेनदेन नहीं हुआ', style: TextStyle(color: AppColors.lightTextSecondary)),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          children: [
                            ..._todaySales.map((sale) => Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 1.5,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF00875A).withValues(alpha: 0.12),
                                      child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF00875A), size: 20),
                                    ),
                                    title: Text(
                                      'बिल #${sale.billNo} • ${sale.customerName ?? "Walk-in Customer"}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                    ),
                                    subtitle: Row(
                                      children: [
                                        Text(dateFormat.format(sale.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: (sale.paymentMode == 'cash'
                                                    ? const Color(0xFF00875A)
                                                    : const Color(0xFF2563EB))
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            sale.paymentMode.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: sale.paymentMode == 'cash'
                                                  ? const Color(0xFF00875A)
                                                  : const Color(0xFF2563EB),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Text(
                                      '+ ${CurrencyFormatter.format(sale.paid)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00875A), fontSize: 14.5),
                                    ),
                                  ),
                                )),
                            ..._todayExpenses.map((exp) => Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 1.5,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFFDC2626).withValues(alpha: 0.12),
                                      child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFFDC2626), size: 20),
                                    ),
                                    title: Text(exp.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                    subtitle: Text(
                                      '${dateFormat.format(exp.spentOn)}${exp.note != null ? " • ${exp.note}" : ""}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    trailing: Text(
                                      '- ${CurrencyFormatter.format(exp.amount)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontSize: 14.5),
                                    ),
                                  ),
                                )),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
