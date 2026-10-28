import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/update_service.dart';
import '../data/services/supabase_service.dart';
import '../providers/auth_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/product_provider.dart';
import '../providers/shop_provider.dart';
import 'pos/pos_screen.dart';
import 'bills/bills_screen.dart';
import 'customers/customers_screen.dart';
import 'inventory/inventory_screen.dart';
import 'daybook/daybook_screen.dart';
import 'settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncUserCloudData();
      UpdateService.showUpdateDialogIfNeeded(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (_authProvider != auth) {
      _authProvider?.removeListener(_onAuthChanged);
      _authProvider = auth;
      _authProvider?.addListener(_onAuthChanged);
    }
  }

  void _onAuthChanged() {
    if (mounted) {
      final auth = context.read<AuthProvider>();
      if (!auth.isAuthenticated) {
        SupabaseService.instance.unsubscribeFromShopChanges();
        context.read<ShopProvider>().resetToGuest();
      } else {
        _syncUserCloudData();
      }
    }
  }

  @override
  void dispose() {
    SupabaseService.instance.unsubscribeFromShopChanges();
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> _syncUserCloudData() async {
    try {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final u = auth.user;
      if (u != null) {
        debugPrint("Syncing user cloud data for: ${u.email} (id: ${u.id})");
        final shopProvider = context.read<ShopProvider>();
        final productProvider = context.read<ProductProvider>();
        final customerProvider = context.read<CustomerProvider>();

        final syncedShop = await shopProvider.loadForUser(u.id, email: u.email);

        if (mounted) {
          await productProvider.loadProducts(syncedShop.id);
          await customerProvider.loadCustomers(syncedShop.id);
          debugPrint("Cloud sync complete: Shop=${syncedShop.id} Products=${productProvider.products.length}");

          // Establish Real-time WebSocket listener across all devices
          SupabaseService.instance.subscribeToShopChanges(
            shopId: syncedShop.id,
            onEvent: (table, eventType, record) {
              if (!mounted) return;
              debugPrint('[MainShell] Real-time live event on: $table ($eventType)');
              if (table == 'products') {
                context.read<ProductProvider>().loadProducts(syncedShop.id);
              } else if (table == 'customers' || table == 'customer_transactions') {
                context.read<CustomerProvider>().loadCustomers(syncedShop.id);
              } else if (table == 'sales') {
                SupabaseService.instance.getSales(syncedShop.id);
              }
            },
          );
        }
      }
    } catch (e) {
      debugPrint("Error syncing user cloud data on start: $e");
    }
  }

  void _onNavigationChanged(int index) {
    SoundService.instance.playButtonClick();
    setState(() => _currentIndex = index);

    final shop = context.read<ShopProvider>().shop;
    if (shop.id != 'demo-shop-101') {
      if (index == 2) {
        // Khata / Customers
        context.read<CustomerProvider>().loadCustomers(shop.id);
      } else if (index == 3) {
        // Inventory / Stock
        context.read<ProductProvider>().loadProducts(shop.id);
      } else if (index == 1) {
        // Bills
        SupabaseService.instance.getSales(shop.id);
      }
    }
  }

  final List<Widget> _screens = const [
    PosScreen(),
    BillsScreen(),
    CustomersScreen(),
    InventoryScreen(),
    DaybookScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 768;

    if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onNavigationChanged,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront, color: Colors.white, size: 26),
                ),
              ),
              selectedIconTheme: const IconThemeData(color: AppColors.primary),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: AppColors.lightTextSecondary,
                fontSize: 11,
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.point_of_sale_outlined),
                  selectedIcon: Icon(Icons.point_of_sale),
                  label: Text('Billing'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: Text('Bills'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Khata'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text('Stock'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: Text('Daybook'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
            Expanded(child: _screens[_currentIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          height: 64,
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedIndex: _currentIndex,
          onDestinationSelected: _onNavigationChanged,
          indicatorColor: const Color(0xFFE8F5E9), // Light green capsule pill
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF00875A)),
              label: 'होम',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded, color: Color(0xFF00875A)),
              label: 'बिल्स',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_alt_outlined),
              selectedIcon: Icon(Icons.people_alt_rounded, color: Color(0xFF00875A)),
              label: 'खाता',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded, color: Color(0xFF00875A)),
              label: 'स्टॉक',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded, color: Color(0xFF00875A)),
              label: 'डे-बुक',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFF00875A)),
              label: 'सेटिंग्स',
            ),
          ],
        ),
      ),
    );
  }
}
