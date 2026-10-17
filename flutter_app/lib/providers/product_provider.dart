import 'package:flutter/foundation.dart';
import '../data/models/product.dart';
import '../data/services/supabase_service.dart';
import '../core/constants/aliases.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  List<String> get categories {
    final set = {'All'};
    for (final p in _products) {
      set.add(p.category);
    }
    return set.toList();
  }

  List<Product> get filteredProducts {
    return _products.where((p) {
      final matchesCat = _selectedCategory == 'All' || p.category == _selectedCategory;
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

  Product? findByBarcode(String barcode) {
    try {
      return _products.firstWhere((p) => p.barcode == barcode || p.sku == barcode);
    } catch (_) {
      return null;
    }
  }
}
