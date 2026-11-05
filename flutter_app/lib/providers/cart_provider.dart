import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/models/cart_item.dart';
import '../data/models/customer.dart';
import '../data/services/supabase_service.dart';
import '../core/services/sound_service.dart';

class SavedCart {
  final String id;
  final String time;
  final Customer? customer;
  final List<CartItem> items;
  final double discount;
  final String? shopId;
  final String? label;
  final DateTime? createdAt;

  SavedCart({
    required this.id,
    required this.time,
    this.customer,
    required this.items,
    this.discount = 0.0,
    this.shopId,
    this.label,
    this.createdAt,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.total);
  double get total {
    final t = subtotal - discount;
    return t > 0 ? t : 0.0;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time,
    'customer': customer?.toJson(),
    'items': items.map((i) => i.toJson()).toList(),
    'discount': discount,
    'shop_id': shopId,
    'label': label,
    'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
  };

  factory SavedCart.fromJson(Map<String, dynamic> json) {
    Customer? cust;
    if (json['customer'] != null && json['customer'] is Map) {
      cust = Customer.fromJson(Map<String, dynamic>.from(json['customer'] as Map));
    } else if (json['customer_name'] != null || json['customer_phone'] != null) {
      cust = Customer(
        id: json['customer_id'] as String? ?? '',
        shopId: json['shop_id'] as String? ?? '',
        name: json['customer_name'] as String? ?? 'Walk-in',
        phone: json['customer_phone'] as String? ?? '',
        createdAt: DateTime.now(),
      );
    }

    final rawLines = json['lines'] ?? json['items'];
    final List<CartItem> itms = [];
    if (rawLines is List) {
      for (final raw in rawLines) {
        if (raw is Map) {
          itms.add(CartItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }

    final createdAtStr = json['created_at'] as String?;
    final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
    final timeStr = json['time'] as String? ??
        (createdAt != null ? DateFormat('hh:mm a').format(createdAt.toLocal()) : '');

    return SavedCart(
      id: json['id'] as String? ?? const Uuid().v4(),
      time: timeStr.isNotEmpty ? timeStr : DateFormat('hh:mm a').format(DateTime.now()),
      customer: cust,
      items: itms,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      shopId: json['shop_id'] as String?,
      label: json['label'] as String?,
      createdAt: createdAt,
    );
  }
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _lines = [];
  Customer? _customer;
  double _discount = 0.0;
  final List<SavedCart> _savedCarts = [];
  bool _isLoadingSaved = false;
  bool _resumeLock = false;

  List<CartItem> get lines => List.unmodifiable(_lines);
  Customer? get customer => _customer;
  double get discount => _discount;
  List<SavedCart> get savedCarts => List.unmodifiable(_savedCarts);
  bool get isLoadingSaved => _isLoadingSaved;
  bool get isResumeBusy => _resumeLock;

  int get itemCount => _lines.length;

  double get totalQty => _lines.fold(0.0, (sum, item) => sum + item.qty);

  double get subtotal => _lines.fold(0.0, (sum, item) => sum + item.total);

  double get total {
    final t = subtotal - _discount;
    return t > 0 ? t : 0.0;
  }

  void addLine(CartItem item) {
    final index = _lines.indexWhere(
      (line) => (line.productId != null && line.productId == item.productId) ||
          (line.productId == null && line.name.toLowerCase() == item.name.toLowerCase()),
    );

    if (index != -1) {
      final existing = _lines[index];
      _lines[index] = existing.copyWith(
        qty: item.qty,
        price: item.price,
      );
    } else {
      _lines.add(item);
    }
    SoundService.instance.playProductAdd();
    notifyListeners();
  }

  /// Fast add or increment (+1) for barcode gun or Kirana item tap
  void incrementOrAdd(dynamic productOrItem, [double delta = 1.0]) {
    final String prodId = productOrItem.id as String;
    final String prodName = productOrItem.name as String;
    final double prodPrice = (productOrItem.price as num).toDouble();
    final String prodUnit = productOrItem.unit as String;
    final String? prodIcon = productOrItem.icon as String?;

    final index = _lines.indexWhere((line) => line.productId == prodId);
    if (index != -1) {
      final existing = _lines[index];
      _lines[index] = existing.copyWith(qty: existing.qty + delta);
    } else {
      _lines.add(CartItem(
        productId: prodId,
        name: prodName,
        price: prodPrice,
        qty: delta,
        unit: prodUnit,
        icon: prodIcon,
      ));
    }
    try {
      SoundService.instance.playProductAdd();
    } catch (_) {}
    notifyListeners();
  }

  void removeLine(String? productId, String name) {
    _lines.removeWhere(
      (line) => (line.productId != null && line.productId == productId) ||
          (line.productId == null && line.name.toLowerCase() == name.toLowerCase()),
    );
    try {
      SoundService.instance.playDelete();
    } catch (_) {}
    notifyListeners();
  }

  void setQty(String? productId, String name, double newQty) {
    if (newQty <= 0) {
      removeLine(productId, name);
      return;
    }

    final index = _lines.indexWhere(
      (line) => (line.productId != null && line.productId == productId) ||
          (line.productId == null && line.name.toLowerCase() == name.toLowerCase()),
    );

    if (index != -1) {
      _lines[index] = _lines[index].copyWith(qty: newQty);
      SoundService.instance.playButtonClick();
      notifyListeners();
    }
  }

  void setPrice(String? productId, String name, double newPrice) {
    if (newPrice < 0) return;

    final index = _lines.indexWhere(
      (line) => (line.productId != null && line.productId == productId) ||
          (line.productId == null && line.name.toLowerCase() == name.toLowerCase()),
    );

    if (index != -1) {
      _lines[index] = _lines[index].copyWith(price: newPrice);
      SoundService.instance.playButtonClick();
      notifyListeners();
    }
  }

  void setDiscount(double value) {
    _discount = value < 0 ? 0.0 : value;
    notifyListeners();
  }

  void setCustomer(Customer? cust) {
    _customer = cust;
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _customer = null;
    _discount = 0.0;
    notifyListeners();
  }

  // ===========================================================================
  // SAVED ORDERS: LOCAL (OFFLINE) + SUPABASE (CLOUD) DUAL SYNC
  // ===========================================================================

  Future<void> _persistLocalSavedCarts(String? shopId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = shopId != null && shopId.isNotEmpty ? 'saved_orders_cache_$shopId' : 'saved_orders_cache_default';
      final jsonList = _savedCarts.map((c) => c.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[CartProvider] _persistLocalSavedCarts error: $e');
    }
  }

  /// Loads saved orders from local storage immediately, then refreshes from Supabase cloud
  Future<void> loadSavedOrders(String? shopId, {bool forceCloud = false}) async {
    if (shopId == null || shopId.isEmpty) return;
    _isLoadingSaved = true;
    notifyListeners();

    try {
      // 1. Instant local load (0ms, 100% offline resilient)
      final prefs = await SharedPreferences.getInstance();
      final key = 'saved_orders_cache_$shopId';
      final cachedJson = prefs.getString(key);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        final cachedCarts = decoded.map((j) => SavedCart.fromJson(Map<String, dynamic>.from(j as Map))).toList();
        _savedCarts.clear();
        _savedCarts.addAll(cachedCarts);
        notifyListeners();
      }

      // 2. Fetch from Supabase (multi-device cloud sync)
      final cloudOrders = await SupabaseService.instance.fetchSavedOrdersFromCloud(shopId);
      if (cloudOrders.isNotEmpty || forceCloud) {
        final remoteCarts = cloudOrders.map((m) => SavedCart.fromJson(m)).toList();

        // Merge: keep any offline unsynced order and upload it
        final Map<String, SavedCart> mergedMap = {};
        for (final r in remoteCarts) {
          mergedMap[r.id] = r;
        }
        for (final l in _savedCarts) {
          if (!mergedMap.containsKey(l.id)) {
            mergedMap[l.id] = l;
            // Background push to Supabase
            SupabaseService.instance.saveOrderToCloud(
              orderId: l.id,
              shopId: shopId,
              lines: l.items.map((i) => i.toJson()).toList(),
              discount: l.discount,
              customerId: l.customer?.id,
              customerName: l.customer?.name,
              customerPhone: l.customer?.phone,
              label: l.label,
            );
          }
        }

        _savedCarts.clear();
        _savedCarts.addAll(mergedMap.values.toList());
        _savedCarts.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
        await _persistLocalSavedCarts(shopId);
      }
    } catch (e) {
      debugPrint('[CartProvider] loadSavedOrders error: $e');
    } finally {
      _isLoadingSaved = false;
      notifyListeners();
    }
  }

  /// Saves current cart locally (offline) and syncs to Supabase cloud
  Future<void> saveCurrentCart([String? shopId]) async {
    if (_lines.isEmpty) return;
    final orderId = const Uuid().v4();
    final now = DateTime.now();
    final saved = SavedCart(
      id: orderId,
      time: DateFormat('hh:mm a').format(now),
      customer: _customer,
      items: List.from(_lines),
      discount: _discount,
      shopId: shopId,
      createdAt: now,
    );

    _savedCarts.insert(0, saved);
    clear();
    await _persistLocalSavedCarts(shopId);
    notifyListeners();

    // Async push to Supabase
    if (shopId != null && shopId.isNotEmpty) {
      SupabaseService.instance.saveOrderToCloud(
        orderId: orderId,
        shopId: shopId,
        lines: saved.items.map((i) => i.toJson()).toList(),
        discount: saved.discount,
        customerId: saved.customer?.id,
        customerName: saved.customer?.name,
        customerPhone: saved.customer?.phone,
        label: saved.label,
      );
    }
  }

  /// Recalls saved cart: removes from Supabase and local cache, restores discount and customer
  Future<bool> recallCart(SavedCart saved, [String? shopId]) async {
    if (_resumeLock) return false;
    _resumeLock = true;
    notifyListeners();

    try {
      final targetShopId = shopId ?? saved.shopId;

      // 1. Remove from Supabase first (atomic removal to prevent duplicate resume)
      if (targetShopId != null && targetShopId.isNotEmpty) {
        await SupabaseService.instance.deleteSavedOrderFromCloud(saved.id);
      }

      // 2. Remove from local list and update cache
      _savedCarts.removeWhere((c) => c.id == saved.id);
      await _persistLocalSavedCarts(targetShopId);

      // 3. Restore cart items, customer and discount
      _lines.clear();
      _lines.addAll(saved.items);
      _customer = saved.customer;
      _discount = saved.discount;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[CartProvider] recallCart error: $e');
      return false;
    } finally {
      _resumeLock = false;
      notifyListeners();
    }
  }

  /// Removes saved cart from local cache and Supabase
  Future<void> removeSavedCart(String id, [String? shopId]) async {
    _savedCarts.removeWhere((c) => c.id == id);
    await _persistLocalSavedCarts(shopId);
    notifyListeners();

    // Delete from Supabase in background
    SupabaseService.instance.deleteSavedOrderFromCloud(id);
  }
}
