import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/cart_provider.dart';
import '../../providers/shop_provider.dart';
import 'widgets/product_grid.dart';
import 'widgets/cart_panel.dart';
import 'widgets/quick_sell_dialog.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  void _showCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('करंट आर्डर / Current Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            body: CartPanel(
              onCompleted: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
    );
  }

  void _showSavedOrders(BuildContext context) {
    final cart = context.read<CartProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('होल्ड किए गए बिल / Saved Bills'),
        content: SizedBox(
          width: 360,
          child: cart.savedCarts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('कोई सेव किया गया बिल नहीं है', textAlign: TextAlign.center),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: cart.savedCarts.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, i) {
                    final saved = cart.savedCarts[i];
                    final total = saved.items.fold(0.0, (sum, it) => sum + it.total) - saved.discount;

                    return ListTile(
                      title: Text(saved.customer?.name ?? 'Walk-in Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${saved.items.length} Items · Time: ${saved.time}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(CurrencyFormatter.format(total), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          IconButton(
                            icon: const Icon(Icons.restore, color: AppColors.primary),
                            onPressed: () {
                              cart.recallCart(saved);
                              Navigator.pop(ctx);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.error, size: 18),
                            onPressed: () {
                              cart.removeSavedCart(saved.id);
                              Navigator.pop(ctx);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>().shop;
    final cart = context.watch<CartProvider>();
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              shop.phone != null ? '📞 ${shop.phone}' : 'POS Billing Mode',
              style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
            ),
          ],
        ),
        actions: [
          // Saved / Held orders button
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.bookmark_outline),
                tooltip: 'Saved Bills',
                onPressed: () => _showSavedOrders(context),
              ),
              if (cart.savedCarts.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
                    child: Text(
                      '${cart.savedCarts.length}',
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),

          // Quick Sell
          TextButton.icon(
            icon: const Icon(Icons.flash_on, color: AppColors.primary, size: 18),
            label: const Text('Quick Sell', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => QuickSellDialog(
                  onConfirm: (item) => cart.addLine(item),
                ),
              );
            },
          ),
        ],
      ),
      body: isTablet
          // Tablet Split-screen: 65% Catalog Grid, 35% Live Cart Panel
          ? Row(
              children: [
                const Expanded(
                  flex: 65,
                  child: ProductGrid(),
                ),
                VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
                const Expanded(
                  flex: 35,
                  child: CartPanel(),
                ),
              ],
            )
          // Mobile Screen: Grid with Floating Bottom Cart Bar
          : Stack(
              children: [
                const ProductGrid(),

                // Mobile Bottom Floating Cart Bar
                if (cart.lines.isNotEmpty)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: InkWell(
                      onTap: () => _showCartSheet(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${cart.itemCount} Items (${cart.totalQty} Qty)',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    cart.customer?.name ?? 'Walk-in Customer',
                                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(cart.total),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
