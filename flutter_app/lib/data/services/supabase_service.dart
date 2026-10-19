import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/expense.dart';
import '../models/shop.dart';
import 'catalog_data.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  static const String supabaseUrl = "https://zibgyfybhvadduuhexqy.supabase.co";
  static const String supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InppYmd5ZnliaHZhZGR1dWhleHF5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIyNDk5MjEsImV4cCI6MjEwNzgyNTkyMX0.XFImvPo8yOUyc1svG2PG1-oK-P0O7iw2MAMxjh0gwSE";

  bool _isInitialized = false;
  String? _initError;
  String? get initError => _initError;

  bool get isInitialized => _isInitialized || client != null;

  SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // In-memory local fallback cache
  final List<Product> _localProducts = [];
  final List<Customer> _localCustomers = [];
  final List<Sale> _localSales = [];
  final List<Expense> _localExpenses = [];
  Shop _localShop = Shop(
    id: 'demo-shop-101',
    name: 'मेरी दुकान (My Store)',
    phone: '',
    address: '',
    gstin: '',
    upiId: '',
    upiPayeeName: '',
    allowNegativeStock: true,
    printPaperSize: '58mm',
    receiptFooter: 'धन्यवाद! फिर पधारें 🙏',
  );

  Shop get currentShop => _localShop;

  Future<void> initialize() async {
    if (client != null) {
      _isInitialized = true;
      return;
    }
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _isInitialized = true;
      _initError = null;
      debugPrint("Supabase initialized successfully");
    } catch (e) {
      _initError = e.toString();
      debugPrint("Supabase init failed: $e");
      try {
        Supabase.instance.client;
        _isInitialized = true;
        _initError = null;
      } catch (_) {
        _isInitialized = false;
      }
    }

    // Load cached offline products/customers/shop if available
    await _loadOfflineCache();
  }

  Future<void> _loadOfflineCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedShop = prefs.getString('saved_shop_data');
      if (cachedShop != null) {
        _localShop = Shop.fromJson(jsonDecode(cachedShop) as Map<String, dynamic>);
      }

      final cachedProds = prefs.getString('cached_products_${_localShop.id}');
      if (cachedProds != null) {
        final list = (jsonDecode(cachedProds) as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
        _localProducts.clear();
        _localProducts.addAll(list);
      } else if (_localProducts.isEmpty) {
        _localProducts.addAll(CatalogData.getInitialProducts(_localShop.id));
      }

      final cachedCusts = prefs.getString('cached_customers_${_localShop.id}');
      if (cachedCusts != null) {
        final list = (jsonDecode(cachedCusts) as List).map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
        _localCustomers.clear();
        _localCustomers.addAll(list);
      }
    } catch (e) {
      debugPrint("Error loading offline cache: $e");
    }
  }

  void setLocalShop(Shop shop) {
    _localShop = shop;
  }

  // --- MULTI-DEVICE CLOUD SHOP SYNC ---
  /// Ensures the logged in user has a persistent UUID shop in Supabase
  /// and downloads that shop's data to the device so mobile and tablet match 100%.
  Future<Shop> syncUserShop({
    required String userId,
    required String userEmail,
    Shop? fallback,
  }) async {
    if (!_isInitialized || client == null) {
      return _localShop;
    }

    try {
      // 1. Try to find shop owned by this user
      final owned = await client!.from('shops').select('*').eq('owner_id', userId).maybeSingle();
      if (owned != null) {
        final shop = Shop.fromJson(owned);
        _localShop = shop;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_shop_data', jsonEncode(shop.toJson()));
        return shop;
      }

      // 2. Try to find shop where user is a member
      final member = await client!.from('shop_members').select('shop_id').eq('user_id', userId).maybeSingle();
      if (member != null && member['shop_id'] != null) {
        final memberShop = await client!.from('shops').select('*').eq('id', member['shop_id']).maybeSingle();
        if (memberShop != null) {
          final shop = Shop.fromJson(memberShop);
          _localShop = shop;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_shop_data', jsonEncode(shop.toJson()));
          return shop;
        }
      }

      // 3. User does not have a shop in cloud yet -> create one with a real UUID
      final shopName = (fallback?.name != null && fallback!.name.isNotEmpty && fallback.name != 'मेरी दुकान (My Store)')
          ? fallback.name
          : 'Meri Dukan (${userEmail.split('@').first})';

      final newShopPayload = {
        'owner_id': userId,
        'name': shopName,
        if (fallback?.phone != null) 'phone': fallback!.phone,
        if (fallback?.address != null) 'address': fallback!.address,
        if (fallback?.gstin != null) 'gst_number': fallback!.gstin,
        if (fallback?.upiId != null) 'upi_id': fallback!.upiId,
        if (fallback?.upiPayeeName != null) 'upi_payee_name': fallback!.upiPayeeName,
        'receipt_footer': fallback?.receiptFooter ?? 'धन्यवाद! फिर पधारें 🙏',
        'print_paper_size': fallback?.printPaperSize ?? '58mm',
        'allow_negative_stock': fallback?.allowNegativeStock ?? true,
      };

      final created = await client!.from('shops').insert(newShopPayload).select().single();
      final shop = Shop.fromJson(created);
      _localShop = shop;

      // Join as owner in shop_members
      try {
        await client!.from('shop_members').upsert({
          'shop_id': shop.id,
          'user_id': userId,
          'role': 'owner',
        });
      } catch (err) {
        debugPrint("shop_members insert err: $err");
      }

      // Seed initial catalog into cloud for this new shop
      final seedItems = CatalogData.getInitialProducts(shop.id);
      try {
        await client!.from('products').insert(seedItems.map((p) => p.toSupabaseJson()).toList());
        _localProducts.clear();
        _localProducts.addAll(seedItems);
      } catch (e) {
        debugPrint("Error seeding initial catalog to cloud: $e");
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_shop_data', jsonEncode(shop.toJson()));
      return shop;
    } catch (e) {
      debugPrint("Error in syncUserShop: $e");
      return _localShop;
    }
  }

  // --- PRODUCTS ---
  Future<List<Product>> getProducts(String shopId) async {
    if (_isInitialized && client != null && shopId != 'demo-shop-101') {
      try {
        final response = await client!
            .from('products')
            .select('*')
            .eq('shop_id', shopId)
            .eq('is_active', true)
            .order('name');
        final list = (response as List).map((e) => Product.fromJson(e)).toList();
        if (list.isNotEmpty) {
          _localProducts.clear();
          _localProducts.addAll(list);
          _saveCachedProducts(shopId, list);
          return list;
        } else {
          // Empty in cloud -> Seed catalog once
          final seed = CatalogData.getInitialProducts(shopId);
          try {
            await client!.from('products').insert(seed.map((p) => p.toSupabaseJson()).toList());
            _localProducts.clear();
            _localProducts.addAll(seed);
            _saveCachedProducts(shopId, seed);
            return seed;
          } catch (_) {}
        }
      } catch (e) {
        debugPrint("Error fetching products from cloud: $e");
      }
    }

    // Fallback: check cached preferences
    if (_localProducts.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_products_$shopId');
        if (cached != null) {
          final list = (jsonDecode(cached) as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
          _localProducts.addAll(list);
        } else {
          _localProducts.addAll(CatalogData.getInitialProducts(shopId));
        }
      } catch (_) {}
    }

    return List.from(_localProducts);
  }

  Future<void> _saveCachedProducts(String shopId, List<Product> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_products_$shopId', jsonEncode(list.map((p) => p.toSupabaseJson()).toList()));
    } catch (_) {}
  }

  Future<Product> addProduct(Product product) async {
    Product saved = product;
    if (isInitialized && client != null && product.shopId != 'demo-shop-101') {
      try {
        final res = await client!.from('products').insert(product.toSupabaseJson()).select().single();
        saved = Product.fromJson(res);
      } catch (e) {
        debugPrint("Error inserting product in cloud: $e");
      }
    }
    _localProducts.removeWhere((p) => p.id == product.id);
    _localProducts.add(saved);
    _saveCachedProducts(product.shopId, _localProducts);
    return saved;
  }

  Future<void> updateProduct(Product product) async {
    final index = _localProducts.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _localProducts[index] = product;
    }
    if (isInitialized && client != null && product.shopId != 'demo-shop-101') {
      try {
        await client!.from('products').update(product.toSupabaseJson()).eq('id', product.id);
      } catch (e) {
        debugPrint("Error updating product in cloud: $e");
      }
    }
    _saveCachedProducts(product.shopId, _localProducts);
  }

  Future<void> deleteProduct(String productId) async {
    _localProducts.removeWhere((p) => p.id == productId);
    if (isInitialized && client != null) {
      try {
        await client!.from('products').delete().eq('id', productId);
      } catch (e) {
        debugPrint("Error deleting product in cloud: $e");
      }
    }
    _saveCachedProducts(_localShop.id, _localProducts);
  }

  // --- CUSTOMERS ---
  Future<List<Customer>> getCustomers(String shopId) async {
    if (_isInitialized && client != null && shopId != 'demo-shop-101') {
      try {
        final response = await client!
            .from('customers')
            .select('*')
            .eq('shop_id', shopId)
            .order('name');
        final list = (response as List).map((e) => Customer.fromJson(e)).toList();
        _localCustomers.clear();
        _localCustomers.addAll(list);
        _saveCachedCustomers(shopId, list);
        return list;
      } catch (e) {
        debugPrint("Error fetching customers from cloud: $e");
      }
    }

    if (_localCustomers.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_customers_$shopId');
        if (cached != null) {
          final list = (jsonDecode(cached) as List).map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
          _localCustomers.addAll(list);
        }
      } catch (_) {}
    }

    return List.from(_localCustomers);
  }

  Future<void> _saveCachedCustomers(String shopId, List<Customer> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_customers_$shopId', jsonEncode(list.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }

  Future<Customer> addCustomer(Customer customer) async {
    Customer saved = customer;
    if (_isInitialized && client != null && customer.shopId != 'demo-shop-101') {
      try {
        final res = await client!.from('customers').insert(customer.toJson()).select().single();
        saved = Customer.fromJson(res);
      } catch (e) {
        debugPrint("Error adding customer to cloud: $e");
      }
    }
    _localCustomers.removeWhere((c) => c.id == customer.id);
    _localCustomers.add(saved);
    _saveCachedCustomers(customer.shopId, _localCustomers);
    return saved;
  }

  Future<void> updateCustomerBalance(String customerId, double newBalance) async {
    final index = _localCustomers.indexWhere((c) => c.id == customerId);
    if (index != -1) {
      _localCustomers[index] = _localCustomers[index].copyWith(balance: newBalance);
    }
    if (_isInitialized && client != null) {
      try {
        await client!.from('customers').update({'balance': newBalance}).eq('id', customerId);
      } catch (e) {
        debugPrint("Error updating customer balance: $e");
      }
    }
    _saveCachedCustomers(_localShop.id, _localCustomers);
  }

  Future<void> deleteCustomer(String customerId) async {
    _localCustomers.removeWhere((c) => c.id == customerId);
    if (_isInitialized && client != null) {
      try {
        await client!.from('customers').delete().eq('id', customerId);
      } catch (e) {
        debugPrint("Error deleting customer: $e");
      }
    }
    _saveCachedCustomers(_localShop.id, _localCustomers);
  }

  // --- SALES & BILLING (CREATE, READ, UPDATE, DELETE) ---
  Future<List<Sale>> getSales(String shopId) async {
    if (_isInitialized && client != null && shopId != 'demo-shop-101') {
      try {
        final response = await client!
            .from('sales')
            .select('*')
            .eq('shop_id', shopId)
            .order('created_at', ascending: false)
            .limit(200);
        final list = (response as List).map((e) => Sale.fromJson(e)).toList();
        _localSales.clear();
        _localSales.addAll(list);
        _saveCachedSales(shopId, list);
        return list;
      } catch (e) {
        debugPrint("Error fetching sales from cloud: $e");
      }
    }

    if (_localSales.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_sales_$shopId');
        if (cached != null) {
          final list = (jsonDecode(cached) as List).map((e) => Sale.fromJson(e as Map<String, dynamic>)).toList();
          _localSales.addAll(list);
        }
      } catch (_) {}
    }

    return List.from(_localSales);
  }

  Future<void> _saveCachedSales(String shopId, List<Sale> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_sales_$shopId', jsonEncode(list.map((s) => s.toJson()).toList()));
    } catch (_) {}
  }

  Future<Sale> createSale(Sale sale) async {
    _localSales.insert(0, sale);

    // Deduct stock locally
    for (final item in sale.items) {
      if (item.productId != null) {
        final pIndex = _localProducts.indexWhere((p) => p.id == item.productId);
        if (pIndex != -1) {
          final current = _localProducts[pIndex];
          _localProducts[pIndex] = current.copyWith(stock: current.stock - item.qty);
        }
      }
    }

    // Add to customer Khata if credit
    if (sale.due > 0 && sale.customerId != null) {
      final cIndex = _localCustomers.indexWhere((c) => c.id == sale.customerId);
      if (cIndex != -1) {
        final c = _localCustomers[cIndex];
        _localCustomers[cIndex] = c.copyWith(balance: c.balance + sale.due);
      }
    }

    if (_isInitialized && client != null && sale.shopId != 'demo-shop-101') {
      try {
        // Try calling RPC create_sale_once if available
        await client!.rpc('create_sale_once', params: {
          '_client_ref': sale.clientRef ?? sale.id,
          '_shop_id': sale.shopId,
          '_items': sale.items.map((i) => i.toJson()).toList(),
          '_discount': sale.discount,
          '_payment_mode': sale.paymentMode,
          '_paid': sale.paid,
          '_customer_id': sale.customerId,
          '_customer_name': sale.customerName,
          '_customer_phone': sale.customerPhone,
          '_note': null,
        });
      } catch (e) {
        debugPrint("RPC create_sale_once fallback to direct table insert: $e");
        try {
          await client!.from('sales').insert(sale.toJson());
        } catch (inner) {
          debugPrint("Failed to write sale to cloud: $inner");
        }
      }
    }

    _saveCachedSales(sale.shopId, _localSales);
    return sale;
  }

  /// Update an existing bill in Cloud and local cache
  Future<Sale> updateSale(Sale updatedSale) async {
    final idx = _localSales.indexWhere((s) => s.id == updatedSale.id);
    if (idx != -1) {
      _localSales[idx] = updatedSale;
    }

    if (_isInitialized && client != null && updatedSale.shopId != 'demo-shop-101') {
      try {
        await client!.from('sales').update(updatedSale.toJson()).eq('id', updatedSale.id);
      } catch (e) {
        debugPrint("Error updating sale in cloud: $e");
      }
    }

    _saveCachedSales(updatedSale.shopId, _localSales);
    return updatedSale;
  }

  /// Delete / cancel an existing bill
  Future<void> deleteSale(String saleId) async {
    _localSales.removeWhere((s) => s.id == saleId);
    if (_isInitialized && client != null) {
      try {
        await client!.from('sales').delete().eq('id', saleId);
      } catch (e) {
        debugPrint("Error deleting sale in cloud: $e");
      }
    }
    _saveCachedSales(_localShop.id, _localSales);
  }

  // --- EXPENSES ---
  Future<List<Expense>> getExpenses(String shopId) async {
    if (_isInitialized && client != null && shopId != 'demo-shop-101') {
      try {
        final response = await client!
            .from('expenses')
            .select('*')
            .eq('shop_id', shopId)
            .order('spent_on', ascending: false)
            .limit(100);
        return (response as List).map((e) => Expense.fromJson(e)).toList();
      } catch (e) {
        debugPrint("Error fetching expenses: $e");
      }
    }
    return List.from(_localExpenses);
  }

  Future<void> addExpense(Expense expense) async {
    _localExpenses.insert(0, expense);
    if (_isInitialized && client != null) {
      try {
        await client!.from('expenses').insert(expense.toJson());
      } catch (e) {
        debugPrint("Error adding expense: $e");
      }
    }
  }

  // --- SHOP SETTINGS ---
  Future<Shop> updateShop(Shop shop) async {
    _localShop = shop;
    if (_isInitialized && client != null) {
      final user = client!.auth.currentUser;
      try {
        final payload = {
          'name': shop.name,
          if (shop.phone != null) 'phone': shop.phone,
          if (shop.address != null) 'address': shop.address,
          'gst_number': shop.gstin,
          if (shop.upiId != null) 'upi_id': shop.upiId,
          if (shop.upiPayeeName != null) 'upi_payee_name': shop.upiPayeeName,
          'allow_negative_stock': shop.allowNegativeStock,
          'print_paper_size': shop.printPaperSize,
          'receipt_footer': shop.receiptFooter,
          if (shop.qrImageUrl != null) 'qr_image_url': shop.qrImageUrl,
        };
        if (shop.id != 'demo-shop-101' && shop.id.length >= 30) {
          await client!.from('shops').update(payload).eq('id', shop.id);
        } else if (user != null) {
          final existing = await client!.from('shops').select('id').eq('owner_id', user.id).maybeSingle();
          if (existing != null && existing['id'] != null) {
            final realId = existing['id'] as String;
            _localShop = shop.copyWith(id: realId);
            await client!.from('shops').update(payload).eq('id', realId);
          } else {
            final created = await client!.from('shops').insert({
              ...payload,
              'owner_id': user.id,
            }).select().single();
            if (created['id'] != null) {
              _localShop = Shop.fromJson(created);
            }
          }
        }
      } catch (e) {
        debugPrint("Error updating shop settings in cloud: $e");
      }
    }
    return _localShop;
  }

  Future<Shop?> getShop(String shopId) async {
    if (_isInitialized && client != null) {
      try {
        final res = await client!.from('shops').select('*').eq('id', shopId).maybeSingle();
        if (res != null) {
          _localShop = Shop.fromJson(res);
          return _localShop;
        }
      } catch (e) {
        debugPrint("Error getting shop from cloud: $e");
      }
    }
    return _localShop;
  }

  Future<Shop> joinShop(String shopCode) async {
    final cleanCode = shopCode.trim();
    if (_isInitialized && client != null) {
      try {
        final res = await client!.from('shops').select('*').eq('id', cleanCode).maybeSingle();
        if (res != null) {
          _localShop = Shop.fromJson(res);
          final user = client!.auth.currentUser;
          if (user != null) {
            try {
              await client!.from('shop_members').upsert({
                'shop_id': cleanCode,
                'user_id': user.id,
                'role': 'cashier',
              });
            } catch (err) {
              debugPrint("upsert shop_members err: $err");
            }
          }
          return _localShop;
        }
      } catch (e) {
        debugPrint("Error joining shop from cloud: $e");
      }
    }

    _localShop = _localShop.copyWith(id: cleanCode);
    return _localShop;
  }
}
