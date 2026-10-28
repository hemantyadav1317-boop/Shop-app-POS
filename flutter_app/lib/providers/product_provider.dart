import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/product.dart';
import '../data/services/supabase_service.dart';
import '../core/constants/aliases.dart';

class ProductProvider extends ChangeNotifier {
  static const List<String> defaultCategories = [
    'VEGETABLES',
    'FRUITS',
    'DAIRY',
    'GRAINS',
    'SNACKS',
    'BEVERAGES',
    'SPICES',
    'PERSONAL CARE',
    'GENERAL',
  ];

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
  final List<String> _customCategories = [];
  final Set<String> _deletedCategories = {};
  final Map<String, String> _categoryImages = {};
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

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
  List<String> get allCategories {
    final set = <String>{};
    for (final c in defaultCategories) {
      final upper = c.toUpperCase();
      if (!_deletedCategories.contains(upper)) {
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
    return set.toList();
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
    return _products.where((p) {
      final matchesCat = _selectedCategory == 'All' ||
          p.category.trim().toUpperCase() == _selectedCategory.trim().toUpperCase();
      final matchesSearch = ProductAliases.matches(p.name, p.category, p.barcode, _searchQuery);
      return matchesCat && matchesSearch;
    }).toList();
  }

  Future<void> loadProducts(String shopId) async {
    _isLoading = true;
    notifyListeners();

    _products = await SupabaseService.instance.getProducts(shopId);
    _isLoading = false;
    notifyListeners();
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
    if (!_customCategories.contains(name) && !defaultCategories.contains(name)) {
      _customCategories.add(name);
      await _saveCustomCategories();
    }
    notifyListeners();
  }

  Future<void> deleteCategory(String categoryName) async {
    final name = categoryName.trim().toUpperCase();
    _customCategories.remove(name);
    _deletedCategories.add(name);
    await _saveCustomCategories();
    await _saveDeletedCategories();

    // Reassign products of this category to GENERAL locally & in Cloud Supabase
    for (var i = 0; i < _products.length; i++) {
      if (_products[i].category.trim().toUpperCase() == name) {
        final updated = _products[i].copyWith(category: 'GENERAL');
        _products[i] = updated;
        await SupabaseService.instance.updateProduct(updated);
      }
    }
    if (_selectedCategory.toUpperCase() == name) {
      _selectedCategory = 'All';
    }
    notifyListeners();
  }

  Future<void> addProduct(Product p) async {
    final created = await SupabaseService.instance.addProduct(p);
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
    await SupabaseService.instance.deleteProduct(productId);
  }

  Product? findByBarcode(String barcode) {
    try {
      return _products.firstWhere((p) => p.barcode == barcode || p.sku == barcode);
    } catch (_) {
      return null;
    }
  }
}
