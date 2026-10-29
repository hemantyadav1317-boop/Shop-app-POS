import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/receipt_print_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/sale.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/product.dart';
import '../../providers/product_provider.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/shop_provider.dart';
import '../../core/services/sound_service.dart';
import '../pos/widgets/bill_receipt_card.dart';
import '../pos/widgets/qty_rate_dialog.dart';
import '../widgets/product_image_view.dart';
import '../../core/services/ai_quote_service.dart';

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
                      quoteLine1: AiQuoteService.getQuoteForBillNo(sale.billNo).line1,
                      quoteLine2: AiQuoteService.getQuoteForBillNo(sale.billNo).line2,
                      upiId: shop.upiId,
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
          final isDark = Theme.of(editCtx).brightness == Brightness.dark;
          final media = MediaQuery.of(editCtx);
          final isTablet = media.size.width >= 600;
          final dialogWidth = isTablet ? 560.0 : media.size.width * 0.95;
          final dialogHeight = isTablet ? 780.0 : media.size.height * 0.90;

          double subtotal = 0.0;
          for (final it in items) {
            subtotal += it.total;
          }
          final discount = double.tryParse(discountCtrl.text) ?? 0.0;
          final total = (subtotal - discount) > 0 ? (subtotal - discount) : 0.0;
          final paid = double.tryParse(paidCtrl.text) ?? 0.0;
          final due = (total - paid) > 0 ? (total - paid) : 0.0;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            child: Container(
              width: dialogWidth,
              height: dialogHeight,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, color: Color(0xFF00875A), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'बिल एडिट करें (Bill #${sale.billNo})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black87),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(editCtx),
                      ),
                    ],
                  ),
                  Divider(color: isDark ? Colors.white12 : Colors.grey.shade300),

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'सामान की लिस्ट (Items):',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              Text(
                                '${items.length} सामान',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Items List
                          if (items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'बिल में कोई सामान नहीं है। कृपया नीचे से सामान जोड़ें।',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                ),
                              ),
                            )
                          else
                            ...items.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final item = entry.value;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Product Name, Unit Rate, and Delete Button
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '₹${item.price.toStringAsFixed(2)} / ${item.unit}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: 'हटाएं (Remove)',
                                          onPressed: () {
                                            setEditState(() {
                                              items.removeAt(idx);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Row 2: Qty Counter (with direct touch keypad edit) & Line Total
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Counter
                                        Container(
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isDark ? Colors.white24 : Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(Icons.remove, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 36, minHeight: 34),
                                                onPressed: () {
                                                  if (item.qty > 0.05) {
                                                    setEditState(() {
                                                      final step = item.unit.toLowerCase() == 'kg' ? 0.25 : 1.0;
                                                      final newQty = item.qty - step;
                                                      if (newQty > 0) {
                                                        items[idx] = item.copyWith(qty: double.parse(newQty.toStringAsFixed(3)));
                                                      }
                                                    });
                                                  }
                                                },
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  // Open QtyRateDialog with touch keypad for this item
                                                  final productProv = editCtx.read<ProductProvider>();
                                                  Product? prod;
                                                  try {
                                                    prod = productProv.products.firstWhere(
                                                      (p) => p.id == item.productId || p.name.toLowerCase() == item.name.toLowerCase(),
                                                    );
                                                  } catch (_) {
                                                    prod = Product(
                                                      id: item.productId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
                                                      shopId: sale.shopId,
                                                      name: item.name,
                                                      price: item.price,
                                                      unit: item.unit,
                                                      stock: 999,
                                                      category: 'GENERAL',
                                                      imageUrl: item.imageUrl,
                                                    );
                                                  }
                                                  showDialog(
                                                    context: editCtx,
                                                    builder: (_) => QtyRateDialog(
                                                      product: prod!,
                                                      initialQty: item.qty,
                                                      onConfirm: (updated) {
                                                        setEditState(() {
                                                          items[idx] = updated;
                                                        });
                                                      },
                                                    ),
                                                  );
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        '${item.qty} ${item.unit}',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 13,
                                                          color: isDark ? Colors.white : Colors.black87,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Icon(Icons.edit_note_rounded, size: 16, color: isDark ? Colors.white54 : Colors.black45),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.add, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 36, minHeight: 34),
                                                onPressed: () {
                                                  setEditState(() {
                                                    final step = item.unit.toLowerCase() == 'kg' ? 0.25 : 1.0;
                                                    final newQty = item.qty + step;
                                                    items[idx] = item.copyWith(qty: double.parse(newQty.toStringAsFixed(3)));
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Total Price for this item
                                        Text(
                                          '₹${item.total.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Color(0xFF00875A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),

                          const SizedBox(height: 8),

                          // Add Product Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                              label: const Text('+ सामान जोड़ें (+ Add Product)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF00875A),
                                side: const BorderSide(color: Color(0xFF00875A), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                _showAddItemToExistingBill(editCtx, (newItem) {
                                  setEditState(() {
                                    items.add(newItem);
                                  });
                                });
                              },
                            ),
                          ),

                          Divider(height: 28, color: isDark ? Colors.white12 : Colors.grey.shade300),

                          // Payment Mode
                          Text(
                            'Payment Mode (भुगतान का प्रकार):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: mode,
                            isExpanded: true,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
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
                          const SizedBox(height: 14),

                          // Discount and Paid Rows
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Discount (छूट):',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                child: TextField(
                                  controller: discountCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    prefixText: '₹ ',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (_) {
                                    SoundService.instance.playTypeKey();
                                    setEditState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'प्राप्त राशि (Paid):',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                child: TextField(
                                  controller: paidCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    prefixText: '₹ ',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (_) {
                                    SoundService.instance.playTypeKey();
                                    setEditState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Total and Due Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF00875A).withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('कुल राशि (Total):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(
                                      CurrencyFormatter.format(total),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF00875A)),
                                    ),
                                  ],
                                ),
                                if (due > 0) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('बकाया (Due / Udhar):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.error)),
                                      Text(
                                        CurrencyFormatter.format(due),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Sticky Save Changes Button at Dialog Bottom
                  Divider(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00875A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      onPressed: items.isEmpty
                          ? null
                          : () async {
                              // Deduct stock for any new items or increased quantities
                              final productProv = context.read<ProductProvider>();
                              for (final item in items) {
                                if (item.productId != null) {
                                  final origIdx = sale.items.indexWhere((o) => o.productId == item.productId);
                                  final origQty = origIdx != -1 ? sale.items[origIdx].qty : 0.0;
                                  final diff = item.qty - origQty;
                                  if (diff != 0) {
                                    final prodIdx = productProv.products.indexWhere((p) => p.id == item.productId);
                                    if (prodIdx != -1) {
                                      final currentProd = productProv.products[prodIdx];
                                      final newStock = currentProd.stock - diff;
                                      await productProv.updateProduct(currentProd.copyWith(stock: newStock > 0 ? newStock : 0.0));
                                    }
                                  }
                                }
                              }

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
                              SoundService.instance.playSuccess();
                              _loadSales();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Color(0xFF00875A),
                                    content: Text('बिल व स्टॉक सफलतापूर्वक अपडेट हो गया!'),
                                  ),
                                );
                              }
                            },
                      label: const Text('बदलाव सेव करें (Save Changes)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

  void _showAddItemToExistingBill(BuildContext parentCtx, Function(CartItem) onAdd) {
    final productProv = parentCtx.read<ProductProvider>();
    final allProds = productProv.products;
    String searchQuery = '';

    showModalBottomSheet(
      context: parentCtx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
          final media = MediaQuery.of(sheetCtx);
          final filtered = allProds.where((p) {
            return searchQuery.isEmpty ||
                p.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                p.category.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();

          return Container(
            height: media.size.height * 0.75,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Top drag handle
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: Color(0xFF00875A)),
                      const SizedBox(width: 8),
                      Text(
                        'दुकान के स्टॉक से सामान चुनें',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black87),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade300),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'सामान खोजें (उदा. मिर्च, आलू, चीनी)...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF00875A)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) {
                      setSheetState(() => searchQuery = val.trim());
                    },
                  ),
                ),

                // Product List
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'कोई सामान नहीं मिला',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (ctx, i) {
                            final p = filtered[i];
                            return ListTile(
                              tileColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
                              ),
                              leading: ProductImageView(
                                imageUrl: p.imageUrl,
                                fallbackIcon: p.icon,
                                size: 42,
                              ),
                              title: Text(
                                p.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              subtitle: Text(
                                'स्टॉक: ${p.stock} ${p.unit} • Cat: ${p.category}',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade600),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹${p.price.toStringAsFixed(2)}/${p.unit}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00875A)),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.add_circle, color: Color(0xFF00875A), size: 26),
                                ],
                              ),
                              onTap: () {
                                // Close the product selector
                                Navigator.pop(sheetCtx);
                                // Open QtyRateDialog (Home Screen interface with PosNumpad touch pad!)
                                showDialog(
                                  context: parentCtx,
                                  builder: (_) => QtyRateDialog(
                                    product: p,
                                    initialQty: 1.0,
                                    onConfirm: (cartItem) {
                                      onAdd(cartItem);
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
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
                : RefreshIndicator(
                    onRefresh: _loadSales,
                    child: _filteredSales.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.lightTextSecondary),
                                    SizedBox(height: 8),
                                    Text('कोई बिल नहीं मिला (No bills yet)', style: TextStyle(color: AppColors.lightTextSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
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
                                '${sale.items.length} items · ${dateFormat.format(sale.createdAt.toLocal())} · ${sale.paymentMode.toUpperCase()}',
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
