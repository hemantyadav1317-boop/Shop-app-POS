import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/shop.dart';
import '../data/services/supabase_service.dart';

class ShopProvider extends ChangeNotifier {
  late Shop _shop;
  ThemeMode _themeMode = ThemeMode.system;
  bool _showProductBadges = false; // Default: OFF (Hidden)
  String? _currentUserId;

  Shop get shop => _shop;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get showProductBadges => _showProductBadges;
  String get storeType => _shop.storeType;
  bool get isKiranaMode => _shop.storeType == 'kirana';
  bool get isVegetableMode => _shop.storeType == 'vegetable';
  bool get isMixMode => _shop.storeType == 'mix';

  static Shop get defaultShop => Shop(
        id: 'demo-shop-101',
        name: 'मेरी दुकान (My Store)',
        phone: null,
        address: null,
        gstin: null,
        upiId: null,
        upiPayeeName: null,
        allowNegativeStock: false,
        printPaperSize: '58mm',
        receiptFooter: 'धन्यवाद! फिर पधारें 🙏',
        qrImageUrl: null,
      );

  static String _shopStorageKey(String? uid) {
    if (uid != null && uid.trim().isNotEmpty) {
      return 'saved_shop_data_${uid.trim()}';
    }
    return 'saved_shop_data_guest';
  }

  ShopProvider({Shop? initialShop}) {
    _shop = initialShop ?? defaultShop;
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

    _showProductBadges = prefs.getBool('show_product_badges') ?? false;

    // Load user-specific shop or guest shop
    final key = _shopStorageKey(_currentUserId);
    final savedShopJson = prefs.getString(key);
    if (savedShopJson != null) {
      try {
        final decoded = jsonDecode(savedShopJson) as Map<String, dynamic>;
        _shop = Shop.fromJson(decoded);
        if (decoded['store_type'] == null) {
          final fallbackStoreType = prefs.getString('shop_store_type');
          if (fallbackStoreType != null) {
            _shop = _shop.copyWith(storeType: fallbackStoreType);
          }
        }
        SupabaseService.instance.setLocalShop(_shop);
      } catch (e) {
        debugPrint("Error decoding saved shop: $e");
      }
    }

    notifyListeners();
  }

  Future<Shop> loadForUser(String? userId, {String? defaultName, String? email}) async {
    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    final key = _shopStorageKey(userId);
    final savedShopJson = prefs.getString(key);

    if (savedShopJson != null) {
      try {
        final decoded = jsonDecode(savedShopJson) as Map<String, dynamic>;
        _shop = Shop.fromJson(decoded);
        if (_shop.id.startsWith('shop-')) {
          _shop = _shop.copyWith(id: _shop.id.replaceFirst('shop-', ''));
        }
        SupabaseService.instance.setLocalShop(_shop);
        notifyListeners();
      } catch (e) {
        debugPrint("Error decoding user shop: $e");
      }
    }

    // Authoritatively resolve and sync user's cloud shop
    if (userId != null && userId.isNotEmpty) {
      try {
        final cloudShop = await SupabaseService.instance.syncUserShop(
          userId: userId,
          userEmail: email ?? '',
          fallback: _shop,
        );
        _shop = cloudShop;
        SupabaseService.instance.setLocalShop(cloudShop);
        await prefs.setString(key, jsonEncode(cloudShop.toJson()));
        await prefs.setString('saved_shop_data', jsonEncode(cloudShop.toJson()));
        notifyListeners();
        return cloudShop;
      } catch (e) {
        debugPrint("Error resolving cloud shop in loadForUser: $e");
      }
    }

    return _shop;
  }

  Future<void> resetToGuest() async {
    _currentUserId = null;
    final prefs = await SharedPreferences.getInstance();

    // Preserve previously configured shop data from local preferences if present
    final cached = prefs.getString('saved_shop_data') ?? prefs.getString('saved_shop_data_guest');
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final restored = Shop.fromJson(decoded);
        if (restored.id != 'demo-shop-101' && restored.name != 'मेरी दुकान (My Store)') {
          _shop = restored;
          SupabaseService.instance.setLocalShop(_shop);
          notifyListeners();
          return;
        }
      } catch (_) {}
    }

    final shopName = prefs.getString('shop_name');
    if (shopName != null && shopName.trim().isNotEmpty && shopName != 'मेरी दुकान (My Store)') {
      _shop = _shop.copyWith(
        name: shopName,
        phone: prefs.getString('shop_phone') ?? _shop.phone,
        address: prefs.getString('shop_address') ?? _shop.address,
        gstin: prefs.getString('shop_gstin') ?? _shop.gstin,
        upiId: prefs.getString('shop_upi_id') ?? _shop.upiId,
        upiPayeeName: prefs.getString('shop_upi_payee_name') ?? _shop.upiPayeeName,
        qrImageUrl: prefs.getString('shop_qr_image_url') ?? _shop.qrImageUrl,
      );
      SupabaseService.instance.setLocalShop(_shop);
      notifyListeners();
      return;
    }

    _shop = defaultShop;
    SupabaseService.instance.setLocalShop(_shop);
    notifyListeners();
  }

  Future<void> setShowProductBadges(bool value) async {
    _showProductBadges = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_product_badges', value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode == ThemeMode.dark ? 'dark' : (mode == ThemeMode.light ? 'light' : 'system'));
  }

  Future<void> setStoreType(String type) async {
    if (_shop.storeType == type) return;
    final updated = _shop.copyWith(storeType: type);
    await updateShop(updated);
  }

  Future<void> setShop(Shop shop) async {
    _shop = shop;
    SupabaseService.instance.setLocalShop(shop);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final key = _shopStorageKey(_currentUserId);
    await prefs.setString(key, jsonEncode(shop.toJson()));
    await prefs.setString('saved_shop_data', jsonEncode(shop.toJson()));
  }

  Future<void> updateShop(Shop updated) async {
    _shop = updated;
    SupabaseService.instance.setLocalShop(updated);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final key = _shopStorageKey(_currentUserId);
    await prefs.setString(key, jsonEncode(updated.toJson()));
    await prefs.setString('saved_shop_data', jsonEncode(updated.toJson()));

    // Keep primary SharedPreferences keys updated for backward compatibility
    await prefs.setString('shop_name', updated.name);
    if (updated.phone != null && updated.phone!.trim().isNotEmpty) {
      await prefs.setString('shop_phone', updated.phone!.trim());
    } else {
      await prefs.remove('shop_phone');
    }

    if (updated.address != null && updated.address!.trim().isNotEmpty) {
      await prefs.setString('shop_address', updated.address!.trim());
    } else {
      await prefs.remove('shop_address');
    }

    if (updated.gstin != null && updated.gstin!.trim().isNotEmpty) {
      await prefs.setString('shop_gstin', updated.gstin!.trim());
    } else {
      await prefs.remove('shop_gstin');
    }

    if (updated.upiId != null && updated.upiId!.trim().isNotEmpty) {
      await prefs.setString('shop_upi_id', updated.upiId!.trim());
    } else {
      await prefs.remove('shop_upi_id');
    }

    if (updated.upiPayeeName != null && updated.upiPayeeName!.trim().isNotEmpty) {
      await prefs.setString('shop_upi_payee_name', updated.upiPayeeName!.trim());
    } else {
      await prefs.remove('shop_upi_payee_name');
    }

    if (updated.receiptFooter != null && updated.receiptFooter!.trim().isNotEmpty) {
      await prefs.setString('shop_receipt_footer', updated.receiptFooter!.trim());
    } else {
      await prefs.remove('shop_receipt_footer');
    }

    await prefs.setString('shop_paper_size', updated.printPaperSize);
    await prefs.setBool('shop_allow_negative_stock', updated.allowNegativeStock);
    await prefs.setString('shop_store_type', updated.storeType);

    if (updated.qrImageUrl != null && updated.qrImageUrl!.trim().isNotEmpty) {
      await prefs.setString('shop_qr_image_url', updated.qrImageUrl!.trim());
    } else {
      await prefs.remove('shop_qr_image_url');
    }

    final synced = await SupabaseService.instance.updateShop(updated);
    if (synced.id != _shop.id) {
      _shop = synced;
      await prefs.setString(key, jsonEncode(synced.toJson()));
      await prefs.setString('saved_shop_data', jsonEncode(synced.toJson()));
      notifyListeners();
    }
  }

  Future<Shop> joinShop(String shopCode) async {
    final joined = await SupabaseService.instance.joinShop(shopCode);
    _shop = joined;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final key = _shopStorageKey(_currentUserId);
    await prefs.setString(key, jsonEncode(joined.toJson()));

    await prefs.setString('shop_name', joined.name);
    if (joined.phone != null) await prefs.setString('shop_phone', joined.phone!);
    if (joined.address != null) await prefs.setString('shop_address', joined.address!);
    if (joined.gstin != null) await prefs.setString('shop_gstin', joined.gstin!);
    if (joined.upiId != null) await prefs.setString('shop_upi_id', joined.upiId!);
    if (joined.upiPayeeName != null) await prefs.setString('shop_upi_payee_name', joined.upiPayeeName!);
    if (joined.receiptFooter != null) await prefs.setString('shop_receipt_footer', joined.receiptFooter!);
    await prefs.setString('shop_paper_size', joined.printPaperSize);
    await prefs.setBool('shop_allow_negative_stock', joined.allowNegativeStock);
    if (joined.qrImageUrl != null) await prefs.setString('shop_qr_image_url', joined.qrImageUrl!);

    return joined;
  }

  Future<Shop> joinShopAsStaff({
    required String phone,
    required String pin,
    String? qrPayload,
    String? staffName,
    String? staffRole,
  }) async {
    final joined = await SupabaseService.instance.verifyAndJoinStaff(
      phone: phone,
      pin: pin,
      qrPayload: qrPayload,
      staffName: staffName,
      staffRole: staffRole,
    );
    _shop = joined;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final key = _shopStorageKey(_currentUserId);
    await prefs.setString(key, jsonEncode(joined.toJson()));
    return joined;
  }

  Future<String> generateNewShareCode() async {
    final code = await SupabaseService.instance.generateShopShareCode(_shop.id);
    _shop = _shop.copyWith(shareCode: code);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final key = _shopStorageKey(_currentUserId);
    await prefs.setString(key, jsonEncode(_shop.toJson()));
    return code;
  }
}
