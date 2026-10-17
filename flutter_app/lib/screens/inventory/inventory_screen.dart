import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _onlyLowStock = false;

  void _showAddEditProductDialog(BuildContext context, [Product? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? 'VEGETABLES');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toString() : '');
    final purchasePriceCtrl = TextEditingController(text: existing?.purchasePrice?.toString() ?? '');
    final stockCtrl = TextEditingController(text: existing != null ? existing.stock.toString() : '0');
    final lowStockCtrl = TextEditingController(text: existing != null ? existing.lowStockAt.toString() : '5');
    String unit = existing?.unit ?? 'kg';
    String icon = existing?.icon ?? '📦';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'नया सामान जोड़ें / Add Product' : 'सामान एडिट करें / Edit Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        // Quick icon selector
                        showDialog(
                          context: ctx,
                          builder: (emojiDialogCtx) => SimpleDialog(
                            title: const Text('इमोजी चुनें / Select Emoji'),
                            children: ['🍎', '🍌', '🥭', '🍇', '🥔', '🧅', '🍅', '🥬', '🌶️', '🥛', '🧀', '📦', '🍞', '🍚', '🍫']
                                .map((em) => SimpleDialogOption(
                                      onPressed: () {
                                        setDialogState(() => icon = em);
                                        Navigator.pop(emojiDialogCtx);
                                      },
                                      child: Text(em, style: const TextStyle(fontSize: 24)),
                                    ))
                                .toList(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.lightMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.lightBorder),
                        ),
                        child: Text(icon, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'सामान का नाम *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: catCtrl,
                        decoration: const InputDecoration(labelText: 'कैटेगरी / Category'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: unit,
                      items: ['kg', 'pc', 'litre', 'pkt', 'g']
                          .map((u) => DropdownMenuItem(value: u, child: Text(u.toUpperCase())))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => unit = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'बिक्री मूल्य (Sale) *', prefixText: '₹ '),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: purchasePriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'खरीद मूल्य (Cost)', prefixText: '₹ '),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: stockCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'वर्तमान स्टॉक ($unit)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lowStockCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Low Alert ($unit)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text) ?? 0.0;
                if (name.isEmpty || price <= 0) return;

                final shop = context.read<ShopProvider>().shop;
                final prod = Product(
                  id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  shopId: shop.id,
                  name: name,
                  category: catCtrl.text.trim().isEmpty ? 'General' : catCtrl.text.trim().toUpperCase(),
                  unit: unit,
                  price: price,
                  purchasePrice: double.tryParse(purchasePriceCtrl.text),
                  stock: double.tryParse(stockCtrl.text) ?? 0.0,
                  lowStockAt: double.tryParse(lowStockCtrl.text) ?? 5.0,
                  icon: icon,
                );

                final provider = context.read<ProductProvider>();
                if (existing == null) {
                  await provider.addProduct(prod);
                } else {
                  await provider.updateProduct(prod);
                }
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Product'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStockAdjustmentDialog(BuildContext context, Product product) {
    final qtyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${product.name} - स्टॉक अपडेट'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('वर्तमान स्टॉक: ${product.stock} ${product.unit}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'नया स्टॉक दर्ज करें (${product.unit})',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newStock = double.tryParse(qtyCtrl.text);
              if (newStock == null) return;
              final updated = product.copyWith(stock: newStock);
              await context.read<ProductProvider>().updateProduct(updated);
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Update Stock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final products = _onlyLowStock
        ? productProvider.products.where((p) => p.isLowStock).toList()
        : productProvider.filteredProducts;

    final lowStockCount = productProvider.products.where((p) => p.isLowStock).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('स्टॉक / Inventory', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Add Product',
            onPressed: () => _showAddEditProductDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Low stock alert filter toggle banner
          if (lowStockCount > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _onlyLowStock ? AppColors.error : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: _onlyLowStock ? Colors.white : AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'सावधान: $lowStockCount आइटम का स्टॉक कम है!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _onlyLowStock ? Colors.white : AppColors.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _onlyLowStock = !_onlyLowStock);
                    },
                    child: Text(
                      _onlyLowStock ? 'Show All' : 'Filter Low',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _onlyLowStock ? Colors.white : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'सामान का नाम या बारकोड खोजें...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (q) => productProvider.setSearchQuery(q),
            ),
          ),
          const SizedBox(height: 6),

          // Product List
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('कोई प्रोडक्ट नहीं मिला', style: TextStyle(color: AppColors.lightTextSecondary)))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final product = products[i];

                      return Card(
                        child: ListTile(
                          leading: Text(product.icon ?? '📦', style: const TextStyle(fontSize: 26)),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              if (product.isLowStock)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('LOW STOCK', style: TextStyle(color: AppColors.error, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            'दर: ${CurrencyFormatter.format(product.price)} / ${product.unit} · Cat: ${product.category}',
                            style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${product.stock} ${product.unit}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: product.isLowStock ? AppColors.error : AppColors.primary,
                                    ),
                                  ),
                                  const Text('स्टॉक', style: TextStyle(fontSize: 10, color: AppColors.lightTextSecondary)),
                                ],
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.edit_note, size: 22),
                                tooltip: 'Adjust Stock',
                                onPressed: () => _showStockAdjustmentDialog(context, product),
                              ),
                            ],
                          ),
                          onTap: () => _showAddEditProductDialog(context, product),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
