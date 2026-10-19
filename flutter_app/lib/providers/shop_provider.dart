import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/shop.dart';
import '../data/services/supabase_service.dart';

class ShopProvider extends ChangeNotifier {
  late Shop _shop;
  ThemeMode _themeMode = ThemeMode.system;

  Shop get shop => _shop;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ShopProvider({Shop? initialShop}) {
    _shop = initialShop ?? SupabaseService.instance.currentShop;
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('theme_mode');
    if (themeStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (themeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }

    final savedShopJson = prefs.getString('saved_shop_data');
    if (savedShopJson != null) {
      try {
        final decoded = jsonDecode(savedShopJson) as Map<String, dynamic>;
        _shop = Shop.fromJson(decoded);
        SupabaseService.instance.setLocalShop(_shop);
      } catch (e) {
        debugPrint("Error decoding saved shop: $e");
      }
    }

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode == ThemeMode.dark ? 'dark' : (mode == ThemeMode.light ? 'light' : 'system'));
  }

  Future<void> updateShop(Shop updated) async {
    _shop = updated;
    SupabaseService.instance.setLocalShop(updated);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_shop_data', jsonEncode(updated.toJson()));
    await prefs.setString('shop_name', updated.name);
    if (updated.phone != null) await prefs.setString('shop_phone', updated.phone!);
    if (updated.address != null) await prefs.setString('shop_address', updated.address!);
    if (updated.gstin != null) await prefs.setString('shop_gstin', updated.gstin!);
    if (updated.upiId != null) await prefs.setString('shop_upi_id', updated.upiId!);
    if (updated.upiPayeeName != null) await prefs.setString('shop_upi_payee_name', updated.upiPayeeName!);
    if (updated.receiptFooter != null) await prefs.setString('shop_receipt_footer', updated.receiptFooter!);
    await prefs.setString('shop_paper_size', updated.printPaperSize);
    await prefs.setBool('shop_allow_negative_stock', updated.allowNegativeStock);
    if (updated.qrImageUrl != null) await prefs.setString('shop_qr_image_url', updated.qrImageUrl!);

    final synced = await SupabaseService.instance.updateShop(updated);
    if (synced.id != _shop.id) {
      _shop = synced;
      await prefs.setString('saved_shop_data', jsonEncode(synced.toJson()));
      notifyListeners();
    }
  }

  Future<Shop> joinShop(String shopCode) async {
    final joined = await SupabaseService.instance.joinShop(shopCode);
    _shop = joined;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_shop_data', jsonEncode(joined.toJson()));
    return joined;
  }
}
