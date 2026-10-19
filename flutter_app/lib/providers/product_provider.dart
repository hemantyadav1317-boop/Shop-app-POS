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

  List<Product> _products = [];
  final List<String> _customCategories = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  ProductProvider() {
    _loadCustomCategories();
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

  /// List of all categories without 'All' (used in product add/edit dropdown & category management)
  List<String> get allCategories {
    final set = <String>{};
    for (final c in defaultCategories) {
      set.add(c.toUpperCase());
    }
    for (final c in _customCategories) {
      set.add(c.toUpperCase());
    }
    for (final p in _products) {
      if (p.category.trim().isNotEmpty && p.category.toLowerCase() != 'all') {
        set.add(p.category.trim().toUpperCase());
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
    if (!_customCategories.contains(name) && !defaultCategories.contains(name)) {
      _customCategories.add(name);
      await _saveCustomCategories();
      notifyListeners();
    }
  }

  Future<void> deleteCategory(String categoryName) async {
    final name = categoryName.trim().toUpperCase();
    _customCategories.remove(name);
    await _saveCustomCategories();

    // Reassign products of this category to GENERAL
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
