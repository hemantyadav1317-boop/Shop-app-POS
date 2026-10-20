import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';
import 'package:shop_pos/screens/widgets/product_image_view.dart';
import 'widgets/bulk_import_dialog.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _onlyLowStock = false;

  void _showAddCategoryDialog(BuildContext context, [Function(String)? onCreated]) {
    final catNameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.category, color: AppColors.primary),
            SizedBox(width: 8),
            Text('नई कैटेगरी जोड़ें / Add Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'जैसे: FRUITS, VEGETABLES, DAIRY, SNACKS, SWEETS आदि',
              style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: catNameCtrl,
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'कैटेगरी का नाम *',
                hintText: 'उदा. COLD DRINKS',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final cat = catNameCtrl.text.trim().toUpperCase();
              if (cat.isEmpty) return;
              await context.read<ProductProvider>().addCategory(cat);
              if (context.mounted) {
                Navigator.pop(ctx);
                onCreated?.call(cat);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.primary,
                    content: Text('कैटेगरी "$cat" सफलतापूर्वक जोड़ी गई'),
                  ),
                );
              }
            },
            child: const Text('सेव करें (Save)'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context, String catName) {
    final count = context.read<ProductProvider>().getProductCountForCategory(catName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Expanded(
              child: Text('कैटेगरी हटाएं / Delete Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('क्या आप "$catName" कैटेगरी को हटाना चाहते हैं?'),
            if (count > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Text(
                  'इस कैटेगरी में $count सामान हैं। ये सभी सामान स्वतः "GENERAL" कैटेगरी में चले जाएंगे।',
                  style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await context.read<ProductProvider>().deleteCategory(catName);
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.error,
                    content: Text('कैटेगरी "$catName" हटा दी गई'),
                  ),
                );
              }
            },
            child: const Text('हटाएं (Delete)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.delete_outline, color: AppColors.error),
            SizedBox(width: 8),
            Expanded(
              child: Text('सामान हटाएं / Delete Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Text('क्या आप "${product.name}" को स्टॉक सूची से हटाना चाहते हैं?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await context.read<ProductProvider>().deleteProduct(product.id);
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.error,
                    content: Text('${product.name} को स्टॉक से हटा दिया गया'),
                  ),
                );
              }
            },
            child: const Text('हटाएं (Delete)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddEditProductDialog(BuildContext context, [Product? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toString() : '');
    final purchasePriceCtrl = TextEditingController(text: existing?.purchasePrice?.toString() ?? '');
    final stockCtrl = TextEditingController(text: existing != null ? existing.stock.toString() : '0');
    final lowStockCtrl = TextEditingController(text: existing != null ? existing.lowStockAt.toString() : '5');
    String unit = existing?.unit ?? 'kg';
    String icon = existing?.icon ?? '📦';
    String? imageUrl = existing?.imageUrl;
    final picker = ImagePicker();

    final productProvider = context.read<ProductProvider>();
    List<String> availableCats = List.from(productProvider.allCategories);
    String selectedCategory = existing != null ? existing.category.toUpperCase() : (availableCats.isNotEmpty ? availableCats.first : 'GENERAL');
    if (!availableCats.contains(selectedCategory)) {
      availableCats.insert(0, selectedCategory);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            existing == null ? 'नया सामान जोड़ें / Add Product' : 'सामान एडिट करें / Edit Product',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Product Photo & Icon Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ProductImageView(
                        imageUrl: imageUrl,
                        fallbackIcon: icon,
                        size: 64,
                        borderRadius: 12,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              imageUrl != null && imageUrl!.isNotEmpty
                                  ? 'फोटो जोड़ी गई है'
                                  : 'कोई फोटो नहीं (इमोजी सेट है)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'फोटो लगाने के लिए विकल्प:',
                              style: TextStyle(fontSize: 10, color: AppColors.lightTextSecondary),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.camera_alt, size: 13),
                                  label: const Text('कैमरा', style: TextStyle(fontSize: 11)),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () async {
                                    try {
                                      final img = await picker.pickImage(
                                        source: ImageSource.camera,
                                        maxWidth: 800,
                                        maxHeight: 800,
                                        imageQuality: 85,
                                      );
                                      if (img != null) {
                                        setDialogState(() => imageUrl = img.path);
                                      }
                                    } catch (e) {
                                      debugPrint("Camera error: $e");
                                    }
                                  },
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.photo_library, size: 13),
                                  label: const Text('गैलरी', style: TextStyle(fontSize: 11)),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () async {
                                    try {
                                      final img = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 800,
                                        maxHeight: 800,
                                        imageQuality: 85,
                                      );
                                      if (img != null) {
                                        setDialogState(() => imageUrl = img.path);
                                      }
                                    } catch (e) {
                                      debugPrint("Gallery error: $e");
                                    }
                                  },
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.link, size: 13),
                                  label: const Text('URL', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    final urlCtrl = TextEditingController(text: imageUrl?.startsWith('http') == true ? imageUrl : '');
                                    showDialog(
                                      context: ctx,
                                      builder: (urlCtx) => AlertDialog(
                                        title: const Text('इमेज URL लिंक दर्ज करें', style: TextStyle(fontSize: 14)),
                                        content: TextField(
                                          controller: urlCtrl,
                                          decoration: const InputDecoration(
                                            hintText: 'https://example.com/item.jpg',
                                            prefixIcon: Icon(Icons.link),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(urlCtx), child: const Text('Cancel')),
                                          ElevatedButton(
                                            onPressed: () {
                                              final val = urlCtrl.text.trim();
                                              if (val.isNotEmpty) {
                                                setDialogState(() => imageUrl = val);
                                              }
                                              Navigator.pop(urlCtx);
                                            },
                                            child: const Text('Set URL'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.emoji_emotions, size: 13),
                                  label: const Text('इमोजी', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: ctx,
                                      builder: (emojiDialogCtx) => SimpleDialog(
                                        title: const Text('इमोजी चुनें / Select Emoji'),
                                        children: ['🍎', '🍌', '🥭', '🍇', '🥔', '🧅', '🍅', '🥬', '🌶️', '🥛', '🧀', '📦', '🍞', '🍚', '🍫', '🧴', '🧼', '☕', '🥤', '🍪']
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
                                ),
                                if (imageUrl != null && imageUrl!.isNotEmpty)
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete_outline, size: 13, color: AppColors.error),
                                    label: const Text('हटाएं', style: TextStyle(fontSize: 11, color: AppColors.error)),
                                    onPressed: () => setDialogState(() => imageUrl = null),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'सामान का नाम *'),
                ),
                const SizedBox(height: 10),

                // Category Dropdown with "+ Add New"
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'कैटेगरी (Category) *',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        isExpanded: true,
                        items: [
                          ...availableCats.map((cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat, overflow: TextOverflow.ellipsis),
                              )),
                          const DropdownMenuItem(
                            value: '__ADD_NEW__',
                            child: Row(
                              children: [
                                Icon(Icons.add_circle_outline, size: 16, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text('+ नई कैटेगरी बनाएं', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == '__ADD_NEW__') {
                            _showAddCategoryDialog(context, (newCat) {
                              setDialogState(() {
                                if (!availableCats.contains(newCat)) {
                                  availableCats.add(newCat);
                                }
                                selectedCategory = newCat;
                              });
                            });
                          } else if (val != null) {
                            setDialogState(() => selectedCategory = val);
                          }
                        },
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
            if (existing != null)
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 16),
                label: const Text('हटाएं', style: TextStyle(color: AppColors.error)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _confirmDeleteProduct(context, existing);
                },
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text) ?? 0.0;
                if (name.isEmpty || price <= 0) return;

                final shop = context.read<ShopProvider>().shop;
                final existingId = existing?.id;
                final hasValidUuid = existingId != null &&
                    RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
                        .hasMatch(existingId);
                final prod = Product(
                  id: hasValidUuid ? existingId : const Uuid().v4(),
                  shopId: shop.id,
                  name: name,
                  category: selectedCategory.trim().toUpperCase(),
                  unit: unit,
                  price: price,
                  purchasePrice: double.tryParse(purchasePriceCtrl.text),
                  stock: double.tryParse(stockCtrl.text) ?? 0.0,
                  lowStockAt: double.tryParse(lowStockCtrl.text) ?? 5.0,
                  imageUrl: imageUrl,
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
    final allCats = productProvider.allCategories;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('स्टॉक व कैटेगरी / Inventory', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            tabs: [
              Tab(
                icon: Icon(Icons.inventory_2_outlined),
                text: 'सामान स्टॉक (Products)',
              ),
              Tab(
                icon: Icon(Icons.category_outlined),
                text: 'कैटेगरी प्रबंधन (Categories)',
              ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('बल्क जोड़ें', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const BulkImportDialog(),
                );
              },
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
              tooltip: 'Add Product',
              onPressed: () => _showAddEditProductDialog(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: TabBarView(
          children: [
            // TAB 1: PRODUCTS INVENTORY
            Column(
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                      label: const Text('📥 Excel / CSV / बिल से 50-100+ सामान एक साथ चढ़ाएं (बल्क अपलोड)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const BulkImportDialog(),
                        );
                      },
                    ),
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
                                leading: ProductImageView(
                                  imageUrl: product.imageUrl,
                                  fallbackIcon: product.icon,
                                  size: 46,
                                  borderRadius: 8,
                                ),
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
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.edit_note, size: 22),
                                      tooltip: 'Adjust Stock',
                                      onPressed: () => _showStockAdjustmentDialog(context, product),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.lightTextSecondary),
                                      padding: EdgeInsets.zero,
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _showAddEditProductDialog(context, product);
                                        } else if (val == 'delete') {
                                          _confirmDeleteProduct(context, product);
                                        }
                                      },
                                      itemBuilder: (ctx) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 16),
                                              SizedBox(width: 8),
                                              Text('एडिट करें'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                              SizedBox(width: 8),
                                              Text('हटाएं (Delete)', style: TextStyle(color: AppColors.error)),
                                            ],
                                          ),
                                        ),
                                      ],
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

            // TAB 2: CATEGORIES MANAGEMENT
            Column(
              children: [
                // Top header card with "+ Add Category" button
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'कुल उपलब्ध कैटेगरी',
                            style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${allCats.length} कैटेगरी',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryDark),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('नई कैटेगरी जोड़ें', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _showAddCategoryDialog(context),
                      ),
                    ],
                  ),
                ),

                // Category List
                Expanded(
                  child: allCats.isEmpty
                      ? const Center(child: Text('कोई कैटेगरी नहीं है'))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          itemCount: allCats.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final cat = allCats[i];
                            final count = productProvider.getProductCountForCategory(cat);

                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primarySurface,
                                  child: Text(
                                    cat.isNotEmpty ? cat.substring(0, 1) : '?',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                                title: Text(
                                  cat,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: Text(
                                  '$count सामान (Products)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: count > 0 ? AppColors.primary : AppColors.lightTextSecondary,
                                    fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                  tooltip: 'Delete Category',
                                  onPressed: () => _confirmDeleteCategory(context, cat),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
