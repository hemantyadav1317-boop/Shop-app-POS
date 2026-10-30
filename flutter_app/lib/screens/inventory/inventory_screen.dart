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
import '../../core/utils/pos_sound_formatter.dart';
import '../../core/services/sound_service.dart';
import 'widgets/bulk_import_dialog.dart';
import 'package:intl/intl.dart';
import '../../data/models/stock_adjustment.dart';
import '../../data/services/stock_adjustment_service.dart';
import '../../data/services/supabase_service.dart';
import '../../data/models/fmcg_item.dart';
import '../../core/services/fmcg_catalog_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _onlyLowStock = false;

  void _showAddCategoryDialog(BuildContext context, [Function(String)? onCreated, String? existingCat]) {
    final catNameCtrl = TextEditingController(text: existingCat ?? '');
    final catImgCtrl = TextEditingController();
    String? selectedImageUrl = existingCat != null
        ? context.read<ProductProvider>().getCategoryImage(existingCat)
        : null;
    if (selectedImageUrl != null) {
      catImgCtrl.text = selectedImageUrl;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.category, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  existingCat != null
                      ? 'कैटेगरी फोटो बदलें / Edit Category'
                      : 'नई कैटेगरी जोड़ें / Add Category',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (existingCat == null) ...[
                  const Text(
                    'जैसे: किराना, फल, सब्जियां, स्नैक्स, डेयरी, कोल्ड ड्रिंक्स आदि',
                    style: TextStyle(fontSize: 11.5, color: AppColors.lightTextSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: catNameCtrl,
                    textCapitalization: TextCapitalization.characters,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'कैटेगरी का नाम *',
                      hintText: 'उदा. किराना (GROCERY)',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'कैटेगरी: $existingCat',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करें (Cancel)')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final cat = catNameCtrl.text.trim().toUpperCase();
                if (cat.isEmpty) return;
                final provider = context.read<ProductProvider>();
                if (existingCat == null) {
                  await provider.addCategory(cat);
                }
                SoundService.instance.playSuccess();
                if (context.mounted) {
                  Navigator.pop(ctx);
                  onCreated?.call(cat);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.primary,
                      content: Text('कैटेगरी "$cat" सफलतापूर्वक सुरक्षित हो गई'),
                    ),
                  );
                }
              },
              child: const Text('सेव करें (Save)'),
            ),
          ],
        ),
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
                  'इस कैटेगरी में $count सामान हैं। ये सभी सामान दुकान और डेटाबेस से पूरी तरह डिलीट हो जाएंगे।',
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
              SoundService.instance.playDelete();
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
              SoundService.instance.playDelete();
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
    final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
    final mrpCtrl = TextEditingController(text: existing?.mrp != null ? existing!.mrp.toString() : '');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toString() : '');
    final purchasePriceCtrl = TextEditingController(text: existing?.purchasePrice?.toString() ?? '');
    final stockCtrl = TextEditingController(text: existing != null ? existing.stock.toString() : '0');
    final lowStockCtrl = TextEditingController(text: existing != null ? existing.lowStockAt.toString() : '5');
    String unit = existing?.unit ?? 'kg';
    String icon = existing?.icon ?? '📦';
    String? imageUrl = existing?.imageUrl;
    final picker = ImagePicker();

    List<FmcgItem> fmcgSuggestions = [];

    final productProvider = context.read<ProductProvider>();
    List<String> availableCats = List.from(productProvider.allCategories);
    String selectedCategory = existing != null ? existing.category.toUpperCase() : (availableCats.isNotEmpty ? availableCats.first : 'GENERAL');
    if (!availableCats.contains(selectedCategory)) {
      availableCats.insert(0, selectedCategory);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          void updateFmcgSuggestions(String query) {
            final q = query.trim();
            if (q.length >= 2) {
              setDialogState(() {
                fmcgSuggestions = FmcgCatalogService.instance.search(q, limit: 5);
              });
            } else {
              setDialogState(() {
                fmcgSuggestions = [];
              });
            }
          }

          void applyFmcgItem(FmcgItem item) {
            nameCtrl.text = item.name;
            barcodeCtrl.text = item.barcode;
            mrpCtrl.text = item.mrp.toStringAsFixed(item.mrp % 1 == 0 ? 0 : 2);
            priceCtrl.text = item.mrp.toStringAsFixed(item.mrp % 1 == 0 ? 0 : 2);
            purchasePriceCtrl.text = item.defaultCostPrice.toStringAsFixed(item.defaultCostPrice % 1 == 0 ? 0 : 2);
            unit = item.unit;
            icon = item.icon;
            final catUpper = item.category.toUpperCase();
            if (!availableCats.contains(catUpper)) {
              availableCats.insert(0, catUpper);
            }
            selectedCategory = catUpper;
            fmcgSuggestions = [];
            SoundService.instance.playSuccess();
            setDialogState(() {});
          }

          final saleVal = double.tryParse(priceCtrl.text) ?? 0.0;
          final costVal = double.tryParse(purchasePriceCtrl.text) ?? 0.0;
          final double marginVal = (saleVal > 0 && costVal > 0) ? (saleVal - costVal) : 0.0;
          final double marginPct = (saleVal > 0 && costVal > 0) ? ((marginVal / saleVal) * 100) : 0.0;

          return AlertDialog(
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
                                          maxWidth: 600,
                                          maxHeight: 600,
                                          imageQuality: 80,
                                        );
                                        if (img != null) {
                                          final bytes = await img.readAsBytes();
                                          final shop = context.read<ShopProvider>().shop;
                                          final uploadedUrl = await SupabaseService.instance.uploadImageBytes(
                                            shopId: shop.id,
                                            folder: 'products',
                                            fileName: '${DateTime.now().millisecondsSinceEpoch}.jpg',
                                            bytes: bytes,
                                          );
                                          setDialogState(() => imageUrl = uploadedUrl);
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
                                          maxWidth: 600,
                                          maxHeight: 600,
                                          imageQuality: 80,
                                        );
                                        if (img != null) {
                                          final bytes = await img.readAsBytes();
                                          final shop = context.read<ShopProvider>().shop;
                                          final uploadedUrl = await SupabaseService.instance.uploadImageBytes(
                                            shopId: shop.id,
                                            folder: 'products',
                                            fileName: '${DateTime.now().millisecondsSinceEpoch}.jpg',
                                            bytes: bytes,
                                          );
                                          setDialogState(() => imageUrl = uploadedUrl);
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
                                          children: ['🍎', '🍌', '🥭', '🍇', '🥔', '🧅', '🍅', '🥬', '🌶️', '🥛', '🧀', '📦', '🍞', '🍚', '🍫', '🧴', '🧼', '☕', '🥤', '🍪', '🍜', '🧂', '🧈', '🍿']
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

                  // 🏷️ Barcode Field (with Gun Auto-lookup)
                  TextField(
                    controller: barcodeCtrl,
                    decoration: InputDecoration(
                      labelText: 'बारकोड (Barcode EAN-13 / UPC)',
                      hintText: 'उदा. 8901058852448 या गन से स्कैन करें',
                      prefixIcon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2563EB)),
                      suffixIcon: barcodeCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                barcodeCtrl.clear();
                                updateFmcgSuggestions('');
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      final item = FmcgCatalogService.instance.findByBarcode(val);
                      if (item != null) {
                        applyFmcgItem(item);
                      } else {
                        updateFmcgSuggestions(val);
                      }
                    },
                    onSubmitted: (val) {
                      final item = FmcgCatalogService.instance.findByBarcode(val);
                      if (item != null) {
                        applyFmcgItem(item);
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  // 📦 Product Name Field with Auto-Suggest
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'सामान का नाम *',
                      hintText: 'उदा. Maggi 70g, Tata Salt, Parle-G, आलू',
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                    ),
                    onChanged: (val) {
                      updateFmcgSuggestions(val);
                    },
                  ),

                  // ⚡ FMCG Preloaded Suggestions Box
                  if (fmcgSuggestions.isNotEmpty && existing == null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF00875A).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF00875A)),
                              SizedBox(width: 4),
                              Text(
                                'किराना कैटलॉग से त्वरित ऑटो-फिल (1-Tap Fill):',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00875A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...fmcgSuggestions.map((item) {
                            return InkWell(
                              onTap: () => applyFmcgItem(item),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 5),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Text(item.icon, style: const TextStyle(fontSize: 18)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${item.brand} • ${item.packSize} • Barcode: ${item.barcode}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${item.mrp.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            color: Color(0xFF00875A),
                                          ),
                                        ),
                                        Text(
                                          'MRP (2026)',
                                          style: TextStyle(fontSize: 8.5, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

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
                        items: ['kg', 'pc', 'pkt', 'litre', 'bottle', 'g']
                            .map((u) => DropdownMenuItem(value: u, child: Text(u.toUpperCase())))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => unit = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 💰 Price Inputs: MRP, Selling Price, Cost Price
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: mrpCtrl,
                          inputFormatters: [PosNumberSoundFormatter()],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'MRP (₹)', prefixText: '₹ '),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          inputFormatters: [PosNumberSoundFormatter()],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'बिक्री दर (Sale) *', prefixText: '₹ '),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: purchasePriceCtrl,
                          inputFormatters: [PosNumberSoundFormatter()],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'खरीद (Cost)', prefixText: '₹ '),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                    ],
                  ),

                  // 📊 Real-time Margin & Profit Pill
                  if (saleVal > 0 && costVal > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: marginVal >= 0
                            ? const Color(0xFF00875A).withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                marginVal >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                size: 16,
                                color: marginVal >= 0 ? const Color(0xFF00875A) : Colors.red,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                marginVal >= 0 ? 'मुनाफा (Margin):' : 'नुकसान (Loss):',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: marginVal >= 0 ? const Color(0xFF00875A) : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '₹${marginVal.toStringAsFixed(1)} / $unit (${marginPct.toStringAsFixed(1)}%)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: marginVal >= 0 ? const Color(0xFF00875A) : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stockCtrl,
                          inputFormatters: [PosNumberSoundFormatter()],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: 'वर्तमान स्टॉक ($unit)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: lowStockCtrl,
                          inputFormatters: [PosNumberSoundFormatter()],
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
                    mrp: double.tryParse(mrpCtrl.text),
                    barcode: barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
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
                  SoundService.instance.playSuccess();
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Product'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showStockAdjustmentDialog(BuildContext context, Product product) {
    final qtyCtrl = TextEditingController(text: product.stock.toString());
    final reasonCtrl = TextEditingController();
    String selectedType = 'audit';
    double changeDelta = 0.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'स्टॉक एडजस्टमेंट (Stock Adjustment)',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black87),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Current Stock
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : AppColors.primarySurface.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white12 : AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'वर्तमान स्टॉक (Current):',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${product.stock} ${product.unit}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Adjustment Reason Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      decoration: InputDecoration(
                        labelText: 'एडजस्टमेंट का कारण (Reason) *',
                        prefixIcon: const Icon(Icons.assignment_turned_in_outlined, color: AppColors.primary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'audit', child: Text('भौतिक ऑडिट / गणना (Audit)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'damage', child: Text('टूटा / डैमेज माल (Damage)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'waste', child: Text('खराब / एक्सपायर (Wastage)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'restock', child: Text('नया स्टॉक आया (Restock)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'correction', child: Text('मैन्युअल सुधार (Correction)', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // New Stock Qty Field
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [PosNumberSoundFormatter()],
                      decoration: InputDecoration(
                        labelText: 'नया वास्तविक स्टॉक (${product.unit}) *',
                        hintText: 'उदा. 12',
                        suffixText: product.unit,
                        prefixIcon: const Icon(Icons.pin_outlined, color: AppColors.primary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) {
                        final entered = double.tryParse(val) ?? product.stock;
                        setDialogState(() {
                          changeDelta = entered - product.stock;
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    // Live Delta indicator
                    if (changeDelta != 0.0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: changeDelta > 0 ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: changeDelta > 0 ? Colors.green.shade300 : Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              changeDelta > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 16,
                              color: changeDelta > 0 ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                changeDelta > 0
                                    ? 'स्टॉक में बढ़ोत्तरी: +$changeDelta ${product.unit}'
                                    : 'स्टॉक में कमी: $changeDelta ${product.unit}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: changeDelta > 0 ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'विवरण / टिप्पणी (Optional Note)',
                        hintText: 'उदा. कार्टन फटने या ऑडिट में अंतर मिला',
                        prefixIcon: const Icon(Icons.notes_rounded, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Aligned side-by-side action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'रद्द करें (Cancel)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 1,
                            ),
                            onPressed: () async {
                              final newStock = double.tryParse(qtyCtrl.text.trim());
                              if (newStock == null) return;

                              final prev = product.stock;
                              final delta = newStock - prev;
                              final shop = context.read<ShopProvider>().shop;
                              final updated = product.copyWith(stock: newStock);
                              await context.read<ProductProvider>().updateProduct(updated);

                              final adjustment = StockAdjustment(
                                id: const Uuid().v4(),
                                shopId: shop.id,
                                productId: product.id,
                                productName: product.name,
                                previousStock: prev,
                                newStock: newStock,
                                changeQuantity: delta,
                                adjustmentType: selectedType,
                                reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                                createdAt: DateTime.now(),
                              );

                              await StockAdjustmentService.instance.recordAdjustment(adjustment);

                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${product.name} का स्टॉक अपडेट हो गया (लॉग सेव्ड)'),
                                    backgroundColor: AppColors.primaryDark,
                                  ),
                                );
                              }
                            },
                            label: const Text('सेव करें (Save)', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showStockAdjustmentLogs(BuildContext context) async {
    final shop = context.read<ShopProvider>().shop;
    final logs = await StockAdjustmentService.instance.getAdjustments(shop.id);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_edu_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'स्टॉक ऑडिट व एडजस्टमेंट लॉग्स',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text('अभी तक कोई स्टॉक एडजस्टमेंट लॉग दर्ज नहीं है', style: TextStyle(color: AppColors.lightTextSecondary)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final log = logs[idx];
                        final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(log.createdAt);
                        final isPositive = log.changeQuantity >= 0;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: isPositive ? Colors.green.shade50 : Colors.red.shade50,
                            child: Icon(
                              isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline,
                              color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                          title: Text(log.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${log.typeLabelHindi} • $dateStr', style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
                              if (log.reason != null && log.reason!.isNotEmpty)
                                Text('नोट: ${log.reason}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isPositive ? "+" : ""}${log.changeQuantity}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                              Text(
                                '${log.previousStock} -> ${log.newStock}',
                                style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
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
              icon: const Icon(Icons.history_edu_rounded, color: AppColors.primary, size: 24),
              tooltip: 'स्टॉक ऑडिट लॉग्स (Adjustment Logs)',
              onPressed: () => _showStockAdjustmentLogs(context),
            ),
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
                    onChanged: (q) {
                      SoundService.instance.playTypeKey();
                      productProvider.setSearchQuery(q);
                    },
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
                  child: RefreshIndicator(
                    onRefresh: () async {
                      final shop = context.read<ShopProvider>().shop;
                      await context.read<ProductProvider>().loadProducts(shop.id);
                    },
                    child: products.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              Center(child: Text('कोई प्रोडक्ट नहीं मिला', style: TextStyle(color: AppColors.lightTextSecondary))),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            itemCount: products.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, i) {
                            final product = products[i];

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _showAddEditProductDialog(context, product),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Row: Image, Product Name, Category, Price, and 3-dots Menu
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ProductImageView(
                                            imageUrl: product.imageUrl,
                                            fallbackIcon: product.icon,
                                            size: 50,
                                            borderRadius: 10,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    letterSpacing: 0.2,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 3),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 2,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  children: [
                                                    Text(
                                                      'दर: ${CurrencyFormatter.format(product.price)} / ${product.unit}  •  ${product.category}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors.lightTextSecondary,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    if (product.mrp != null && product.mrp! > 0)
                                                      Text(
                                                        'MRP: ₹${product.mrp!.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          color: Colors.grey.shade500,
                                                          decoration: product.mrp! > product.price ? TextDecoration.lineThrough : null,
                                                        ),
                                                      ),
                                                    if (product.purchasePrice != null && product.purchasePrice! > 0)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF00875A).withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          'मुनाफा: ₹${(product.price - product.purchasePrice!).toStringAsFixed(1)}',
                                                          style: const TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF00875A),
                                                          ),
                                                        ),
                                                      ),
                                                    if (product.barcode != null && product.barcode!.isNotEmpty)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: Colors.blue.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.qr_code, size: 10, color: Colors.blue),
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              product.barcode!,
                                                              style: const TextStyle(
                                                                fontSize: 9.5,
                                                                fontWeight: FontWeight.w600,
                                                                color: Colors.blue,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert, size: 20, color: AppColors.lightTextSecondary),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
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
                                      const SizedBox(height: 10),
                                      const Divider(height: 1),
                                      const SizedBox(height: 8),

                                      // Bottom Row: Stock status badge on left, Stock amount & Adjust Button on right
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (product.isLowStock)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.error.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: AppColors.error.withOpacity(0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(Icons.warning_amber_rounded, size: 13, color: AppColors.error),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'LOW STOCK',
                                                    style: TextStyle(
                                                      color: AppColors.error,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'इन स्टॉक (In Stock)',
                                                style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              RichText(
                                                text: TextSpan(
                                                  children: [
                                                    const TextSpan(
                                                      text: 'स्टॉक: ',
                                                      style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                                                    ),
                                                    TextSpan(
                                                      text: '${product.stock} ${product.unit}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13.5,
                                                        color: product.isLowStock ? AppColors.error : AppColors.primaryDark,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              InkWell(
                                                onTap: () => _showStockAdjustmentDialog(context, product),
                                                borderRadius: BorderRadius.circular(6),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primarySurface,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: const [
                                                      Icon(Icons.edit_note, size: 16, color: AppColors.primary),
                                                      SizedBox(width: 3),
                                                      Text(
                                                        'एडजस्ट',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.primary,
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
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
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
                            final catImg = productProvider.getCategoryImage(cat);

                            return Card(
                              child: ListTile(
                                leading: ProductImageView(
                                  imageUrl: catImg,
                                  fallbackIcon: cat.isNotEmpty ? cat.substring(0, 1) : '📁',
                                  size: 42,
                                  borderRadius: 8,
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
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
                                      tooltip: 'फोटो जोड़ें / बदलें',
                                      onPressed: () => _showAddCategoryDialog(context, null, cat),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                      tooltip: 'Delete Category',
                                      onPressed: () => _confirmDeleteCategory(context, cat),
                                    ),
                                  ],
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
