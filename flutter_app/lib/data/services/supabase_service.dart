import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
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

  /// Automatically ensures that if a user is logged in, their data is attached
  /// to their real Supabase Cloud shop UUID rather than staying trapped in demo-shop-101.
  Future<String> _ensureValidShopId(String currentShopId) async {
    if (currentShopId != 'demo-shop-101' && currentShopId.length >= 30) {
      return currentShopId;
    }
    final user = client?.auth.currentUser;
    if (user != null) {
      final synced = await syncUserShop(userId: user.id, userEmail: user.email ?? '');
      return synced.id;
    }
    return currentShopId;
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
      final prefs = await SharedPreferences.getInstance();

      // 1. Try to find existing shop owned by this user
      final owned = await client!.from('shops').select('*').eq('owner_id', userId).maybeSingle();
      if (owned != null) {
        final shop = Shop.fromJson(owned);
        _localShop = shop;
        await prefs.setString('saved_shop_data', jsonEncode(shop.toJson()));

        // Migrate any offline cached products to cloud shop
        final offlineCached = prefs.getString('cached_products_demo-shop-101');
        if (offlineCached != null) {
          try {
            final list = (jsonDecode(offlineCached) as List)
                .map((e) => Product.fromJson(e as Map<String, dynamic>))
                .toList();
            if (list.isNotEmpty) {
              final toMigrate = list.map((p) => p.copyWith(
                id: p.id.startsWith('demo-') ? const Uuid().v4() : p.id,
                shopId: shop.id,
              )).toList();
              await addProductsBatch(toMigrate);
              await prefs.remove('cached_products_demo-shop-101');
              debugPrint("Migrated ${toMigrate.length} offline cached products to cloud shop ${shop.id}");
            }
          } catch (e) {
            debugPrint("Error migrating offline cached products: $e");
          }
        }

        // Migrate any in-memory demo products
        if (_localProducts.isNotEmpty && _localProducts.any((p) => p.shopId == 'demo-shop-101')) {
          final toMigrate = _localProducts
              .where((p) => p.shopId == 'demo-shop-101')
              .map((p) => p.copyWith(
                    id: p.id.startsWith('demo-') ? const Uuid().v4() : p.id,
                    shopId: shop.id,
                  ))
              .toList();
          await addProductsBatch(toMigrate);
        }

        return shop;
      }

      // 2. Try to find shop where user is a member
      try {
        final member = await client!.from('shop_members').select('shop_id').eq('user_id', userId).maybeSingle();
        if (member != null && member['shop_id'] != null) {
          final memberShop = await client!.from('shops').select('*').eq('id', member['shop_id']).maybeSingle();
          if (memberShop != null) {
            final shop = Shop.fromJson(memberShop);
            _localShop = shop;
            await prefs.setString('saved_shop_data', jsonEncode(shop.toJson()));
            return shop;
          }
        }
      } catch (memErr) {
        debugPrint("Check shop_members error: $memErr");
      }

      // 3. User does not have a shop in cloud yet -> create one with a client-generated UUID
      final shopName = (fallback?.name != null && fallback!.name.isNotEmpty && fallback.name != 'मेरी दुकान (My Store)')
          ? fallback.name
          : 'Meri Dukan (${userEmail.split('@').first})';

      final newShopId = const Uuid().v4();
      final newShopPayload = {
        'id': newShopId,
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

      Shop shop;
      try {
        final created = await client!.from('shops').insert(newShopPayload).select().maybeSingle();
        if (created != null) {
          shop = Shop.fromJson(created);
        } else {
          shop = Shop(
            id: newShopId,
            name: shopName,
            phone: fallback?.phone ?? '',
            address: fallback?.address ?? '',
            gstin: fallback?.gstin ?? '',
            upiId: fallback?.upiId ?? '',
            upiPayeeName: fallback?.upiPayeeName ?? '',
            allowNegativeStock: fallback?.allowNegativeStock ?? true,
            printPaperSize: fallback?.printPaperSize ?? '58mm',
            receiptFooter: fallback?.receiptFooter ?? 'धन्यवाद! फिर पधारें 🙏',
          );
        }
      } catch (insertErr) {
        debugPrint("Direct insert shops error (fallback to assigned UUID): $insertErr");
        shop = Shop(
          id: newShopId,
          name: shopName,
          phone: fallback?.phone ?? '',
          address: fallback?.address ?? '',
          gstin: fallback?.gstin ?? '',
          upiId: fallback?.upiId ?? '',
          upiPayeeName: fallback?.upiPayeeName ?? '',
          allowNegativeStock: fallback?.allowNegativeStock ?? true,
          printPaperSize: fallback?.printPaperSize ?? '58mm',
          receiptFooter: fallback?.receiptFooter ?? 'धन्यवाद! फिर पधारें 🙏',
        );
      }

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

      await prefs.setString('saved_shop_data', jsonEncode(shop.toJson()));
      return shop;
    } catch (e) {
      debugPrint("Error in syncUserShop: $e");
      return _localShop;
    }
  }

  /// Complete 1-Tap Cloud Sync: Fetches all fresh data from Supabase
  /// and returns count summary for user confirmation.
  Future<Map<String, int>> syncAllCloudData(String shopId) async {
    final validShopId = await _ensureValidShopId(shopId);
    int prods = 0;
    int custs = 0;
    int sales = 0;

    if (_isInitialized && client != null && validShopId != 'demo-shop-101') {
      try {
        final pList = await getProducts(validShopId);
        prods = pList.length;
      } catch (e) {
        debugPrint("Sync products err: $e");
      }

      try {
        final cList = await getCustomers(validShopId);
        custs = cList.length;
      } catch (e) {
        debugPrint("Sync customers err: $e");
      }

      try {
        final sList = await getSales(validShopId);
        sales = sList.length;
      } catch (e) {
        debugPrint("Sync sales err: $e");
      }
    }

    return {
      'products': prods,
      'customers': custs,
      'sales': sales,
    };
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

        // Check if there are local products (like newly added custom products) that need to be pushed to cloud
        final cloudNames = list.map((p) => p.name.trim().toLowerCase()).toSet();
        final unUploaded = _localProducts.where((lp) => !cloudNames.contains(lp.name.trim().toLowerCase())).toList();
        if (unUploaded.isNotEmpty) {
          debugPrint("Auto-syncing ${unUploaded.length} un-uploaded local products to cloud...");
          final newlyUploaded = await addProductsBatch(unUploaded);
          list.addAll(newlyUploaded);
        }

        if (list.isNotEmpty) {
          _localProducts.clear();
          _localProducts.addAll(list);
          _saveCachedProducts(shopId, list);
          return list;
        } else {
          // Empty in cloud -> Seed catalog once
          final seed = CatalogData.getInitialProducts(shopId);
          try {
            final savedSeed = await addProductsBatch(seed);
            _localProducts.clear();
            _localProducts.addAll(savedSeed.isNotEmpty ? savedSeed : seed);
            _saveCachedProducts(shopId, _localProducts);
            return _localProducts;
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
        final cached = prefs.getString('cached_products_$shopId') ??
            prefs.getString('cached_products_demo-shop-101');
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
    final validShopId = await _ensureValidShopId(product.shopId);
    final isValidUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(product.id);
    final targetProduct = product.copyWith(
      id: isValidUuid ? product.id : const Uuid().v4(),
      shopId: validShopId,
    );
    Product saved = targetProduct;
    if (isInitialized && client != null && validShopId != 'demo-shop-101') {
      try {
        final res = await client!.from('products').insert(targetProduct.toSupabaseJson()).select().single();
        saved = Product.fromJson(res);
      } catch (e) {
        debugPrint("Error inserting product in cloud: $e");
      }
    }
    _localProducts.removeWhere((p) => p.id == product.id || p.id == targetProduct.id);
    _localProducts.add(saved);
    _saveCachedProducts(validShopId, _localProducts);
    return saved;
  }

  Future<List<Product>> addProductsBatch(List<Product> products) async {
    if (products.isEmpty) return [];
    final validShopId = await _ensureValidShopId(products.first.shopId);
    final List<Product> targetProducts = products.map((p) {
      final isValidUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(p.id);
      return p.copyWith(
        id: isValidUuid ? p.id : const Uuid().v4(),
        shopId: validShopId,
      );
    }).toList();
    final List<Product> savedList = [];
    if (isInitialized && client != null && validShopId != 'demo-shop-101') {
      try {
        final payload = targetProducts.map((p) => p.toSupabaseJson()).toList();
        final res = await client!.from('products').insert(payload).select();
        final list = (res as List).map((e) => Product.fromJson(e)).toList();
        savedList.addAll(list);
      } catch (e) {
        debugPrint("Error batch inserting products in cloud: $e");
        savedList.addAll(targetProducts);
      }
    } else {
      savedList.addAll(targetProducts);
    }

    for (final p in savedList) {
      _localProducts.removeWhere((item) => item.id == p.id);
      _localProducts.add(p);
    }
    if (targetProducts.isNotEmpty) {
      _saveCachedProducts(validShopId, _localProducts);
    }
    return savedList;
  }

  Future<void> updateProduct(Product product) async {
    final validShopId = await _ensureValidShopId(product.shopId);
    final targetProduct = product.shopId != validShopId ? product.copyWith(shopId: validShopId) : product;
    final index = _localProducts.indexWhere((p) => p.id == targetProduct.id);
    if (index != -1) {
      _localProducts[index] = targetProduct;
    }
    if (isInitialized && client != null && validShopId != 'demo-shop-101') {
      try {
        await client!.from('products').update(targetProduct.toSupabaseJson()).eq('id', targetProduct.id);
      } catch (e) {
        debugPrint("Error updating product in cloud: $e");
      }
    }
    _saveCachedProducts(validShopId, _localProducts);
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
    // Load any offline/cached customers first to prevent data loss
    if (_localCustomers.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_customers_$shopId') ??
            prefs.getString('cached_customers_demo-shop-101') ??
            prefs.getString('cached_customers_shop1');
        if (cached != null) {
          final list = (jsonDecode(cached) as List).map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
          _localCustomers.addAll(list);
        }
      } catch (_) {}
    }

    if (_isInitialized && client != null && shopId != 'demo-shop-101') {
      try {
        final response = await client!
            .from('customers')
            .select('*')
            .eq('shop_id', shopId)
            .order('name');
        final cloudList = (response as List).map((e) => Customer.fromJson(e)).toList();

        // Auto-sync any local customers that are not in cloud yet
        final cloudNames = cloudList.map((c) => c.name.trim().toLowerCase()).toSet();
        for (final localCust in List<Customer>.from(_localCustomers)) {
          if (!cloudNames.contains(localCust.name.trim().toLowerCase())) {
            debugPrint("Auto-syncing un-synced customer to cloud: ${localCust.name}");
            final saved = await addCustomer(localCust.copyWith(shopId: shopId));
            cloudList.add(saved);
          }
        }

        _localCustomers.clear();
        _localCustomers.addAll(cloudList);
        _saveCachedCustomers(shopId, cloudList);
        return cloudList;
      } catch (e) {
        debugPrint("Error fetching customers from cloud: $e");
      }
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
    final validShopId = await _ensureValidShopId(customer.shopId);
    final isValidUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(customer.id);
    final targetCustomer = customer.copyWith(
      id: isValidUuid ? customer.id : const Uuid().v4(),
      shopId: validShopId,
    );
    Customer saved = targetCustomer;
    if (_isInitialized && client != null && validShopId != 'demo-shop-101') {
      try {
        final payload = targetCustomer.toSupabaseJson();
        final res = await client!.from('customers').insert(payload).select().single();
        saved = Customer.fromJson(res);
      } catch (e) {
        debugPrint("Error adding customer to cloud: $e");
      }
    }
    _localCustomers.removeWhere((c) => c.id == customer.id || c.id == targetCustomer.id);
    _localCustomers.add(saved);
    _saveCachedCustomers(validShopId, _localCustomers);
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
    // Load offline cached sales first to prevent loss
    if (_localSales.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_sales_$shopId') ??
            prefs.getString('cached_sales_demo-shop-101');
        if (cached != null) {
          final list = (jsonDecode(cached) as List).map((e) => Sale.fromJson(e as Map<String, dynamic>)).toList();
          _localSales.addAll(list);
        }
      } catch (_) {}
    }

    if (_isInitialized && client != null && shopId != 'demo-shop-101') {
      try {
        final response = await client!
            .from('sales')
            .select('*, sale_items(*)')
            .eq('shop_id', shopId)
            .order('created_at', ascending: false)
            .limit(200);
        final cloudList = (response as List).map((e) => Sale.fromJson(e)).toList();

        // Auto-sync any local sales not yet in cloud
        final cloudBillNos = cloudList.map((s) => s.billNo).toSet();
        for (final localSale in List<Sale>.from(_localSales)) {
          if (!cloudBillNos.contains(localSale.billNo)) {
            debugPrint("Auto-syncing un-synced sale to cloud: Bill #${localSale.billNo}");
            try {
              await createSale(localSale.copyWith(shopId: shopId));
            } catch (_) {}
          }
        }

        _localSales.clear();
        _localSales.addAll(cloudList);
        _saveCachedSales(shopId, cloudList);
        return cloudList;
      } catch (e) {
        debugPrint("Error fetching sales from cloud: $e");
      }
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
    final validShopId = await _ensureValidShopId(sale.shopId);
    final targetSale = sale.shopId != validShopId ? sale.copyWith(shopId: validShopId) : sale;
    _localSales.insert(0, targetSale);

    // Deduct stock locally
    for (final item in targetSale.items) {
      if (item.productId != null) {
        final pIndex = _localProducts.indexWhere((p) => p.id == item.productId);
        if (pIndex != -1) {
          final current = _localProducts[pIndex];
          _localProducts[pIndex] = current.copyWith(stock: current.stock - item.qty);
        }
      }
    }

    // Add to customer Khata if credit
    if (targetSale.due > 0 && targetSale.customerId != null) {
      final cIndex = _localCustomers.indexWhere((c) => c.id == targetSale.customerId);
      if (cIndex != -1) {
        final c = _localCustomers[cIndex];
        _localCustomers[cIndex] = c.copyWith(balance: c.balance + targetSale.due);
      }
    }

    if (_isInitialized && client != null && validShopId != 'demo-shop-101') {
      try {
        // 1. Try calling official Supabase RPC create_sale
        final formattedItems = targetSale.items.map((i) => {
          'product_id': (i.productId != null && i.productId!.length >= 30) ? i.productId : null,
          'name': i.name,
          'unit': (i.unit == 'kg') ? 'kg' : 'pc',
          'price': i.price,
          'qty': i.qty,
        }).toList();

        final validMode = ['cash', 'online', 'credit', 'split', 'set_later'].contains(targetSale.paymentMode)
            ? targetSale.paymentMode
            : 'cash';

        final custId = (targetSale.customerId != null && targetSale.customerId!.length >= 30) ? targetSale.customerId : null;

        await client!.rpc('create_sale', params: {
          '_shop_id': validShopId,
          '_items': formattedItems,
          '_discount': targetSale.discount,
          '_payment_mode': validMode,
          '_paid': targetSale.paid,
          '_customer_id': custId,
          '_customer_name': targetSale.customerName,
          '_customer_phone': targetSale.customerPhone,
          '_note': null,
        });
        debugPrint("Sale successfully synced to cloud via create_sale RPC");
      } catch (e) {
        debugPrint("RPC create_sale fallback to direct table insert: $e");
        try {
          final isValidSaleUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(targetSale.id);
          final saleId = isValidSaleUuid ? targetSale.id : const Uuid().v4();
          final salePayload = {
            'id': saleId,
            'shop_id': validShopId,
            'bill_no': targetSale.billNo > 0 ? targetSale.billNo : 1,
            'customer_id': (targetSale.customerId != null && targetSale.customerId!.length >= 30) ? targetSale.customerId : null,
            'customer_name': targetSale.customerName,
            'customer_phone': targetSale.customerPhone,
            'sub_total': targetSale.subtotal,
            'discount': targetSale.discount,
            'total': targetSale.total,
            'paid': targetSale.paid,
            'due': targetSale.due,
            'payment_mode': ['cash', 'online', 'credit', 'split', 'set_later'].contains(targetSale.paymentMode)
                ? targetSale.paymentMode
                : 'cash',
          };
          await client!.from('sales').insert(salePayload);

          for (final item in targetSale.items) {
            try {
              await client!.from('sale_items').insert({
                'shop_id': validShopId,
                'sale_id': saleId,
                'product_id': (item.productId != null && item.productId!.length >= 30) ? item.productId : null,
                'name': item.name,
                'unit': (item.unit == 'kg') ? 'kg' : 'pc',
                'price': item.price,
                'qty': item.qty,
                'line_total': item.price * item.qty,
              });
            } catch (_) {}
          }
        } catch (inner) {
          debugPrint("Failed to write sale directly to cloud: $inner");
        }
      }
    }

    _saveCachedSales(validShopId, _localSales);
    return targetSale;
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
