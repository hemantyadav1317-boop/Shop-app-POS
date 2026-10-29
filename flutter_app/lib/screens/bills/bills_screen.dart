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
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black87),
                        onPressed: () => Navigator.pop(editCtx),
                      ),
                    ],
                  ),
                  Divider(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'सामान की लिस्ट (Items):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '₹${item.price.toStringAsFixed(2)}/${item.unit}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.remove_circle_outline, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
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
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(
                                          '${item.qty} ${item.unit}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.add_circle_outline, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
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
                                  const SizedBox(width: 8),
                                  Text(
                                    '₹${item.total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF00875A),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
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
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.add_shopping_cart, size: 18),
                              label: const Text('+ सामान जोड़ें (+ Add Product)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF00875A),
                                side: const BorderSide(color: Color(0xFF00875A), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                          Divider(height: 24, color: isDark ? Colors.white12 : Colors.grey.shade300),
                          Text(
                            'Payment Mode:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: mode,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                                  onChanged: (_) {
                                    SoundService.instance.playTypeKey();
                                    setEditState(() {});
                                  },
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
                                  onChanged: (_) {
                                    SoundService.instance.playTypeKey();
                                    setEditState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('कुल राशि (Total):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(CurrencyFormatter.format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF00875A))),
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
                  Divider(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00875A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                                const SnackBar(backgroundColor: Color(0xFF00875A), content: Text('बिल व स्टॉक सफलतापूर्वक अपडेट हो गया!')),
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

  void _showAddItemToExistingBill(BuildContext parentCtx, Function(CartItem) onAdd) {
    final productProv = parentCtx.read<ProductProvider>();
    final allProds = productProv.products;
    String searchQuery = '';
    Product? selectedProduct;
    double selectedQty = 1.0;
    final qtyCtrl = TextEditingController(text: '1');

    showModalBottomSheet(
      context: parentCtx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
          final filtered = allProds.where((p) {
            return searchQuery.isEmpty ||
                p.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                p.category.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();

          return Container(
            height: MediaQuery.of(sheetCtx).size.height * 0.85,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: Color(0xFF00875A)),
                      const SizedBox(width: 8),
                      Text(
                        selectedProduct == null ? 'दुकान के स्टॉक से सामान चुनें' : '${selectedProduct!.name} जोड़ें',
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

                // If no product selected: Search + List
                if (selectedProduct == null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'सामान खोजें (उदा. मिर्च, आलू, चीनी)...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF00875A)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) {
                        setSheetState(() => searchQuery = val.trim());
                      },
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('कोई सामान नहीं मिला', style: TextStyle(color: Colors.grey)))
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
                                  size: 40,
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
                                trailing: Text(
                                  '₹${p.price.toStringAsFixed(2)}/${p.unit}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00875A)),
                                ),
                                onTap: () {
                                  setSheetState(() {
                                    selectedProduct = p;
                                    selectedQty = p.unit.toLowerCase() == 'kg' ? 0.2 : 1.0;
                                    qtyCtrl.text = selectedQty.toString();
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ] else ...[
                  // Product selected: weight buttons & amount calculation
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              ProductImageView(imageUrl: selectedProduct!.imageUrl, fallbackIcon: selectedProduct!.icon, size: 50),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedProduct!.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'दर: ₹${selectedProduct!.price.toStringAsFixed(2)} / ${selectedProduct!.unit}  •  स्टॉक: ${selectedProduct!.stock} ${selectedProduct!.unit}',
                                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => setSheetState(() => selectedProduct = null),
                                child: const Text('बदलें (Change)'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'मात्रा / वज़न चुनें:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // If Kg: Quick weight buttons (100g, 200g, 250g, 500g, 1kg, 2kg)
                          if (selectedProduct!.unit.toLowerCase() == 'kg') ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                {'label': '100 gm', 'val': 0.1},
                                {'label': '200 gm', 'val': 0.2},
                                {'label': '250 gm', 'val': 0.25},
                                {'label': '500 gm', 'val': 0.5},
                                {'label': '1 kg', 'val': 1.0},
                                {'label': '2 kg', 'val': 2.0},
                              ].map((w) {
                                final double v = w['val'] as double;
                                final isSel = (selectedQty - v).abs() < 0.001;
                                return ChoiceChip(
                                  label: Text(w['label'] as String),
                                  selected: isSel,
                                  selectedColor: const Color(0xFF00875A),
                                  labelStyle: TextStyle(
                                    color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  onSelected: (_) {
                                    setSheetState(() {
                                      selectedQty = v;
                                      qtyCtrl.text = v.toString();
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Interactive Qty input
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () {
                                  final step = selectedProduct!.unit.toLowerCase() == 'kg' ? 0.1 : 1.0;
                                  if (selectedQty > step) {
                                    setSheetState(() {
                                      selectedQty = double.parse((selectedQty - step).toStringAsFixed(3));
                                      qtyCtrl.text = selectedQty.toString();
                                    });
                                  }
                                },
                                child: const Icon(Icons.remove),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: qtyCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  decoration: InputDecoration(
                                    suffixText: selectedProduct!.unit,
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (val) {
                                    final parsed = double.tryParse(val);
                                    if (parsed != null && parsed > 0) {
                                      setSheetState(() => selectedQty = parsed);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: () {
                                  final step = selectedProduct!.unit.toLowerCase() == 'kg' ? 0.1 : 1.0;
                                  setSheetState(() {
                                    selectedQty = double.parse((selectedQty + step).toStringAsFixed(3));
                                    qtyCtrl.text = selectedQty.toString();
                                  });
                                },
                                child: const Icon(Icons.add),
                              ),
                            ],
                          ),
                          const Spacer(),

                          // Total amount display
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF00875A).withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('सामान की कुल राशि:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(
                                  '₹${(selectedQty * selectedProduct!.price).toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF00875A)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00875A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(
                              'बिल में जोड़ें • ₹${(selectedQty * selectedProduct!.price).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            onPressed: () {
                              if (selectedQty <= 0) return;
                              onAdd(CartItem(
                                productId: selectedProduct!.id,
                                name: selectedProduct!.name,
                                unit: selectedProduct!.unit,
                                price: selectedProduct!.price,
                                qty: selectedQty,
                                imageUrl: selectedProduct!.imageUrl,
                                icon: selectedProduct!.icon,
                              ));
                              Navigator.pop(sheetCtx);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
