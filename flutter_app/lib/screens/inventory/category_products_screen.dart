import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/sound_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import 'package:shop_pos/screens/widgets/product_image_view.dart';
import 'inventory_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String category;

  const CategoryProductsScreen({super.key, required this.category});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final productProvider = context.watch<ProductProvider>();

    // Filter products for this specific category
    final categoryProducts = productProvider.products
        .where((p) => p.category.trim().toUpperCase() == widget.category.trim().toUpperCase())
        .toList();

    // Apply live search query
    final filtered = categoryProducts.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          (p.barcode != null && p.barcode!.toLowerCase().contains(q));
    }).toList();

    // Summary calculations
    final totalCount = categoryProducts.length;
    double totalStockVal = 0.0;
    double totalStockQty = 0.0;
    int lowStockCount = 0;

    for (final p in categoryProducts) {
      totalStockQty += p.stock;
      totalStockVal += (p.price * p.stock);
      if (p.isLowStock) lowStockCount++;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.category,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '$totalCount सामान • कुल स्टॉक: ${totalStockQty.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          if (!context.watch<AuthProvider>().isStaffSession)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'सामान जोड़ें',
              onPressed: () {
                SoundService.instance.playButtonClick();
                InventoryScreen.showAddEditProductDialogStatic(
                  context,
                  preselectedCategory: widget.category,
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 📊 Category Analytics & Summary Card
          Container(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00875A).withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00875A).withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('कुल सामान', '$totalCount', Icons.category_rounded, const Color(0xFF2563EB)),
                Container(height: 32, width: 1, color: Colors.grey.withValues(alpha: 0.25)),
                _buildStatItem(
                  'स्टॉक वैल्यू',
                  '₹${totalStockVal.toStringAsFixed(0)}',
                  Icons.currency_rupee_rounded,
                  const Color(0xFF00875A),
                ),
                Container(height: 32, width: 1, color: Colors.grey.withValues(alpha: 0.25)),
                _buildStatItem(
                  'कम स्टॉक',
                  '$lowStockCount',
                  Icons.warning_amber_rounded,
                  lowStockCount > 0 ? Colors.red : Colors.grey,
                ),
              ],
            ),
          ),

          // 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '"${widget.category}" में सामान या बारकोड खोजें...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),

          // 📦 Products List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'खोज परिणाम में कोई सामान नहीं मिला'
                                : 'इस कैटेगरी में अभी कोई सामान नहीं है',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('+ सामान जोड़ें'),
                            onPressed: () {
                              InventoryScreen.showAddEditProductDialogStatic(
                                context,
                                preselectedCategory: widget.category,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      final marginVal = product.purchasePrice != null
                          ? (product.price - product.purchasePrice!)
                          : null;

                      return Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: product.isLowStock
                                ? Colors.red.withValues(alpha: 0.3)
                                : Colors.grey.withValues(alpha: 0.15),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            SoundService.instance.playButtonClick();
                            InventoryScreen.showAddEditProductDialog(
                              context,
                              existing: product,
                              preselectedCategory: widget.category,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ProductImageView(
                                  imageUrl: product.imageUrl,
                                  fallbackIcon: (product.icon != null && product.icon!.isNotEmpty && product.icon != '📦') ? product.icon! : InventoryScreen.getCategoryEmoji(widget.category),
                                  size: 48,
                                  borderRadius: 10,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            '₹${product.price.toStringAsFixed(1)} / ${product.unit}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: Color(0xFF00875A),
                                            ),
                                          ),
                                          if (product.mrp != null && product.mrp! > product.price) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              'MRP ₹${product.mrp!.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: Colors.grey.shade500,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                          ],
                                          if (marginVal != null) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF00875A).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'मुनाफा: ₹${marginVal.toStringAsFixed(1)}',
                                                style: const TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF00875A),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: product.isLowStock
                                            ? Colors.red.withValues(alpha: 0.12)
                                            : const Color(0xFF00875A).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${product.stock} ${product.unit}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: product.isLowStock ? Colors.red : const Color(0xFF00875A),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
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
        ],
      ),
      floatingActionButton: context.watch<AuthProvider>().isStaffSession
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('नया सामान', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                SoundService.instance.playButtonClick();
                InventoryScreen.showAddEditProductDialogStatic(
                  context,
                  preselectedCategory: widget.category,
                );
              },
            ),
    );
  }

  Widget _buildStatItem(String title, String val, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color),
        ),
      ],
    );
  }
}
