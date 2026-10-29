import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/product.dart';
import '../../../../data/models/cart_item.dart';
import '../../../../providers/product_provider.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../providers/shop_provider.dart';
import 'package:shop_pos/screens/widgets/product_image_view.dart';
import 'qty_rate_dialog.dart';

class ProductGrid extends StatefulWidget {
  const ProductGrid({super.key});

  @override
  State<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<ProductGrid> {
  Widget _buildCategoryIconWidget({
    required String? catImg,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    double size = 20,
  }) {
    if (catImg != null && catImg.trim().isNotEmpty) {
      final clean = catImg.trim();
      if (clean.startsWith('data:image')) {
        try {
          final commaIndex = clean.indexOf(',');
          final base64Data = commaIndex != -1 ? clean.substring(commaIndex + 1) : clean;
          final bytes = base64Decode(base64Data);
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                icon,
                size: size,
                color: isSelected ? Colors.white : const Color(0xFF00875A),
              ),
            ),
          );
        } catch (_) {}
      } else {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            clean,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(
              icon,
              size: size,
              color: isSelected ? Colors.white : const Color(0xFF00875A),
            ),
          ),
        );
      }
    }
    return Icon(
      icon,
      size: size,
      color: isSelected ? Colors.white : const Color(0xFF00875A),
    );
  }

  IconData _getCategoryIcon(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('veg') || lower.contains('सब्जी')) return Icons.eco_rounded;
    if (lower.contains('fruit') || lower.contains('फल')) return Icons.apple_rounded;
    if (lower.contains('dairy') || lower.contains('दूध') || lower.contains('डेयरी')) return Icons.local_drink_rounded;
    if (lower.contains('snack') || lower.contains('बिस्कुट') || lower.contains('नमकीन')) return Icons.bakery_dining_rounded;
    if (lower.contains('kirana') || lower.contains('grocery') || lower.contains('राशन')) return Icons.shopping_basket_rounded;
    if (lower.contains('all') || lower.contains('सभी')) return Icons.grid_view_rounded;
    return Icons.category_rounded;
  }

  String _getProductBadge(Product product, int index) {
    if (product.isLowStock) return 'कम स्टॉक';
    if (product.tag != null && product.tag!.trim().isNotEmpty) {
      return product.tag!.trim();
    }
    final mod = index % 4;
    if (mod == 0) return 'ताजा';
    if (mod == 1) return 'बेस्टसेलर';
    if (mod == 2) return 'ऑर्गैनिक';
    return 'नई आवक';
  }

  Color _getBadgeColor(String badge) {
    final lower = badge.toLowerCase();
    if (badge == 'बेस्टसेलर' || lower.contains('best')) return const Color(0xFFD97706);
    if (badge == 'कम स्टॉक' || lower.contains('low')) return const Color(0xFFDC2626);
    if (badge == 'नई आवक' || lower.contains('new')) return const Color(0xFF2563EB);
    if (lower.contains('organic') || badge.contains('ऑर्गैनिक')) return const Color(0xFF059669);
    return const Color(0xFF00875A); // ताजा & custom tags
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final cart = context.watch<CartProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return CustomScrollView(
      slivers: [
        // 1. Search Bar (Floating white pill with soft shadow)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 10 : 14, isMobile ? 8 : 10, isMobile ? 10 : 14, 6),
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
                    fontSize: isMobile ? 12 : 13,
                    color: isDark ? Colors.white60 : Colors.grey.shade500,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: isMobile ? 20 : 22,
                    color: const Color(0xFF00875A),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (productProvider.searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => productProvider.setSearchQuery(''),
                        ),
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
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
        ),

        // 2. Category Cards Row (All, Vegetables, Fruits, Grocery, etc.)
        SliverToBoxAdapter(
          child: SizedBox(
            height: isMobile ? 62 : 68,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              scrollDirection: Axis.horizontal,
              itemCount: productProvider.categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = productProvider.categories[i];
                final isSelected = productProvider.selectedCategory == cat;
                final count = productProvider.getProductCountForCategory(cat);
                final icon = _getCategoryIcon(cat);
                final catImg = productProvider.getCategoryImage(cat);

                return InkWell(
                  onTap: () {
                    SoundService.instance.playButtonClick();
                    productProvider.selectCategory(cat);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isMobile ? 70 : 80,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00875A) // Vibrant Forest Green
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00875A)
                            : (isDark ? Colors.white12 : Colors.grey.shade200),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? const Color(0xFF00875A).withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: isSelected ? 6 : 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCategoryIconWidget(
                          catImg: catImg,
                          icon: icon,
                          isSelected: isSelected,
                          isDark: isDark,
                          size: isMobile ? 18 : 22,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isMobile ? 10 : 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF1E293B)),
                          ),
                        ),
                        Text(
                          '($count)',
                          style: TextStyle(
                            fontSize: isMobile ? 9 : 10,
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

        const SliverToBoxAdapter(child: SizedBox(height: 4)),

        // 3. Dense Product Grid
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
                          childAspectRatio: 0.82,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        )
                      : const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 145,
                          childAspectRatio: 0.84,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final product = productProvider.filteredProducts[i];
                      final inCartItem = cart.lines.cast().firstWhere(
                            (l) => l.productId == product.id,
                            orElse: () => null,
                          );
                      final inCartQty = inCartItem?.qty ?? 0.0;
                      return _buildProductCard(context, product, inCartQty, cart, i, isMobile);
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
    int index,
    bool isMobile,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badge = _getProductBadge(product, index);
    final badgeColor = _getBadgeColor(badge);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(
          color: inCartQty > 0
              ? const Color(0xFF00875A)
              : (isDark ? Colors.white12 : Colors.grey.shade200),
          width: inCartQty > 0 ? 1.5 : 1.0,
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
              // Product Image container with floating status badge
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(isMobile ? 10 : 12)),
                      child: Container(
                        width: double.infinity,
                        color: isDark ? Colors.black26 : Colors.grey.shade50,
                        child: Center(
                          child: ProductImageView(
                            imageUrl: product.imageUrl,
                            fallbackIcon: product.icon,
                            size: isMobile ? 46 : 54,
                            borderRadius: 8,
                          ),
                        ),
                      ),
                    ),

                    // Top Left Status Badge (ताजा, बेस्टसेलर, ऑर्गैनिक, नई आवक / कस्टम टैग) - Optional & Default OFF
                    if (context.watch<ShopProvider>().showProductBadges)
                      Positioned(
                        top: 3,
                        left: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Product Info & Price
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 3, 5, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Product Name
                    Text(
                      product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: isMobile ? 10.5 : 11.5,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 2),

                    // Price & Stock row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Bold Green Price
                              RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: CurrencyFormatter.formatCompact(product.price),
                                      style: TextStyle(
                                        fontSize: isMobile ? 11.5 : 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF00875A), // Vibrant Green
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' /${product.unit}',
                                      style: TextStyle(
                                        fontSize: isMobile ? 8.5 : 9.5,
                                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 1),

                              // Stock
                              Row(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 8,
                                    color: product.isLowStock ? Colors.red : const Color(0xFF00875A),
                                  ),
                                  const SizedBox(width: 1.5),
                                  Expanded(
                                    child: Text(
                                      '${product.stock} ${product.unit}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 8,
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

                        // Oval Dark Green Cart Button [ 🛒+ ] with touch sound
                        InkWell(
                          onTap: () {
                            SoundService.instance.playProductAdd();
                            // 1-Tap quick add to cart
                            cart.addLine(CartItem(
                              productId: product.id,
                              name: product.name,
                              price: product.price,
                              qty: (inCartQty > 0 ? inCartQty + 1 : 1.0),
                              unit: product.unit,
                              imageUrl: product.imageUrl,
                              icon: product.icon,
                            ));
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF004D40), // Dark Forest Green
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 1),
                                Text(
                                  inCartQty > 0
                                      ? '+${inCartQty % 1 == 0 ? inCartQty.toInt() : inCartQty.toStringAsFixed(1)}'
                                      : '+',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9.5,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
