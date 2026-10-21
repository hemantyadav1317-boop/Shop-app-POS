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

class ProductGrid extends StatefulWidget {
  const ProductGrid({super.key});

  @override
  State<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<ProductGrid> {
  final Set<String> _favoritedIds = {};

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
    final mod = index % 4;
    if (mod == 0) return 'ताजा';
    if (mod == 1) return 'बेस्टसेलर';
    if (mod == 2) return 'ऑर्गैनिक';
    return 'नई आवक';
  }

  Color _getBadgeColor(String badge) {
    if (badge == 'बेस्टसेलर') return const Color(0xFFD97706);
    if (badge == 'कम स्टॉक') return const Color(0xFFDC2626);
    if (badge == 'नई आवक') return const Color(0xFF2563EB);
    return const Color(0xFF00875A); // ताजा & ऑर्गैनिक
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final cart = context.watch<CartProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        // 1. Search Bar (Floating white pill with soft shadow)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
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
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.grey.shade500,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 22,
                    color: Color(0xFF00875A),
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
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) => productProvider.setSearchQuery(val),
              ),
            ),
          ),
        ),

        // 2. Category Cards Row (All, Vegetables, Fruits, Grocery, etc.)
        SliverToBoxAdapter(
          child: SizedBox(
            height: 82,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: productProvider.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final cat = productProvider.categories[i];
                final isSelected = productProvider.selectedCategory == cat;
                final count = productProvider.getProductCountForCategory(cat);
                final icon = _getCategoryIcon(cat);

                return InkWell(
                  onTap: () {
                    SoundService.instance.playClick();
                    productProvider.selectCategory(cat);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 76,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00875A) // Vibrant Forest Green
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00875A)
                            : (isDark ? Colors.white12 : Colors.grey.shade200),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? const Color(0xFF00875A).withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: isSelected ? 8 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 22,
                          color: isSelected ? Colors.white : const Color(0xFF00875A),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF1E293B)),
                          ),
                        ),
                        Text(
                          '($count)',
                          style: TextStyle(
                            fontSize: 10,
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

        // 3. Promotional Indian Supermarket Banner
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                image: DecorationImage(
                  image: const AssetImage('assets/images/pos_promo_banner.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    const Color(0xFF042F1B).withValues(alpha: 0.72), // Lush green overlay
                    BlendMode.darken,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00875A).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.eco, size: 12, color: Color(0xFF4ADE80)),
                              SizedBox(width: 4),
                              Text(
                                'ताजा और प्रीमियम',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'ताजा फल और सब्जियाँ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'सीधे किसान से आपके लिए',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: const [
                            _BannerPill(icon: Icons.check_circle_outline, text: '100% Fresh'),
                            _BannerPill(icon: Icons.verified_user_outlined, text: 'Best Quality'),
                            _BannerPill(icon: Icons.bolt, text: 'Fast Billing'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.shopping_basket_rounded,
                        size: 40,
                        color: Color(0xFF4ADE80),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 4. Section Header: '🍃 आज की खास पेशकश'
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.eco_rounded, size: 18, color: Color(0xFF00875A)),
                    SizedBox(width: 6),
                    Text(
                      'आज की खास पेशकश',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                  ],
                ),
                Text(
                  'सभी देखें (${productProvider.filteredProducts.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00875A),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 5. 2-Column Product Grid
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
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 80),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.76,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final product = productProvider.filteredProducts[i];
                      final inCartItem = cart.lines.cast().firstWhere(
                            (l) => l.productId == product.id,
                            orElse: () => null,
                          );
                      final inCartQty = inCartItem?.qty ?? 0.0;
                      return _buildProductCard(context, product, inCartQty, cart, i);
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
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badge = _getProductBadge(product, index);
    final badgeColor = _getBadgeColor(badge);
    final isFav = _favoritedIds.contains(product.id);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: inCartQty > 0
              ? const Color(0xFF00875A)
              : (isDark ? Colors.white12 : Colors.grey.shade200),
          width: inCartQty > 0 ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
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
              // Product Image container with floating badges
              Expanded(
                flex: 11,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      child: Container(
                        width: double.infinity,
                        color: isDark ? Colors.black26 : Colors.grey.shade50,
                        child: Center(
                          child: ProductImageView(
                            imageUrl: product.imageUrl,
                            fallbackIcon: product.icon,
                            size: 76,
                            borderRadius: 12,
                          ),
                        ),
                      ),
                    ),

                    // Top Left Status Badge (ताजा, बेस्टसेलर, ऑर्गैनिक, नई आवक)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: badgeColor.withValues(alpha: 0.35),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              badge == 'बेस्टसेलर' ? Icons.star_rounded : Icons.eco,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              badge,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Top Right Heart Button (Wishlist / Favorite)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: () {
                          SoundService.instance.playClick();
                          setState(() {
                            if (isFav) {
                              _favoritedIds.remove(product.id);
                            } else {
                              _favoritedIds.add(product.id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: isFav ? Colors.red : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Product Info & Price
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Price & Stock row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Bold Green Price
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: CurrencyFormatter.formatCompact(product.price),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF00875A), // Vibrant Green
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' / ${product.unit}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),

                              // Stock
                              Row(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 11,
                                    color: product.isLowStock ? Colors.red : const Color(0xFF00875A),
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      'Stock: ${product.stock} ${product.unit}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
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

                        // Oval Dark Green Cart Button [ 🛒+ ]
                        InkWell(
                          onTap: () {
                            // 1-Tap quick add to cart
                            cart.addLine(CartItem(
                              productId: product.id,
                              name: product.name,
                              price: product.price,
                              qty: (inCartQty > 0 ? inCartQty + 1 : 1.0),
                              unit: product.unit,
                            ));
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF004D40), // Dark Forest Green
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF004D40).withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  inCartQty > 0
                                      ? '+${inCartQty % 1 == 0 ? inCartQty.toInt() : inCartQty.toStringAsFixed(1)}'
                                      : '+',
                                  style: const TextStyle(
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

class _BannerPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BannerPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: const Color(0xFF4ADE80)),
        const SizedBox(width: 2),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
