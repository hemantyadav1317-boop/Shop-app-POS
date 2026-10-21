import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.90,
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
            body: SafeArea(
              top: false,
              child: CartPanel(
                onCompleted: () => Navigator.pop(context),
              ),
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

  void _showShareShopDialog(BuildContext context) {
    final shop = context.read<ShopProvider>().shop;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.share, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'दुकान शेयर करें / Family Access',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'अपने भाई, पिता या स्टाफ को अपनी दुकान का एक्सेस देने के लिए यह दुकान कोड साझा करें:',
              style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySurface.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('दुकान का नाम:', style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
                  Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  const Text('दुकान कोड (Shop ID):', style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
                  SelectableText(
                    shop.id,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('कोड कॉपी करें', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shop.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('दुकान कोड कॉपी हो गया!')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('WhatsApp', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final text = 'नमस्ते, हमारी दुकान "${shop.name}" का POS ऐप कोड है:\n${shop.id}\n\nऐप में लॉगिन करके "परिवार की दुकान से जुड़ें" में यह कोड डालकर दुकान कनेक्ट कर सकते हैं।';
                      final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else {
                        Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('शेयर मैसेज कॉपी हो गया!')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            // Lush Organic Indian Store Header
            // Lush Organic Indian Store Header with High Contrast Gradient Overlay
            Stack(
              children: [
                // Photographic Indian Store Background
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/pos_header_bg.jpg',
                    fit: BoxFit.cover,
                  ),
                ),

                // Green Gradient Overlay: Deep Solid Green on left behind text, smooth fade to right
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFF02190E), // Deep solid green behind text for 100% legibility
                          const Color(0xFF042F1B).withValues(alpha: 0.95),
                          const Color(0xFF064426).withValues(alpha: 0.80),
                          const Color(0xFF042716).withValues(alpha: 0.50), // Transparent shop view on right
                        ],
                        stops: const [0.0, 0.45, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),

                // Header Content
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Logo, Shop Name & Action Buttons
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Leaf Sprout Icon
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          color: Color(0xFF4ADE80),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Shop Name & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shop.name.isNotEmpty ? shop.name : 'Meri Dukan',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'POS Billing Mode • हर जरूरत का सामान, अब और आसान',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Action Buttons: Share, Bookmark, Quick Sell
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Share Button
                          InkWell(
                            onTap: () => _showShareShopDialog(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Saved Orders Button with Badge
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              InkWell(
                                onTap: () => _showSavedOrders(context),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.bookmark_outline, color: Colors.white, size: 18),
                                ),
                              ),
                              if (cart.savedCarts.isNotEmpty)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${cart.savedCarts.length}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 8),

                          // Quick Sell Pill Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00875A), // Lush Green
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            icon: const Icon(Icons.flash_on, size: 15, color: Colors.white),
                            label: const Text(
                              'Quick Sell',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
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
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Location Chip Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, size: 13, color: Color(0xFF4ADE80)),
                            const SizedBox(width: 4),
                            Text(
                              (shop.address != null && shop.address!.isNotEmpty)
                                  ? shop.address!
                                  : 'Jaipur, Rajasthan',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.white70),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

            // Content Area: Tablet Split-screen OR Mobile Grid with Floating Cart
            Expanded(
              child: isTablet
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
                  : Stack(
                      children: [
                        const ProductGrid(),

                        // Floating Pill Cart Bar at Bottom
                        if (cart.lines.isNotEmpty)
                          Positioned(
                            left: 14,
                            right: 14,
                            bottom: 12,
                            child: InkWell(
                              onTap: () => _showCartSheet(context),
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A), // Sleek Charcoal
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: const Color(0xFF00875A).withValues(alpha: 0.5),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.shopping_cart_outlined,
                                      color: Color(0xFF4ADE80),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '${cart.itemCount} Items  |  ',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            TextSpan(
                                              text: CurrencyFormatter.format(cart.total),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00875A), // Lush Green
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(22),
                                        ),
                                      ),
                                      icon: const Text(
                                        'बिल बनाएं',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      label: const Icon(Icons.arrow_forward_rounded, size: 15),
                                      onPressed: () => _showCartSheet(context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
