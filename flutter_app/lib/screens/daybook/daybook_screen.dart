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
        title: const Text('दैनिक रोकड़ / Daybook', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card),
            tooltip: 'Add Expense',
            onPressed: _showAddExpenseDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDaybook,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Daybook Cash Tally Card
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('गल्ले में शुद्ध नकद / Net Cash in Drawer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            DateFormat('dd MMMM yyyy').format(DateTime.now()),
                            style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyFormatter.format(netDrawer),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                          color: netDrawer >= 0 ? AppColors.primary : AppColors.error,
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn('💵 नकद आया (Cash In)', CurrencyFormatter.format(cashIn), AppColors.primary),
                          _buildStatColumn('📲 ऑनलाइन (UPI In)', CurrencyFormatter.format(upiIn), Colors.blue),
                          _buildStatColumn('💸 खर्च (Cash Out)', CurrencyFormatter.format(cashOut), AppColors.error),
                        ],
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('आज के लेनदेन / Today\'s Entries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),

                // Transactions timeline
                Expanded(
                  child: (_todaySales.isEmpty && _todayExpenses.isEmpty)
                      ? const Center(child: Text('आज अभी तक कोई लेनदेन नहीं हुआ', style: TextStyle(color: AppColors.lightTextSecondary)))
                      : ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            ..._todaySales.map((sale) => Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primarySurface,
                                      child: const Icon(Icons.arrow_downward, color: AppColors.primary, size: 20),
                                    ),
                                    title: Text('Sale Bill #${sale.billNo} (${sale.customerName ?? "Walk-in"})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text('${dateFormat.format(sale.createdAt)} · ${sale.paymentMode.toUpperCase()}', style: const TextStyle(fontSize: 11)),
                                    trailing: Text(
                                      '+ ${CurrencyFormatter.format(sale.paid)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                                    ),
                                  ),
                                )),
                            ..._todayExpenses.map((exp) => Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.error.withOpacity(0.15),
                                      child: const Icon(Icons.arrow_upward, color: AppColors.error, size: 20),
                                    ),
                                    title: Text(exp.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text('${dateFormat.format(exp.spentOn)}${exp.note != null ? " · ${exp.note}" : ""}'),
                                    trailing: Text(
                                      '- ${CurrencyFormatter.format(exp.amount)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 14),
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

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.lightTextSecondary)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ],
    );
  }
}
