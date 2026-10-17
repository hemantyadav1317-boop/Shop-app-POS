import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/product.dart';
import '../../../../providers/product_provider.dart';
import '../../../../providers/cart_provider.dart';
import 'qty_rate_dialog.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final cart = context.watch<CartProvider>();

    return Column(
      children: [
        // Category Filter Chips
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            scrollDirection: Axis.horizontal,
            itemCount: productProvider.categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = productProvider.categories[i];
              final isSelected = productProvider.selectedCategory == cat;

              return ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                selectedColor: AppColors.primarySurface,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.lightTextSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.lightBorder,
                ),
                onSelected: (_) => productProvider.selectCategory(cat),
              );
            },
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'सर्च करें: नाम (Aloo, आलू, Potato) या बारकोड...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: productProvider.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => productProvider.setSearchQuery(''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (val) => productProvider.setSearchQuery(val),
          ),
        ),
        const SizedBox(height: 6),

        // Product Grid
        Expanded(
          child: productProvider.filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.lightTextSecondary),
                      const SizedBox(height: 8),
                      Text(
                        'कोई सामान नहीं मिला\n(No products found for "${productProvider.searchQuery}")',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 170,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: productProvider.filteredProducts.length,
                  itemBuilder: (context, i) {
                    final product = productProvider.filteredProducts[i];

                    // Check if already in cart
                    final inCartItem = cart.lines.cast().firstWhere(
                          (l) => l.productId == product.id,
                          orElse: () => null,
                        );
                    final inCartQty = inCartItem?.qty ?? 0.0;

                    return _buildProductTile(context, product, inCartQty, cart);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductTile(BuildContext context, Product product, double inCartQty, CartProvider cart) {
    final isSelected = inCartQty > 0;

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => QtyRateDialog(
            product: product,
            initialQty: inCartQty > 0 ? inCartQty : 1.0,
            onConfirm: (cartItem) {
              cart.addLine(cartItem);
            },
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface.withOpacity(0.4) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Theme.of(context).dividerColor,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Product Icon
                Expanded(
                  child: Center(
                    child: Text(
                      product.icon ?? '📦',
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Name
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Rate
                Row(
                  children: [
                    Text(
                      CurrencyFormatter.formatCompact(product.price),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                    ),
                    Text(
                      ' / ${product.unit}',
                      style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                    ),
                  ],
                ),

                // Stock indicator
                Text(
                  product.isLowStock
                      ? '⚠️ कम स्टॉक: ${product.stock} ${product.unit}'
                      : 'Stock: ${product.stock} ${product.unit}',
                  style: TextStyle(
                    fontSize: 10,
                    color: product.isLowStock ? AppColors.error : AppColors.lightTextSecondary,
                    fontWeight: product.isLowStock ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),

            // In-Cart Badge
            if (inCartQty > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    inCartQty % 1 == 0 ? inCartQty.toInt().toString() : inCartQty.toStringAsFixed(2),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
