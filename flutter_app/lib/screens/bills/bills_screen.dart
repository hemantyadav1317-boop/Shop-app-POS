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
    if (_filter == 'credit') {
      return _sales.where((s) => s.due > 0).toList();
    } else if (_filter == 'online') {
      return _sales.where((s) => s.paymentMode == 'online').toList();
    } else if (_filter == 'cash') {
      return _sales.where((s) => s.paymentMode == 'cash').toList();
    }
    return _sales;
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
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sale Invoice Receipt',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
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
                      shopEmail: userEmail ?? 'hemantyadav1317@gmail.com',
                      gstin: shop.gstin,
                      billNo: '${sale.billNo}',
                      dateString: dateFormat.format(sale.createdAt),
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
