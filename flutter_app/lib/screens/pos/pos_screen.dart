import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/services/sound_service.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/weighing_scale_provider.dart';
import '../../providers/ai_vision_provider.dart';
import '../settings/weighing_scale_settings_screen.dart';
import 'widgets/product_grid.dart';
import 'widgets/cart_panel.dart';
import 'widgets/quick_sale_keypad.dart';
import 'widgets/ai_vision_overlay.dart';
import 'kirana_pos_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  int _activeTab = 0; // 0: Sale, 1: Quick Sale, 2: Saved Orders

  void _showCartSheet(BuildContext context) {
    SoundService.instance.playButtonClick();
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
              title: const Text('Current Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  void _showQuickStoreModeSheet(BuildContext context) {
    SoundService.instance.playButtonClick();
    final shopProvider = context.read<ShopProvider>();
    final currentType = shopProvider.storeType;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.storefront_rounded, color: Color(0xFF00875A), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Switch Store Mode',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStoreModeTile(
                ctx,
                shopProvider,
                id: 'vegetable',
                title: '🥬 Vegetable & Fruit Store',
                subtitle: 'Weight-based (Kg/Gram), Touchscreen Counter',
                isSelected: currentType == 'vegetable',
                color: const Color(0xFF00875A),
              ),
              const SizedBox(height: 8),
              _buildStoreModeTile(
                ctx,
                shopProvider,
                id: 'kirana',
                title: '🛒 Grocery & Kirana Store',
                subtitle: 'Barcode Gun, 2026 FMCG Catalog, MRP & Profit',
                isSelected: currentType == 'kirana',
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(height: 8),
              _buildStoreModeTile(
                ctx,
                shopProvider,
                id: 'other',
                title: '📦 General Retail & Other Store',
                subtitle: 'Standard Point of Sale with Item Catalog',
                isSelected: currentType == 'other',
                color: const Color(0xFF6366F1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreModeTile(
    BuildContext ctx,
    ShopProvider shopProvider, {
    required String id,
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color color,
  }) {
    return InkWell(
      onTap: () async {
        SoundService.instance.playButtonClick();
        HapticFeedback.mediumImpact();
        await shopProvider.setStoreType(id);
        if (ctx.mounted) Navigator.pop(ctx);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.25),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? color : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? color : Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>().shop;
    if (shop.isKiranaMode) {
      return const KiranaPosScreen();
    }
    final cart = context.watch<CartProvider>();
    final isTablet = MediaQuery.of(context).size.width >= 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scale = context.watch<WeighingScaleProvider>();
    final ai = context.watch<AiVisionProvider>();
    if (ai.isAiVisionActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<AiVisionProvider>().onScaleReadingChanged(
            weight: scale.liveWeight,
            isStable: scale.isStable,
            productProvider: context.read<ProductProvider>(),
            cartProvider: context.read<CartProvider>(),
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      bottomNavigationBar: _buildBottomTabBar(isDark, cart),
      body: SafeArea(
        top: true,
        child: Stack(
          children: [
            Column(
              children: [
            // Lush Organic Indian Store Header
            Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/pos_header_bg.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFF02190E),
                          const Color(0xFF042F1B).withValues(alpha: 0.95),
                          const Color(0xFF064426).withValues(alpha: 0.80),
                          const Color(0xFF042716).withValues(alpha: 0.50),
                        ],
                        stops: const [0.0, 0.45, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          color: Color(0xFF4ADE80),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              shop.name.isNotEmpty ? shop.name : 'Meri Dukan',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            InkWell(
                              onTap: () => _showQuickStoreModeSheet(context),
                              borderRadius: BorderRadius.circular(6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    shop.storeType == 'kirana'
                                        ? '🛒 Kirana Mode'
                                        : (shop.storeType == 'other' ? '📦 Other Retail' : '🥬 Vegetable Mode'),
                                    style: const TextStyle(
                                      color: Color(0xFF4ADE80),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: Color(0xFF4ADE80), size: 14),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Consumer<WeighingScaleProvider>(
                            builder: (context, scale, _) {
                              return InkWell(
                                onTap: () {
                                  SoundService.instance.playButtonClick();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const WeighingScaleSettingsScreen()),
                                  );
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: scale.isConnected
                                        ? const Color(0xFF10B981).withValues(alpha: 0.25)
                                        : Colors.white.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: scale.isConnected
                                          ? const Color(0xFF10B981)
                                          : Colors.white24,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.scale_rounded,
                                        color: scale.isConnected
                                            ? const Color(0xFF34D399)
                                            : Colors.white70,
                                        size: 15,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        scale.isConnected
                                            ? '${scale.liveWeight.toStringAsFixed(3)} kg'
                                            : 'Scale',
                                        style: TextStyle(
                                          color: scale.isConnected
                                              ? const Color(0xFF34D399)
                                              : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          fontFamily: scale.isConnected
                                              ? 'monospace'
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Consumer<AiVisionProvider>(
                            builder: (context, aiProvider, _) {
                              return InkWell(
                                onTap: () {
                                  SoundService.instance.playButtonClick();
                                  aiProvider.toggleAiVision();
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: aiProvider.isAiVisionActive
                                        ? const Color(0xFF06B6D4).withValues(alpha: 0.25)
                                        : Colors.white.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: aiProvider.isAiVisionActive
                                          ? const Color(0xFF06B6D4)
                                          : Colors.white24,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.camera_alt_rounded,
                                        color: aiProvider.isAiVisionActive
                                            ? const Color(0xFF22D3EE)
                                            : Colors.white70,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        aiProvider.isAiVisionActive ? 'AI ON' : 'AI',
                                        style: TextStyle(
                                          color: aiProvider.isAiVisionActive
                                              ? const Color(0xFF22D3EE)
                                              : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              SoundService.instance.playButtonClick();
                              final sp = context.read<ShopProvider>();
                              sp.setThemeMode(sp.isDarkMode ? ThemeMode.light : ThemeMode.dark);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                context.watch<ShopProvider>().isDarkMode
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                                color: Colors.white,
                                size: 17,
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

            // Content Area: Tablet Split-screen OR Mobile with Floating Cart
            Expanded(
              child: _buildMainContent(isTablet, isDark, cart),
            ),
          ],
        ),
        const AiVisionOverlay(),
      ],
    ),
  ),
);
  }

  Widget _buildMainContent(bool isTablet, bool isDark, CartProvider cart) {
    Widget activeView;
    if (_activeTab == 0) {
      activeView = const ProductGrid();
    } else if (_activeTab == 1) {
      activeView = QuickSaleKeypad(
        onItemAdded: () {
          if (!isTablet) {
            // Give subtle haptic feedback on mobile
            HapticFeedback.lightImpact();
          }
        },
      );
    } else {
      activeView = _buildSavedOrdersInline(cart, isDark);
    }

    if (isTablet) {
      return Row(
        children: [
          Expanded(
            flex: 65,
            child: activeView,
          ),
          VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
          const Expanded(
            flex: 35,
            child: CartPanel(),
          ),
        ],
      );
    }

    return Stack(
      children: [
        activeView,

        // Floating Cart Bar for Mobile
        if (cart.lines.isNotEmpty)
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: InkWell(
              onTap: () {
                SoundService.instance.playButtonClick();
                _showCartSheet(context);
              },
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
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
                        backgroundColor: const Color(0xFF00875A),
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
                      onPressed: () {
                        SoundService.instance.playButtonClick();
                        _showCartSheet(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // BOTTOM NAVIGATION BAR (Image 2 Patti)
  // ==========================================
  Widget _buildBottomTabBar(bool isDark, CartProvider cart) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 🛒 Tab 0: Sale (Product Catalog)
          Expanded(
            child: _buildBottomTabItem(
              index: 0,
              label: 'Sale',
              icon: Icons.storefront_outlined,
              activeIcon: Icons.storefront_rounded,
              isDark: isDark,
            ),
          ),

          // ⚡ Tab 1: Quick Sale (Keypad)
          Expanded(
            child: _buildBottomTabItem(
              index: 1,
              label: 'Quick Sale',
              icon: Icons.flash_on_outlined,
              activeIcon: Icons.flash_on_rounded,
              isDark: isDark,
            ),
          ),

          // ⏱️ Tab 2: Saved Orders
          Expanded(
            child: _buildBottomTabItem(
              index: 2,
              label: 'Saved Orders',
              icon: Icons.bookmark_border_rounded,
              activeIcon: Icons.bookmark_rounded,
              badgeCount: cart.savedCarts.length,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTabItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    int badgeCount = 0,
    required bool isDark,
  }) {
    final isSelected = _activeTab == index;
    const primaryColor = Color(0xFF00875A);

    return InkWell(
      onTap: () {
        SoundService.instance.playButtonClick();
        setState(() => _activeTab = index);
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? primaryColor.withValues(alpha: 0.2) : primaryColor.withValues(alpha: 0.1))
              : Colors.transparent,
          border: Border(
            top: BorderSide(
              color: isSelected ? primaryColor : Colors.transparent,
              width: 3.0,
            ),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 20,
                  color: isSelected ? primaryColor : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? (isDark ? Colors.white : primaryColor) : Colors.grey,
                  ),
                ),
              ],
            ),
            if (badgeCount > 0)
              Positioned(
                top: -6,
                right: -16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SAVED ORDERS INLINE VIEW
  // ==========================================
  Widget _buildSavedOrdersInline(CartProvider cart, bool isDark) {
    if (cart.savedCarts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_outline_rounded, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No Saved Orders',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Orders placed on hold will appear here for instant recall',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() => _activeTab = 0),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back to Sale'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saved / Held Orders (${cart.savedCarts.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _activeTab = 0),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to Sale'),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView.separated(
              itemCount: cart.savedCarts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final saved = cart.savedCarts[i];
                final total = saved.items.fold(0.0, (sum, it) => sum + it.total) - saved.discount;

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF00875A).withValues(alpha: 0.15),
                      child: const Icon(Icons.receipt_long, color: Color(0xFF00875A)),
                    ),
                    title: Text(
                      saved.customer?.name ?? 'Walk-in Customer',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${saved.items.length} Items · Saved at ${saved.time}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          CurrencyFormatter.format(total),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF00875A)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            SoundService.instance.playButtonClick();
                            cart.recallCart(saved);
                            setState(() => _activeTab = 0);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00875A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Recall'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                          tooltip: 'Delete',
                          onPressed: () {
                            SoundService.instance.playDelete();
                            cart.removeSavedCart(saved.id);
                          },
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
    );
  }
}
