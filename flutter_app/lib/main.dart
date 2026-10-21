import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'data/models/shop.dart';
import 'data/services/supabase_service.dart';
import 'providers/auth_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/product_provider.dart';
import 'providers/customer_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';

import 'core/services/sound_service.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Sound Service
  await SoundService.instance.init();

  // Set immersive status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Supabase with local fallback
  await SupabaseService.instance.initialize();

  Shop initialShop = SupabaseService.instance.currentShop;
  String initialShopId = 'demo-shop-101';
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedShop = prefs.getString('saved_shop_data');
    if (savedShop != null) {
      final decoded = jsonDecode(savedShop) as Map<String, dynamic>;
      initialShop = Shop.fromJson(decoded);
      SupabaseService.instance.setLocalShop(initialShop);
      if (decoded['id'] != null) {
        initialShopId = decoded['id'] as String;
      }
    }
  } catch (e) {
    debugPrint("Error reading saved shop id: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ShopProvider(initialShop: initialShop)),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()..loadProducts(initialShopId)),
        ChangeNotifierProvider(create: (_) => CustomerProvider()..loadCustomers(initialShopId)),
      ],
      child: const ShopPosApp(),
    ),
  );
}

class ShopPosApp extends StatelessWidget {
  const ShopPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final shopProvider = context.watch<ShopProvider>();
    final auth = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'Shop POS — Billing, Stock & Khata',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: shopProvider.themeMode,
      home: const SplashScreen(),
    );
  }
}
