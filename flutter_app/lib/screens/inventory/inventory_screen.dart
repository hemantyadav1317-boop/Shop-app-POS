import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../main_shell.dart';
import 'add_edit_product_screen.dart';
import 'mandi_order_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import 'package:shop_pos/screens/widgets/product_image_view.dart';
import 'category_products_screen.dart';
import '../../core/utils/pos_sound_formatter.dart';
import '../../core/services/sound_service.dart';
import 'widgets/bulk_import_dialog.dart';
import 'package:intl/intl.dart';
import '../../data/models/stock_adjustment.dart';
import '../../data/services/stock_adjustment_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  static String getCategoryEmoji(String category) {
    final cat = category.trim().toLowerCase();
    if (cat.contains('सब्ज') || cat.contains('veg') || cat.contains('sabji')) return '🥦';
    if (cat.contains('फल') || cat.contains('fruit')) return '🍎';
    if (cat.contains('किराना') || cat.contains('kirana') || cat.contains('groc')) return '🥫';
    if (cat.contains('स्नैक्स') || cat.contains('snack') || cat.contains('namkeen') || cat.contains('चिप्स')) return '🍟';
    if (cat.contains('डेयरी') || cat.contains('dairy') || cat.contains('milk') || cat.contains('दूध')) return '🥛';
    if (cat.contains('पर्सनल') || cat.contains('care') || cat.contains('साबुन') || cat.contains('soap')) return '🧴';
    if (cat.contains('बेकरी') || cat.contains('bake') || cat.contains('bread') || cat.contains('ब्रेड')) return '🍞';
    if (cat.contains('मसाले') || cat.contains('spice') || cat.contains('mirch') || cat.contains('मिर्च')) return '🌶️';
    if (cat.contains('पेय') || cat.contains('drink') || cat.contains('cold') || cat.contains('juice') || cat.contains('शरबत')) return '🥤';
    if (cat.contains('अनाज') || cat.contains('दाल') || cat.contains('grain') || cat.contains('pulse') || cat.contains('चावल')) return '🌾';
    if (cat.contains('तेल') || cat.contains('oil') || cat.contains('ghee') || cat.contains('घी')) return '🛢️';
    if (cat.contains('मीठा') || cat.contains('sweet') || cat.contains('mithai')) return '🍬';
    if (cat.contains('पूजा') || cat.contains('pooja') || cat.contains('puja')) return '🪔';
    if (cat.contains('सफाई') || cat.contains('clean') || cat.contains('detergent')) return '🧹';
    if (cat.contains('स्टेशनरी') || cat.contains('stationery') || cat.contains('pen')) return '✏️';
    return '📦';
  }

  static void showAddEditProductDialog(
    BuildContext context, {
    Product? existing,
    String? preselectedCategory,
  }) {
    _InventoryScreenState._showAddEditProductDialogDirect(context, existing, preselectedCategory);
  }

  static void showAddEditProductDialogStatic(
    BuildContext context, {
    Product? existing,
    String? preselectedCategory,
  }) {
    _InventoryScreenState._showAddEditProductDialogDirect(context, existing, preselectedCategory);
  }

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _onlyLowStock = false;

  static void _showAddCategoryDialog(BuildContext context, [Function(String)? onCreated, String? existingCat]) {
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('सुरक्षा नियम: केवल दुकान मालिक नई कैटेगरी बना सकते हैं।'),
        ),
      );
      return;
    }
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
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('सुरक्षा नियम: केवल दुकान मालिक कैटेगरी डिलीट कर सकते हैं।'),
        ),
      );
      return;
    }
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

  static void _confirmDeleteProduct(BuildContext context, Product product) {
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('सुरक्षा नियम: केवल दुकान मालिक सामान डिलीट कर सकते हैं।'),
        ),
      );
      return;
    }
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

  static void _showAddEditProductDialogDirect(BuildContext context, [Product? existing, String? preselectedCategory]) {
    final auth = context.read<AuthProvider>();
    if (existing == null && auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('सुरक्षा नियम: केवल दुकान मालिक नया सामान जोड़ सकते हैं।'),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditProductScreen(
          existing: existing,
          preselectedCategory: preselectedCategory,
        ),
      ),
    );
  }
  void _showStockAdjustmentDialog(BuildContext context, Product product) {
    final localeCode = Provider.of<LocaleProvider>(context, listen: false).localeCode;
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
                            color: const Color(0xFF1A4B8E).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.tune_rounded, color: Color(0xFF1A4B8E), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.localizedName(localeCode),
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
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF1A4B8E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white12 : const Color(0xFF1A4B8E).withValues(alpha: 0.2),
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
                              color: Color(0xFF1A4B8E),
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
                              backgroundColor: const Color(0xFF1A4B8E),
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
    final shop = context.watch<ShopProvider>().shop;
    final productProvider = context.watch<ProductProvider>();
    final localeCode = context.watch<LocaleProvider>().localeCode;
    final products = _onlyLowStock
        ? productProvider.products.where((p) => p.isLowStock).toList()
        : productProvider.filteredProducts;

    final lowStockCount = productProvider.products.where((p) => p.isLowStock).length;
    final allCats = productProvider.allCategories;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            tooltip: 'मेन्यू',
            onPressed: () {
              SoundService.instance.playButtonClick();
              MainShell.openDrawer(context);
            },
          ),
          title: const Text('Inventory', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            tabs: [
              Tab(
                text: 'Products (${products.length})',
              ),
              Tab(
                text: 'Category (${allCats.length})',
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.upload_file, color: Colors.white, size: 22),
              tooltip: 'बल्क जोड़ें (Excel/CSV)',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const BulkImportDialog(),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.history_edu_rounded, color: Colors.white, size: 22),
              tooltip: 'स्टॉक ऑडिट लॉग्स (Adjustment Logs)',
              onPressed: () => _showStockAdjustmentLogs(context),
            ),
            const SizedBox(width: 4),
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
                        const SizedBox(width: 4),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            elevation: 1,
                          ),
                          icon: const Icon(Icons.assignment_outlined, size: 14),
                          label: const Text('मंडी पर्ची', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            SoundService.instance.playButtonClick();
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const MandiOrderScreen()));
                          },
                        ),
                      ],
                    ),
                  ),

                // Search Field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: shop.hasBarcodeSupport
                          ? 'Search products or scan barcode...'
                          : 'Search products by name...',
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (q) {
                      SoundService.instance.playTypeKey();
                      productProvider.setSearchQuery(q);
                    },
                  ),
                ),
                const SizedBox(height: 4),

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
                              Center(child: Text('No products found', style: TextStyle(color: AppColors.lightTextSecondary))),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 80),
                            itemCount: products.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, i) {
                            final product = products[i];

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _showAddEditProductDialogDirect(context, product),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      ProductImageView(
                                        imageUrl: product.imageUrl,
                                        fallbackIcon: product.icon,
                                        size: 46,
                                        borderRadius: 8,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.localizedName(localeCode),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14.5,
                                                letterSpacing: 0.1,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Wrap(
                                              spacing: 5,
                                              runSpacing: 2,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.lightMuted,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    product.category,
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w500,
                                                      color: AppColors.lightTextSecondary,
                                                    ),
                                                  ),
                                                ),
                                                if (product.barcode != null && product.barcode!.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.withValues(alpha: 0.08),
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
                                                if (product.isLowStock)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.error.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'LOW STOCK',
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppColors.error,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  '${CurrencyFormatter.format(product.price)} / ${product.unit}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                if (product.mrp != null && product.mrp! > product.price) ...[
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '₹${product.mrp!.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey.shade500,
                                                      decoration: TextDecoration.lineThrough,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          InkWell(
                                            onTap: () => _showStockAdjustmentDialog(context, product),
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: product.isLowStock
                                                    ? AppColors.error.withValues(alpha: 0.1)
                                                    : AppColors.primarySurface,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${product.stock} ${product.unit}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: product.isLowStock ? AppColors.error : AppColors.primaryDark,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert, size: 20, color: AppColors.lightTextSecondary),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onSelected: (val) {
                                              if (val == 'edit') {
                                                _showAddEditProductDialogDirect(context, product);
                                              } else if (val == 'adjust') {
                                                _showStockAdjustmentDialog(context, product);
                                              } else if (val == 'delete') {
                                                _confirmDeleteProduct(context, product);
                                              }
                                            },
                                            itemBuilder: (ctx) {
                                              final isStaff = context.read<AuthProvider>().isStaffSession;
                                              return [
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.edit, size: 16),
                                                      SizedBox(width: 8),
                                                      Text('Edit Product'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'adjust',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.tune, size: 16, color: AppColors.primary),
                                                      SizedBox(width: 8),
                                                      Text('Adjust Stock'),
                                                    ],
                                                  ),
                                                ),
                                                if (!isStaff)
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                                        SizedBox(width: 8),
                                                        Text('Delete Product', style: TextStyle(color: AppColors.error)),
                                                      ],
                                                    ),
                                                  ),
                                              ];
                                            },
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
                      if (!context.watch<AuthProvider>().isStaffSession)
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

                // Category List (Clean & Premium Billiez Layout)
                Expanded(
                  child: allCats.isEmpty
                      ? const Center(
                          child: Text(
                            'कोई कैटेगरी नहीं है (No Category Yet)',
                            style: TextStyle(color: AppColors.lightTextSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 80),
                          itemCount: allCats.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            final cat = allCats[i];
                            final count = productProvider.getProductCountForCategory(cat);

                            return Card(
                              elevation: 0.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  SoundService.instance.playButtonClick();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CategoryProductsScreen(category: cat),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cat.toUpperCase(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14.5,
                                                letterSpacing: 0.3,
                                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$count Products',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.lightTextSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!context.watch<AuthProvider>().isStaffSession) ...[
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.error,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          icon: const Icon(Icons.delete_outline, size: 16),
                                          label: const Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                          onPressed: () => _confirmDeleteCategory(context, cat),
                                        ),
                                        const SizedBox(width: 4),
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          icon: const Icon(Icons.add, size: 16),
                                          label: const Text('Add Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          onPressed: () => _showAddEditProductDialogDirect(context, null, cat),
                                        ),
                                        const SizedBox(width: 2),
                                      ],
                                      const Icon(Icons.keyboard_arrow_right_rounded, size: 20, color: Colors.grey),
                                    ],
                                  ),
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
        floatingActionButton: context.watch<AuthProvider>().isStaffSession
            ? null
            : Builder(
                builder: (scaffoldContext) {
                  return FloatingActionButton(
                    backgroundColor: AppColors.primary,
                    elevation: 3,
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                    onPressed: () {
                      final tabController = DefaultTabController.of(scaffoldContext);
                      if (tabController.index == 1) {
                        _showAddCategoryDialog(context);
                      } else {
                        _showAddEditProductDialogDirect(context);
                      }
                    },
                  );
                },
              ),
      ),
    );
  }
}
