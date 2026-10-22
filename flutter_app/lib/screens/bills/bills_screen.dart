import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/receipt_print_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/sale.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/shop_provider.dart';
import '../../core/services/sound_service.dart';
import '../pos/widgets/bill_receipt_card.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  List<Sale> _sales = [];
  bool _isLoading = true;
  String _filter = 'all'; // 'all', 'credit', 'online', 'cash'

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    final shop = context.read<ShopProvider>().shop;
    final list = await SupabaseService.instance.getSales(shop.id);
    setState(() {
      _sales = list;
      _isLoading = false;
    });
  }

  List<Sale> get _filteredSales {
    final seenIds = <String>{};
    final unique = <Sale>[];
    for (final s in _sales) {
      if (!seenIds.contains(s.id)) {
        seenIds.add(s.id);
        unique.add(s);
      }
    }
    if (_filter == 'credit') {
      return unique.where((s) => s.due > 0).toList();
    } else if (_filter == 'online') {
      return unique.where((s) => s.paymentMode == 'online').toList();
    } else if (_filter == 'cash') {
      return unique.where((s) => s.paymentMode == 'cash').toList();
    }
    return unique;
  }

  void _showBillDetails(Sale sale) {
    final shop = context.read<ShopProvider>().shop;
    final userEmail = SupabaseService.instance.client?.auth.currentUser?.email;
    final dateFormat = DateFormat('dd-MM-yyyy h:mm a');
    final screenshotController = ScreenshotController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Sale Invoice Receipt',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 24),
                      tooltip: 'बिल में बदलाव करें (Edit Bill)',
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showEditBillDialog(sale);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                      tooltip: 'बिल डिलीट करें (Delete Bill)',
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDeleteBill(sale);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Screenshot(
                    controller: screenshotController,
                    child: BillReceiptCard(
                      shopName: shop.name,
                      shopAddress: shop.address,
                      shopPhone: shop.phone,
                      shopEmail: (userEmail != null && userEmail.isNotEmpty) ? userEmail : null,
                      gstin: shop.gstin,
                      billNo: '${sale.billNo}',
                      dateString: dateFormat.format(sale.createdAt),
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
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.grey.shade50,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.reply, color: Color(0xFF2563EB), size: 24),
                              SizedBox(height: 4),
                              Text('Back', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          try {
                            final imageBytes = await screenshotController.capture(pixelRatio: 2.0);
                            await ReceiptPrintService.shareReceipt(sale: sale, shop: shop, imageBytes: imageBytes);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('शेयर एरर: $e')));
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.share, color: Color(0xFF2563EB), size: 24),
                              SizedBox(height: 4),
                              Text('Share Bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          try {
                            final imageBytes = await screenshotController.capture(pixelRatio: 2.0);
                            await ReceiptPrintService.printReceipt(sale: sale, shop: shop, imageBytes: imageBytes);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(backgroundColor: AppColors.error, content: Text('प्रिंट एरर: $e')));
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.print, color: Color(0xFF2563EB), size: 24),
                              SizedBox(height: 4),
                              Text('Print Bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditBillDialog(Sale sale) {
    final items = List.from(sale.items);
    String mode = sale.paymentMode;
    final discountCtrl = TextEditingController(text: sale.discount > 0 ? sale.discount.toStringAsFixed(2) : '0');
    final paidCtrl = TextEditingController(text: sale.paid.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (editCtx) => StatefulBuilder(
        builder: (editCtx, setEditState) {
          double subtotal = 0.0;
          for (final it in items) {
            subtotal += it.total;
          }
          final discount = double.tryParse(discountCtrl.text) ?? 0.0;
          final total = (subtotal - discount) > 0 ? (subtotal - discount) : 0.0;
          final paid = double.tryParse(paidCtrl.text) ?? 0.0;
          final due = (total - paid) > 0 ? (total - paid) : 0.0;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'बिल एडिट करें (Bill #${sale.billNo})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(editCtx),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('सामान की लिस्ट (Items):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          ...items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                                        onPressed: () {
                                          if (item.qty > 1) {
                                            setEditState(() {
                                              final newQty = item.qty - (item.unit.toLowerCase() == 'kg' ? 0.25 : 1);
                                              if (newQty > 0) {
                                                items[idx] = item.copyWith(qty: newQty);
                                              }
                                            });
                                          }
                                        },
                                      ),
                                      Text(
                                        '${item.qty} ${item.unit}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, size: 18),
                                        onPressed: () {
                                          setEditState(() {
                                            final newQty = item.qty + (item.unit.toLowerCase() == 'kg' ? 0.25 : 1);
                                            items[idx] = item.copyWith(qty: newQty);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '₹${item.total.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                    onPressed: () {
                                      setEditState(() {
                                        items.removeAt(idx);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(height: 20),
                          const Text('Payment Mode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: mode,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                            items: const [
                              DropdownMenuItem(value: 'cash', child: Text('नकद (Cash)')),
                              DropdownMenuItem(value: 'online', child: Text('ऑनलाइन (UPI)')),
                              DropdownMenuItem(value: 'credit', child: Text('उधार (Khata / Credit)')),
                              DropdownMenuItem(value: 'split', child: Text('Split')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setEditState(() {
                                  mode = val;
                                  if (val == 'credit') {
                                    paidCtrl.text = '0.00';
                                  } else if (val == 'cash' || val == 'online') {
                                    paidCtrl.text = total.toStringAsFixed(2);
                                  }
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(child: Text('Discount (छूट):', style: TextStyle(fontSize: 12))),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: discountCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(prefixText: '₹ ', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                  onChanged: (_) => setEditState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Expanded(child: Text('प्राप्त राशि (Paid):', style: TextStyle(fontSize: 12))),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: paidCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(prefixText: '₹ ', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                  onChanged: (_) => setEditState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('कुल राशि (Total):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(CurrencyFormatter.format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                            ],
                          ),
                          if (due > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('बकाया (Due / Udhar):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.error)),
                                Text(CurrencyFormatter.format(due), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: items.isEmpty
                        ? null
                        : () async {
                            final updated = sale.copyWith(
                              items: List.from(items),
                              subtotal: subtotal,
                              discount: discount,
                              total: total,
                              paid: paid > total ? total : paid,
                              due: due,
                              paymentMode: mode,
                              paymentStatus: due == 0 ? 'completed' : 'pending',
                            );
                            Navigator.pop(editCtx);
                            await SupabaseService.instance.updateSale(updated);
                            _loadSales();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(backgroundColor: AppColors.primary, content: Text('बिल सफलतापूर्वक अपडेट हो गया!')),
                              );
                            }
                          },
                    child: const Text('बदलाव सेव करें (Save Changes)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteBill(Sale sale) {
    showDialog(
      context: context,
      builder: (delCtx) => AlertDialog(
        title: const Text('बिल डिलीट करें?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('क्या आप वाकई बिल #${sale.billNo} (${CurrencyFormatter.format(sale.total)}) को डिलीट/रद्द करना चाहते हैं?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(delCtx),
            child: const Text('रद्द करें (Cancel)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              SoundService.instance.playDelete();
              Navigator.pop(delCtx);
              await SupabaseService.instance.deleteSale(sale.id);
              _loadSales();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: AppColors.error, content: Text('बिल डिलीट कर दिया गया।')),
                );
              }
            },
            child: const Text('हाँ, डिलीट करें'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('बिल हिस्ट्री / Bills History', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('all', 'All Bills (${_sales.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('cash', 'Cash'),
                const SizedBox(width: 8),
                _buildFilterChip('online', 'UPI Online'),
                const SizedBox(width: 8),
                _buildFilterChip('credit', 'उधार (Credit)'),
              ],
            ),
          ),

          // Sales List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSales.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.lightTextSecondary),
                            SizedBox(height: 8),
                            Text('कोई बिल नहीं मिला (No bills yet)', style: TextStyle(color: AppColors.lightTextSecondary)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredSales.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final sale = _filteredSales[i];

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: sale.due > 0 ? AppColors.error.withOpacity(0.15) : AppColors.primarySurface,
                                child: Icon(
                                  sale.due > 0 ? Icons.book : Icons.receipt,
                                  color: sale.due > 0 ? AppColors.error : AppColors.primary,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text('#${sale.billNo}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sale.customerName ?? 'Walk-in Customer',
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${sale.items.length} items · ${dateFormat.format(sale.createdAt)} · ${sale.paymentMode.toUpperCase()}',
                                style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(sale.total),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  if (sale.due > 0)
                                    Text(
                                      'Due: ${CurrencyFormatter.format(sale.due)}',
                                      style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                              onTap: () => _showBillDetails(sale),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primarySurface,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.lightTextSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() => _filter = key);
      },
    );
  }
}
