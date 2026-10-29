import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/product.dart';
import '../../../../data/models/cart_item.dart';
import '../../../../providers/product_provider.dart';
import '../../../../providers/cart_provider.dart';
import 'package:shop_pos/screens/widgets/product_image_view.dart';
import 'qty_rate_dialog.dart';

class _StickyCategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  final Color backgroundColor;

  _StickyCategoryHeaderDelegate({
    required this.child,
    this.height = 44.0,
    required this.backgroundColor,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: height,
      color: backgroundColor,
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyCategoryHeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.height != height ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class ProductGrid extends StatefulWidget {
  const ProductGrid({super.key});

  @override
  State<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<ProductGrid> {
  void _showQuickSellDialog(BuildContext context) {
    SoundService.instance.playButtonClick();
    final nameCtrl = TextEditingController(text: 'खुला सामान');
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    String selectedUnit = 'pc';

    final presets = ['खुला सामान', 'दूध / दही', 'सब्जी / फल', 'नाश्ता', 'किराना', 'अन्य'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.bolt, color: Color(0xFF00875A), size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚡ क्विक सेल / Quick Item',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('त्वरित नाम चुनें (Presets):', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: presets.map((p) {
                      final isSel = nameCtrl.text == p;
                      return ChoiceChip(
                        label: Text(p, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null)),
                        selected: isSel,
                        selectedColor: const Color(0xFF00875A),
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() => nameCtrl.text = p);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'सामान का नाम *',
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: priceCtrl,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'दर / Price (₹) *',
                            prefixIcon: Icon(Icons.currency_rupee),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'मात्रा *',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: selectedUnit,
                        underline: const SizedBox(),
                        items: ['pc', 'kg', 'ltr', 'g', 'pack'].map((u) {
                          return DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontWeight: FontWeight.bold)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedUnit = val);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('रद्द करें (Cancel)'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('बिल में जोड़ें (Add)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00875A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final name = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Quick Item';
                  final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                  final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;

                  if (price <= 0 || qty <= 0) {
                    SoundService.instance.playError();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFFDC2626),
                        content: Text('⚠️ कृपया सही मूल्य और मात्रा दर्ज करें!'),
                      ),
                    );
                    return;
                  }

                  final cart = context.read<CartProvider>();
                  final quickItem = CartItem(
                    productId: 'quick_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    unit: selectedUnit,
                    price: price,
                    qty: qty,
                    icon: '⚡',
                  );

                  cart.addLine(quickItem);
                  SoundService.instance.playSuccess();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF00875A),
                      duration: const Duration(seconds: 2),
                      content: Text('⚡ "$name" बिल में जोड़ दिया गया (₹${quickItem.total})'),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final cart = context.watch<CartProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return CustomScrollView(
      slivers: [
        // 1. Search Bar + Quick Sell Action Button
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 10 : 14, isMobile ? 8 : 10, isMobile ? 10 : 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.shade200,
                      ),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'सर्च करें: नाम (Aloo, आलू, Potato) या बारकोड...',
                        hintStyle: TextStyle(
                          fontSize: isMobile ? 11.5 : 13,
                          color: isDark ? Colors.white60 : Colors.grey.shade500,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: isMobile ? 20 : 22,
                          color: const Color(0xFF00875A),
                        ),
                        suffixIcon: productProvider.searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => productProvider.setSearchQuery(''),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: isMobile ? 8 : 10),
                      ),
                      onChanged: (val) {
                        SoundService.instance.playTypeKey();
                        productProvider.setSearchQuery(val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // ⚡ Quick Sell Action Button
                InkWell(
                  onTap: () => _showQuickSellDialog(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00875A),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00875A).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, color: Colors.white, size: 17),
                        SizedBox(width: 3),
                        Text(
                          'Quick',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. FIXED / STICKY Text-Only Category Bar (Pinned while scrolling products)
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyCategoryHeaderDelegate(
            height: isMobile ? 42.0 : 46.0,
            backgroundColor: isDark ? const Color(0xFF0F172A) : Theme.of(context).scaffoldBackgroundColor,
            child: SizedBox(
              height: isMobile ? 42.0 : 46.0,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                scrollDirection: Axis.horizontal,
                itemCount: productProvider.categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final cat = productProvider.categories[i];
                  final isSelected = productProvider.selectedCategory == cat;
                  final count = productProvider.getProductCountForCategory(cat);

                  return InkWell(
                    onTap: () {
                      SoundService.instance.playButtonClick();
                      productProvider.selectCategory(cat);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF00875A)
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF00875A)
                              : (isDark ? Colors.white12 : Colors.grey.shade300),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? const Color(0xFF00875A).withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: 0.02),
                            blurRadius: isSelected ? 4 : 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cat,
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 13,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF1E293B)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '($count)',
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white70 : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 6)),

        // 3. Dense Product Grid with Full-Bleed Photos
        productProvider.filteredProducts.isEmpty
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text(
                        'कोई सामान नहीं मिला\n(No products found for "${productProvider.searchQuery}")',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            : SliverPadding(
                padding: EdgeInsets.fromLTRB(isMobile ? 8 : 12, 0, isMobile ? 8 : 12, 80),
                sliver: SliverGrid(
                  gridDelegate: isMobile
                      ? const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.84,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        )
                      : const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 145,
                          childAspectRatio: 0.86,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final product = productProvider.filteredProducts[i];
                      final inCartItem = cart.lines.cast<CartItem?>().firstWhere(
                            (l) => l?.productId == product.id,
                            orElse: () => null,
                          );
                      final inCartQty = inCartItem?.qty ?? 0.0;
                      return _buildProductCard(context, product, inCartQty, cart, isMobile);
                    },
                    childCount: productProvider.filteredProducts.length,
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Product product,
    double inCartQty,
    CartProvider cart,
    bool isMobile,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(
          color: inCartQty > 0
              ? const Color(0xFF00875A)
              : (isDark ? Colors.white12 : Colors.grey.shade200),
          width: inCartQty > 0 ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
          onTap: () {
            // Touch sound effect on tapping product card
            SoundService.instance.playProductAdd();
            // Detailed quantity and rate dialog on tapping product card
            showDialog(
              context: context,
              builder: (_) => QtyRateDialog(
                product: product,
                initialQty: inCartQty > 0 ? inCartQty : 1.0,
                onConfirm: (cartItem) => cart.addLine(cartItem),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Full-Bleed Product Image (Fills 100% available width & height, no empty spaces)
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(isMobile ? 10 : 12)),
                        child: ProductImageView(
                          imageUrl: product.imageUrl,
                          fallbackIcon: product.icon,
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 0,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    // In-Cart Indicator Badge (if already added to current bill)
                    if (inCartQty > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00875A),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                          child: Text(
                            '✓ ${inCartQty % 1 == 0 ? inCartQty.toInt() : inCartQty.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // Out of stock overlay indicator
                    if (product.stock <= 0)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(isMobile ? 10 : 12)),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'OUT OF STOCK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Product Info: Name, Price, and Stock (Full width without cramped cart icon)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Product Name
                    Text(
                      product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: isMobile ? 11 : 12,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Bold Green Price
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: CurrencyFormatter.formatCompact(product.price),
                            style: TextStyle(
                              fontSize: isMobile ? 12.5 : 13.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF00875A),
                            ),
                          ),
                          TextSpan(
                            text: ' /${product.unit}',
                            style: TextStyle(
                              fontSize: isMobile ? 9 : 10,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1.5),

                    // Real-time Stock Display
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 9,
                          color: product.isLowStock ? Colors.red : const Color(0xFF00875A),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            'Stock: ${product.stock} ${product.unit}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 8.5,
                              color: product.isLowStock
                                  ? Colors.red.shade700
                                  : (isDark ? Colors.white60 : Colors.grey.shade600),
                              fontWeight: product.isLowStock ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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
}
