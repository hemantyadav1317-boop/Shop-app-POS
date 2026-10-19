import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
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
      _syncUserCloudData();
    }
  }

  @override
  void dispose() {
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

        final syncedShop = await SupabaseService.instance.syncUserShop(
          userId: u.id,
          userEmail: u.email ?? '',
          fallback: shopProvider.shop,
        );

        if (mounted) {
          if (syncedShop.id != shopProvider.shop.id || syncedShop.name != shopProvider.shop.name) {
            await shopProvider.setShop(syncedShop);
          }
          await productProvider.loadProducts(syncedShop.id);
          await customerProvider.loadCustomers(syncedShop.id);
          debugPrint("Cloud sync complete: Shop=${syncedShop.id} Products=${productProvider.products.length}");
        }
      }
    } catch (e) {
      debugPrint("Error syncing user cloud data on start: $e");
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
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() => _currentIndex = idx);
        },
        indicatorColor: AppColors.primarySurface,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale, color: AppColors.primary),
            label: 'Billing',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppColors.primary),
            label: 'Bills',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: AppColors.primary),
            label: 'Khata',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: AppColors.primary),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet, color: AppColors.primary),
            label: 'Daybook',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppColors.primary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
