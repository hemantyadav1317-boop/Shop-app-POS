import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/shop.dart';
import '../data/services/supabase_service.dart';

class ShopProvider extends ChangeNotifier {
  Shop _shop = SupabaseService.instance.currentShop;
  ThemeMode _themeMode = ThemeMode.system;

  Shop get shop => _shop;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ShopProvider() {
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
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_shop_data', jsonEncode(updated.toJson()));
    await SupabaseService.instance.updateShop(updated);
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
