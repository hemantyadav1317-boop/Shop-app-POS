import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/models/category.dart';
import '../data/models/product.dart';
import '../data/models/cart_item.dart';
import '../data/models/sale.dart';
import '../data/services/local_db_service.dart';
import '../data/services/supabase_service.dart';
import '../core/constants/aliases.dart';

class ProductProvider extends ChangeNotifier {
  static const List<String> defaultCategories = [];

  static const Map<String, String> defaultCategoryImages = {
    'VEGETABLES': 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=120&q=80',
    'FRUITS': 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?w=120&q=80',
    'DAIRY': 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=120&q=80',
    'GRAINS': 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=120&q=80',
    'SNACKS': 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=120&q=80',
    'BEVERAGES': 'https://images.unsplash.com/photo-1527661591475-527312dd65f5?w=120&q=80',
    'SPICES': 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=120&q=80',
    'PERSONAL CARE': 'https://images.unsplash.com/photo-1556228720-195a672e8a03?w=120&q=80',
    'GENERAL': 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=120&q=80',
  };

  List<Product> _products = [];
  final List<Category> _normalizedCategories = [];
  final List<String> _customCategories = [];
  final Set<String> _deletedCategories = {};
  final Map<String, String> _categoryImages = {};
  final Map<String, double> _productSalesQty = {};
  final Map<String, double> _categorySalesQty = {};
  String _activeShopId = 'demo-shop-101';
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  Map<String, dynamic> exportCategoriesConfig() => {
        'custom_categories': List<String>.from(_customCategories),
        'deleted_categories': _deletedCategories.toList(),
        'category_images': Map<String, String>.from(_categoryImages),
      };

  Future<void> _syncCategoriesToDoubleLayer([String? shopId]) async {
    final targetId = shopId ??
        (_activeShopId != 'demo-shop-101'
            ? _activeShopId
            : SupabaseService.instance.currentShop.id);
    await SupabaseService.instance
        .saveCategoriesConfig(targetId, exportCategoriesConfig());
  }

  Future<void> restoreCategoriesConfig(Map<String, dynamic> config) async {
    final custom = (config['custom_categories'] as List?)
            ?.map((e) => e.toString().trim().toUpperCase())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];
    final deleted = (config['deleted_categories'] as List?)
            ?.map((e) => e.toString().trim().toUpperCase())
            .where((e) => e.isNotEmpty)
            .toSet() ??
        {};
    final images = (config['category_images'] as Map?)
            ?.map((k, v) => MapEntry(k.toString().toUpperCase(), v.toString())) ??
        {};

    _customCategories
      ..clear()
      ..addAll(custom);
    _deletedCategories
      ..clear()
      ..addAll(deleted);
    _categoryImages
      ..clear()
      ..addAll(images);

    await _saveCustomCategories();
    await _saveDeletedCategories();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pos_category_images', jsonEncode(_categoryImages));
    notifyListeners();
  }

  ProductProvider() {
    _loadCustomCategories();
    _loadDeletedCategories();
    _loadCategoryImages();
  }

  String? getCategoryImage(String category) {
    final upper = category.trim().toUpperCase();
    if (_categoryImages.containsKey(upper) && _categoryImages[upper]!.isNotEmpty) {
      return _categoryImages[upper];
    }
    return defaultCategoryImages[upper];
  }

  Future<void> setCategoryImage(String category, String imageUrl) async {
    final upper = category.trim().toUpperCase();
    if (imageUrl.trim().isEmpty) {
      _categoryImages.remove(upper);
    } else {
      _categoryImages[upper] = imageUrl.trim();
    }
    await _saveCategoryImages();
    await _syncCategoriesToDoubleLayer();
    notifyListeners();
  }

  Future<void> _loadCategoryImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('pos_category_images');
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          _categoryImages.clear();
          decoded.forEach((k, v) {
            if (v is String) _categoryImages[k.toString().toUpperCase()] = v;
          });
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error loading category images: $e");
    }
  }

  Future<void> _saveCategoryImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pos_category_images', jsonEncode(_categoryImages));
    } catch (e) {
      debugPrint("Error saving category images: $e");
    }
  }

  Future<void> _loadCustomCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('custom_categories');
      if (saved != null) {
        _customCategories.clear();
        _customCategories.addAll(saved);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading custom categories: $e");
    }
  }

  Future<void> _saveCustomCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('custom_categories', _customCategories);
    } catch (e) {
      debugPrint("Error saving custom categories: $e");
    }
  }

  Future<void> _loadDeletedCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('pos_deleted_categories');
      if (saved != null) {
        _deletedCategories.clear();
        _deletedCategories.addAll(saved.map((e) => e.toUpperCase()));
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading deleted categories: $e");
    }
  }

  Future<void> _saveDeletedCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pos_deleted_categories', _deletedCategories.toList());
    } catch (e) {
      debugPrint("Error saving deleted categories: $e");
    }
  }

  /// List of all categories without 'All' (used in product add/edit dropdown & category management)
  /// Sorted by most selling / popularity first, then alphabetical
  List<String> get allCategories {
    final set = <String>{};
    for (final c in _normalizedCategories) {
      final upper = c.name.trim().toUpperCase();
      if (c.isActive && upper.isNotEmpty && upper != 'ALL' && !_deletedCategories.contains(upper)) {
        set.add(upper);
      }
    }
    for (final c in _customCategories) {
      final upper = c.toUpperCase();
      if (!_deletedCategories.contains(upper)) {
        set.add(upper);
      }
    }
    for (final p in _products) {
      if (p.category.trim().isNotEmpty && p.category.toLowerCase() != 'all') {
        final upper = p.category.trim().toUpperCase();
        if (!_deletedCategories.contains(upper)) {
          set.add(upper);
        }
      }
    }
    final list = set.toList();
    list.sort((a, b) {
      final qtyA = _categorySalesQty[a] ?? 0.0;
      final qtyB = _categorySalesQty[b] ?? 0.0;
      if (qtyB != qtyA) {
        return qtyB.compareTo(qtyA); // Most sold category first
      }
      return a.compareTo(b); // Alphabetical tie-breaker
    });
    return list;
  }

  /// List of categories with 'All' at the start (used in billing & filters)
  List<String> get categories => ['All', ...allCategories];

  /// Get number of products under a category
  int getProductCountForCategory(String cat) {
    if (cat == 'All') return _products.length;
    final catUpper = cat.toUpperCase();
    return _products.where((p) => p.category.trim().toUpperCase() == catUpper).length;
  }

  List<Product> get filteredProducts {
    final list = _products.where((p) {
      final matchesCat = _selectedCategory == 'All' ||
          p.category.trim().toUpperCase() == _selectedCategory.trim().toUpperCase();
      final matchesSearch = ProductAliases.matches(p.name, p.category, p.barcode, _searchQuery);
      return matchesCat && matchesSearch;
    }).toList();

    // Sort by sales popularity: most sold products appear first, then alphabetical
    list.sort((a, b) {
      final qtyA = _productSalesQty[a.id] ?? 0.0;
      final qtyB = _productSalesQty[b.id] ?? 0.0;
      if (qtyB != qtyA) {
        return qtyB.compareTo(qtyA); // Descending popularity
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase()); // Alphabetical tie-breaker
    });
    return list;
  }

  Future<void> loadProducts(String shopId) async {
    _isLoading = true;
    _activeShopId = shopId;
    notifyListeners();

    // Load & merge cloud/SQLite categories config FIRST so deleted categories stay suppressed
    try {
      final localCats = await LocalDbService.instance.getCategories(shopId);
      _normalizedCategories
        ..clear()
        ..addAll(localCats);
    } catch (_) {}

    try {
      final remoteCfg = await SupabaseService.instance.getCategoriesConfig(shopId);
      if (remoteCfg.isNotEmpty) {
        final remoteDeleted = (remoteCfg['deleted_categories'] as List?)
                ?.map((e) => e.toString().trim().toUpperCase())
                .where((e) => e.isNotEmpty)
                .toSet() ??
            {};
        final remoteCustom = (remoteCfg['custom_categories'] as List?)
                ?.map((e) => e.toString().trim().toUpperCase())
                .where((e) => e.isNotEmpty)
                .toList() ??
            [];
        final remoteImages = (remoteCfg['category_images'] as Map?)
                ?.map((k, v) => MapEntry(k.toString().toUpperCase(), v.toString())) ??
            {};

        for (final dc in remoteDeleted) {
          _deletedCategories.add(dc);
          _customCategories.remove(dc);
        }
        for (final cc in remoteCustom) {
          if (!_deletedCategories.contains(cc) && !_customCategories.contains(cc)) {
            _customCategories.add(cc);
          }
        }
        for (final entry in remoteImages.entries) {
          if (entry.value.isNotEmpty) {
            _categoryImages[entry.key] = entry.value;
          }
        }
        await _saveCustomCategories();
        await _saveDeletedCategories();
      }
    } catch (_) {}

    final loaded = await SupabaseService.instance.getProducts(shopId);
    // Double-guard: any product belonging to a deleted category stays soft-deleted & hidden
    final strayInDeletedCat = loaded
        .where((p) => _deletedCategories.contains(p.category.trim().toUpperCase()))
        .toList();
    for (final p in strayInDeletedCat) {
      await SupabaseService.instance.deleteProduct(p.id, shopId: shopId);
    }
    _products = loaded
        .where((p) => !_deletedCategories.contains(p.category.trim().toUpperCase()))
        .toList();

    // Recompute product and category popularity / sales count from local sales history
    try {
      final sales = await LocalDbService.instance.getSales(shopId);
      recomputeSalesStats(sales);
    } catch (e) {
      debugPrint("Error loading sales for popularity sorting: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Recomputes product and category sales frequency / total units sold
  void recomputeSalesStats(List<Sale> sales) {
    _productSalesQty.clear();
    _categorySalesQty.clear();
    for (final sale in sales) {
      for (final item in sale.items) {
        final qty = item.qty;
        if (item.productId != null && item.productId!.isNotEmpty) {
          _productSalesQty[item.productId!] = (_productSalesQty[item.productId!] ?? 0.0) + qty;
        }
        final prod = getProductById(item.productId);
        final cat = prod?.category.trim().toUpperCase() ?? '';
        if (cat.isNotEmpty && cat != 'ALL') {
          _categorySalesQty[cat] = (_categorySalesQty[cat] ?? 0.0) + qty;
        }
      }
    }
  }

  void selectCategory(String cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> addCategory(String categoryName) async {
    final name = categoryName.trim().toUpperCase();
    if (name.isEmpty) return;
    _deletedCategories.remove(name);
    await _saveDeletedCategories();
    if (!_customCategories.contains(name)) {
      _customCategories.add(name);
      await _saveCustomCategories();
    }
    final catId = const Uuid().v4();
    final cat = Category(
      id: catId,
      shopId: _activeShopId,
      name: name,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await LocalDbService.instance.upsertCategory(_activeShopId, cat);
    _normalizedCategories.removeWhere((c) => c.name.toUpperCase() == name);
    _normalizedCategories.add(cat);
    await _syncCategoriesToDoubleLayer();
    notifyListeners();
  }

  Future<void> deleteCategory(String categoryName) async {
    final name = categoryName.trim().toUpperCase();
    _customCategories.remove(name);
    _deletedCategories.add(name);
    _categoryImages.remove(name);
    _normalizedCategories.removeWhere((c) => c.name.toUpperCase() == name);
    await _saveCustomCategories();
    await _saveDeletedCategories();
    await LocalDbService.instance.deleteCategory(_activeShopId, name);

    // Cascade Delete: Soft-delete all products in this category in Cloud Supabase + Local SQLite
    final toDelete = _products.where((p) => p.category.trim().toUpperCase() == name).toList();
    _products.removeWhere((p) => p.category.trim().toUpperCase() == name);
    if (_selectedCategory.toUpperCase() == name) {
      _selectedCategory = 'All';
    }
    notifyListeners();

    for (final p in toDelete) {
      try {
        await SupabaseService.instance.deleteProduct(p.id, shopId: _activeShopId);
      } catch (e) {
        debugPrint("Error deleting product ${p.name} on category delete: $e");
      }
    }
    await _syncCategoriesToDoubleLayer();
  }

  Future<void> addProduct(Product p) async {
    final catUpper = p.category.trim().toUpperCase();
    if (_deletedCategories.remove(catUpper)) {
      await _saveDeletedCategories();
      await _syncCategoriesToDoubleLayer();
    }
    final created = await SupabaseService.instance.addProduct(p);
    _products.removeWhere((prod) => prod.id == created.id);
    _products.add(created);
    notifyListeners();
  }

  Future<void> addProductsBatch(List<Product> newProducts) async {
    if (newProducts.isEmpty) return;
    final saved = await SupabaseService.instance.addProductsBatch(newProducts);
    for (final p in saved) {
      _products.removeWhere((item) => item.id == p.id);
      _products.add(p);
    }
    notifyListeners();
  }

  Future<void> updateProduct(Product p) async {
    await SupabaseService.instance.updateProduct(p);
    final idx = _products.indexWhere((prod) => prod.id == p.id);
    if (idx != -1) {
      _products[idx] = p;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String productId) async {
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
    await SupabaseService.instance.deleteProduct(productId, shopId: _activeShopId);
  }

  Product? findByBarcode(String barcode) {
    try {
      return _products.firstWhere((p) => p.barcode == barcode || p.sku == barcode);
    } catch (_) {
      return null;
    }
  }

  Product? getProductById(String? id) {
    if (id == null || id.isEmpty) return null;
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Deduct stock in-memory upon sale completion and update popularity counters so UI updates immediately
  void deductStock(List<CartItem> items) {
    bool changed = false;
    for (final item in items) {
      if (item.productId != null) {
        final idx = _products.indexWhere((p) => p.id == item.productId);
        if (idx != -1) {
          final current = _products[idx];
          final newStock = current.stock - item.qty;
          _products[idx] = current.copyWith(stock: newStock);
          changed = true;

          // Increment real-time sales popularity counters
          _productSalesQty[current.id] = (_productSalesQty[current.id] ?? 0.0) + item.qty;
          final cat = current.category.trim().toUpperCase();
          if (cat.isNotEmpty && cat != 'ALL') {
            _categorySalesQty[cat] = (_categorySalesQty[cat] ?? 0.0) + item.qty;
          }
        }
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Adjust in-memory stock when an existing bill is edited (delta = newQty - oldQty)
  void applyStockDiff(List<CartItem> oldItems, List<CartItem> newItems) {
    final oldQty = <String, double>{};
    for (final it in oldItems) {
      if (it.productId != null && it.productId!.isNotEmpty) {
        oldQty[it.productId!] = (oldQty[it.productId!] ?? 0.0) + it.qty;
      }
    }
    final newQty = <String, double>{};
    for (final it in newItems) {
      if (it.productId != null && it.productId!.isNotEmpty) {
        newQty[it.productId!] = (newQty[it.productId!] ?? 0.0) + it.qty;
      }
    }
    final touched = <String>{...oldQty.keys, ...newQty.keys};
    bool changed = false;
    for (final pid in touched) {
      final deltaSold = (newQty[pid] ?? 0.0) - (oldQty[pid] ?? 0.0);
      if (deltaSold.abs() < 0.0001) continue;
      final idx = _products.indexWhere((p) => p.id == pid);
      if (idx != -1) {
        final current = _products[idx];
        _products[idx] = current.copyWith(stock: current.stock - deltaSold);
        _productSalesQty[current.id] = (_productSalesQty[current.id] ?? 0.0) + deltaSold;
        final cat = current.category.trim().toUpperCase();
        if (cat.isNotEmpty && cat != 'ALL') {
          _categorySalesQty[cat] = (_categorySalesQty[cat] ?? 0.0) + deltaSold;
        }
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void replaceProductsLocal(List<Product> list) {
    _products = List<Product>.from(list);
    notifyListeners();
  }
}
