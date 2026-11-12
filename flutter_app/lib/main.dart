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
import 'providers/weighing_scale_provider.dart';
import 'providers/ai_vision_provider.dart';
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
    var savedShop = prefs.getString('saved_shop_data');
    if (savedShop == null) {
      for (final key in prefs.getKeys()) {
        if (key.startsWith('saved_shop_data_') && key != 'saved_shop_data_guest') {
          final candidate = prefs.getString(key);
          if (candidate != null && candidate.isNotEmpty) {
            savedShop = candidate;
            break;
          }
        }
      }
    }
    if (savedShop != null) {
      final decoded = jsonDecode(savedShop) as Map<String, dynamic>;
      initialShop = Shop.fromJson(decoded);
      final localUpi = prefs.getString('shop_upi_id');
      final localQr = prefs.getString('shop_qr_image_url');
      final localReviewUrl = prefs.getString('shop_google_review_url');
      if ((initialShop.upiId == null || initialShop.upiId!.isEmpty) && localUpi != null && localUpi.isNotEmpty) {
        initialShop = initialShop.copyWith(upiId: localUpi);
      }
      if ((initialShop.qrImageUrl == null || initialShop.qrImageUrl!.isEmpty) && localQr != null && localQr.isNotEmpty) {
        initialShop = initialShop.copyWith(qrImageUrl: localQr);
      }
      if ((initialShop.googleReviewUrl == null || initialShop.googleReviewUrl!.isEmpty) &&
          localReviewUrl != null &&
          localReviewUrl.isNotEmpty) {
        initialShop = initialShop.copyWith(googleReviewUrl: localReviewUrl);
      }
      SupabaseService.instance.setLocalShop(initialShop);
      if (decoded['id'] != null) {
        initialShopId = decoded['id'] as String;
      }
    } else {
      final name = prefs.getString('shop_name');
      if (name != null && name.trim().isNotEmpty && name != 'मेरी दुकान (My Store)') {
        initialShop = initialShop.copyWith(
          name: name,
          phone: prefs.getString('shop_phone'),
          address: prefs.getString('shop_address'),
          gstin: prefs.getString('shop_gstin'),
          upiId: prefs.getString('shop_upi_id'),
          upiPayeeName: prefs.getString('shop_upi_payee_name'),
          qrImageUrl: prefs.getString('shop_qr_image_url'),
          googleReviewUrl: prefs.getString('shop_google_review_url'),
          storeType: prefs.getString('shop_store_type') ?? 'vegetable',
        );
        SupabaseService.instance.setLocalShop(initialShop);
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
        ChangeNotifierProvider(create: (_) => WeighingScaleProvider()),
        ChangeNotifierProvider(create: (_) => AiVisionProvider()),
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
