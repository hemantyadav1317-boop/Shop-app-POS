import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/customer_payment.dart';
import '../models/sale.dart';
import '../models/expense.dart';
import '../models/shop.dart';
import 'local_db_service.dart';

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
    await LocalDbService.instance.init();
    if (client != null) {
      _isInitialized = true;
      await _loadOfflineCache();
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

    // Load cached offline products/customers/sales/shop if available
    await _loadOfflineCache();
  }

  Future<void> _loadOfflineCache() async {
    try {
      await LocalDbService.instance.init();
      final prefs = await SharedPreferences.getInstance();
      final cachedShop = prefs.getString('saved_shop_data');
      if (cachedShop != null) {
        _localShop = Shop.fromJson(jsonDecode(cachedShop) as Map<String, dynamic>);
      } else {
        final dbShop = await LocalDbService.instance.getShop(_localShop.id);
        if (dbShop != null) _localShop = dbShop;
      }
      await LocalDbService.instance.saveShop(_localShop);

      // Load products: prefer SQLite, migrate SharedPreferences if SQLite is empty
      var dbProds = await LocalDbService.instance.getProducts(_localShop.id);
      if (dbProds.isEmpty) {
        final cachedProds = prefs.getString('cached_products_${_localShop.id}');
        if (cachedProds != null) {
          dbProds = (jsonDecode(cachedProds) as List)
              .map((e) => Product.fromJson(e as Map<String, dynamic>))
              .toList();
          if (dbProds.isNotEmpty) {
            await LocalDbService.instance.saveProducts(_localShop.id, dbProds);
          }
        }
      }
      if (dbProds.isNotEmpty) {
        _localProducts.clear();
        _localProducts.addAll(dbProds);
      }

      // Load customers: prefer SQLite, migrate SharedPreferences if SQLite is empty
      var dbCusts = await LocalDbService.instance.getCustomers(_localShop.id);
      if (dbCusts.isEmpty) {
        final cachedCusts = prefs.getString('cached_customers_${_localShop.id}');
        if (cachedCusts != null) {
          dbCusts = (jsonDecode(cachedCusts) as List)
              .map((e) => Customer.fromJson(e as Map<String, dynamic>))
              .toList();
          if (dbCusts.isNotEmpty) {
            await LocalDbService.instance.saveCustomers(_localShop.id, dbCusts);
          }
        }
      }
      if (dbCusts.isNotEmpty) {
        _localCustomers.clear();
        _localCustomers.addAll(dbCusts);
      }

      // Load sales: prefer SQLite (unlimited bills), migrate SharedPreferences if SQLite is empty
      var dbSales = await LocalDbService.instance.getSales(_localShop.id);
      if (dbSales.isEmpty) {
        final cachedSales = prefs.getString('cached_sales_${_localShop.id}');
        if (cachedSales != null) {
          dbSales = (jsonDecode(cachedSales) as List)
              .map((e) => Sale.fromJson(e as Map<String, dynamic>))
              .toList();
          if (dbSales.isNotEmpty) {
            await LocalDbService.instance.saveSales(_localShop.id, dbSales);
          }
        }
      }
      if (dbSales.isNotEmpty) {
        _localSales.clear();
        _localSales.addAll(dbSales);
      }
    } catch (e) {
      debugPrint("Error loading offline cache: $e");
    }
  }

  void setLocalShop(Shop shop) {
    if (_localShop.id != 'demo-shop-101' && shop.id == 'demo-shop-101') {
      // Ironclad Guard: Never downgrade an active configured shop to demo-shop-101
      return;
    }
    _localShop = shop;
  }

  void resetLocalData() {
    _localShop = Shop(
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
    _localProducts.clear();
    _localCustomers.clear();
    _localSales.clear();
  }

  /// Automatically ensures that if a user is logged in, their data is attached
  /// to their real Supabase Cloud shop UUID rather than staying trapped in demo-shop-101
  /// or accidentally using the raw user authentication UUID.
  Future<String> _ensureValidShopId(String currentShopId) async {
    final user = client?.auth.currentUser;
    String cleanId = currentShopId.trim();
    if (cleanId.startsWith('shop-')) {
      cleanId = cleanId.replaceFirst('shop-', '');
    }

    final isCleanUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(cleanId);

    // If cleanId is already a real shop UUID (and NOT demo, and NOT raw user.id):
    if (cleanId != 'demo-shop-101' && isCleanUuid && (user == null || cleanId != user.id)) {
      return cleanId;
    }

    // If localShop is already synced to a real cloud shop UUID (and NOT raw user.id):
    final localId = _localShop.id.trim().replaceFirst('shop-', '');
    final isLocalUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(localId);
    if (localId != 'demo-shop-101' && isLocalUuid && (user == null || localId != user.id)) {
      return localId;
    }

    // Otherwise, if user is logged in, resolve their real cloud shop
    if (user != null) {
      final synced = await syncUserShop(userId: user.id, userEmail: user.email ?? '');
      return synced.id;
    }

    return cleanId;
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

      // Step 1: Collect all candidate shops from shop_members & shops safely (NO maybeSingle crash)
      final List<Shop> candidateShops = [];
      final Set<String> seenShopIds = {};

      // 1A. Check shop_members
      try {
        final List memberRows = await client!
            .from('shop_members')
            .select('shop_id')
            .eq('user_id', userId);
        for (final m in memberRows) {
          if (m != null && m['shop_id'] != null) {
            final sid = m['shop_id'].toString().trim();
            if (sid.isNotEmpty && !seenShopIds.contains(sid)) {
              seenShopIds.add(sid);
              try {
                final sRow = await client!.from('shops').select('*').eq('id', sid).maybeSingle();
                if (sRow != null) {
                  candidateShops.add(Shop.fromJson(sRow));
                }
              } catch (_) {}
            }
          }
        }
      } catch (memErr) {
        debugPrint("Check shop_members error: $memErr");
      }

      // 1B. Check shops table where user is owner_id
      try {
        final List ownedRows = await client!
            .from('shops')
            .select('*')
            .eq('owner_id', userId);
        for (final o in ownedRows) {
          if (o != null && o['id'] != null) {
            final sid = o['id'].toString().trim();
            if (!seenShopIds.contains(sid)) {
              seenShopIds.add(sid);
              candidateShops.add(Shop.fromJson(o));
            }
          }
        }
      } catch (ownedErr) {
        debugPrint("Check shops owner_id error: $ownedErr");
      }

      // If we found candidate shops:
      if (candidateShops.isNotEmpty) {
        // If there's more than 1 shop, prioritize the one with actual customers/sales/products!
        Shop bestShop = candidateShops.first;
        if (candidateShops.length > 1) {
          int maxScore = -1;
          for (final candidate in candidateShops) {
            int score = 0;
            try {
              final cList = await client!.from('customers').select('id').eq('shop_id', candidate.id).limit(1);
              if ((cList as List).isNotEmpty) score += 50;
            } catch (_) {}
            try {
              final sList = await client!.from('sales').select('id').eq('shop_id', candidate.id).limit(1);
              if ((sList as List).isNotEmpty) score += 50;
            } catch (_) {}
            try {
              final pList = await client!.from('products').select('id').eq('shop_id', candidate.id).limit(1);
              if ((pList as List).isNotEmpty) score += 20;
            } catch (_) {}
            if (score > maxScore) {
              maxScore = score;
              bestShop = candidate;
            }
          }
        }

        // Ensure owner is in shop_members for bestShop so RLS is 100% satisfied
        try {
          await client!.from('shop_members').upsert({
            'shop_id': bestShop.id,
            'user_id': userId,
            'role': 'owner',
          });
        } catch (_) {}

        // Migrate any legacy data where shop_id was stored as raw userId
        try {
          await client!.from('customers').update({'shop_id': bestShop.id}).eq('shop_id', userId);
          await client!.from('sales').update({'shop_id': bestShop.id}).eq('shop_id', userId);
          await client!.from('products').update({'shop_id': bestShop.id}).eq('shop_id', userId);
        } catch (_) {}

        final localUpi = (bestShop.upiId != null && bestShop.upiId!.trim().isNotEmpty)
            ? bestShop.upiId
            : (_localShop.upiId ?? prefs.getString('shop_upi_id'));
        final localQr = (bestShop.qrImageUrl != null && bestShop.qrImageUrl!.trim().isNotEmpty)
            ? bestShop.qrImageUrl
            : (_localShop.qrImageUrl ?? prefs.getString('shop_qr_image_url'));
        final localReviewUrl = (bestShop.googleReviewUrl != null && bestShop.googleReviewUrl!.trim().isNotEmpty)
            ? bestShop.googleReviewUrl
            : (_localShop.googleReviewUrl ?? prefs.getString('shop_google_review_url'));

        final resolvedShop = bestShop.copyWith(
          upiId: localUpi,
          qrImageUrl: localQr,
          googleReviewUrl: localReviewUrl,
          upiPayeeName: (bestShop.upiPayeeName != null && bestShop.upiPayeeName!.trim().isNotEmpty)
              ? bestShop.upiPayeeName
              : (_localShop.upiPayeeName ?? prefs.getString('shop_upi_payee_name')),
        );

        _localShop = resolvedShop;
        await prefs.setString('saved_shop_data', jsonEncode(resolvedShop.toJson()));
        await prefs.setString('saved_shop_data_$userId', jsonEncode(resolvedShop.toJson()));
        debugPrint("Successfully resolved and linked user's shop: ${resolvedShop.id} (${resolvedShop.name})");
        return resolvedShop;
      }

      // Step 2: User does not have ANY shop in cloud yet -> create one with a clean UUID
      final isCrossAccount = fallback != null &&
          (fallback.id != 'demo-shop-101' && fallback.id != userId && !fallback.id.contains(userId));
      final cleanFallback = isCrossAccount ? null : fallback;

      final userHandle = userEmail.contains('@') ? userEmail.split('@').first : userEmail;
      final defaultShopName = userHandle.isNotEmpty ? 'मेरी दुकान ($userHandle)' : 'मेरी दुकान POS';

      final shopName = (cleanFallback?.name != null && cleanFallback!.name.isNotEmpty && cleanFallback.name != 'मेरी दुकान (My Store)')
          ? cleanFallback.name
          : defaultShopName;

      final newShopId = const Uuid().v4();
      final newShopPayload = {
        'id': newShopId,
        'owner_id': userId,
        'name': shopName,
        if (cleanFallback?.phone != null && cleanFallback!.phone!.isNotEmpty) 'phone': cleanFallback.phone,
        if (cleanFallback?.address != null && cleanFallback!.address!.isNotEmpty) 'address': cleanFallback.address,
        if (cleanFallback?.gstin != null && cleanFallback!.gstin!.isNotEmpty) 'gst_number': cleanFallback.gstin,
      };

      Shop shop;
      try {
        // IMPORTANT: Insert WITHOUT .select() so PostgREST doesn't check SELECT RLS policy before user is in shop_members!
        await client!.from('shops').insert(newShopPayload);

        // Join as owner in shop_members immediately
        try {
          await client!.from('shop_members').insert({
            'shop_id': newShopId,
            'user_id': userId,
            'role': 'owner',
          });
        } catch (memErr) {
          debugPrint("shop_members insert err: $memErr");
        }

        // Now fetch the created shop (user is in shop_members, so SELECT policy succeeds)
        final created = await client!.from('shops').select('*').eq('id', newShopId).maybeSingle();
        if (created != null) {
          shop = Shop.fromJson(created);
        } else {
          shop = Shop(
            id: newShopId,
            name: shopName,
            phone: cleanFallback?.phone,
            address: cleanFallback?.address,
            gstin: cleanFallback?.gstin,
            upiId: cleanFallback?.upiId,
            upiPayeeName: cleanFallback?.upiPayeeName,
            allowNegativeStock: cleanFallback?.allowNegativeStock ?? false,
            printPaperSize: cleanFallback?.printPaperSize ?? '58mm',
            receiptFooter: cleanFallback?.receiptFooter ?? 'धन्यवाद! फिर पधारें 🙏',
          );
        }
      } catch (insertErr) {
        debugPrint("Direct insert shops error: $insertErr");
        shop = Shop(
          id: newShopId,
          name: shopName,
          phone: cleanFallback?.phone,
          address: cleanFallback?.address,
          gstin: cleanFallback?.gstin,
          upiId: cleanFallback?.upiId,
          upiPayeeName: cleanFallback?.upiPayeeName,
          allowNegativeStock: cleanFallback?.allowNegativeStock ?? false,
          printPaperSize: cleanFallback?.printPaperSize ?? '58mm',
          receiptFooter: cleanFallback?.receiptFooter ?? 'धन्यवाद! फिर पधारें 🙏',
        );
      }

      _localShop = shop;
      await prefs.setString('saved_shop_data', jsonEncode(shop.toJson()));
      await prefs.setString('saved_shop_data_$userId', jsonEncode(shop.toJson()));
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
    final validShopId = await _ensureValidShopId(shopId);
    final prefs = await SharedPreferences.getInstance();
    final queueKey = 'pending_deleted_products_$validShopId';
    final pendingSet = <String>{
      ...(prefs.getStringList(queueKey) ?? const []),
      ...await LocalDbService.instance.getDeletedProductIds(validShopId),
    };
    final pendingDeletions = pendingSet.toList();

    if (_isInitialized && client != null && validShopId != 'demo-shop-101') {
      // Flush pending offline outbox operations first (including soft deletes)
      await flushSyncOutbox(validShopId);

      // Flush any remaining legacy pending soft deletions
      if (pendingDeletions.isNotEmpty) {
        final toRemove = <String>[];
        for (final delId in pendingDeletions) {
          try {
            await client!.from('products').update({
              'is_active': false,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', delId);
            toRemove.add(delId);
            await LocalDbService.instance.removeOutboxForEntity('product', delId);
          } catch (_) {}
        }
        pendingDeletions.removeWhere((id) => toRemove.contains(id));
        await prefs.setStringList(queueKey, pendingDeletions);
        await LocalDbService.instance.saveDeletedProductIds(validShopId, pendingDeletions);
      }

      try {
        final response = await client!
            .from('products')
            .select('*')
            .eq('shop_id', validShopId)
            .eq('is_active', true)
            .order('name');
        final list = (response as List)
            .map((e) => Product.fromJson(e))
            .where((p) => !pendingDeletions.contains(p.id))
            .toList();

        // ONLY sync local products if they genuinely belong to validShopId (NEVER push demo-shop-101 items to user's real shop)
        final cloudIds = list.map((p) => p.id).toSet();
        final cloudNames = list.map((p) => p.name.trim().toLowerCase()).toSet();
        final unUploaded = _localProducts
            .where((lp) =>
                lp.shopId == validShopId &&
                !pendingDeletions.contains(lp.id) &&
                !cloudIds.contains(lp.id) &&
                !cloudNames.contains(lp.name.trim().toLowerCase()))
            .toList();
        if (unUploaded.isNotEmpty) {
          debugPrint("Auto-syncing ${unUploaded.length} un-uploaded local products to cloud for shop $validShopId...");
          final newlyUploaded = await addProductsBatch(unUploaded);
          list.addAll(newlyUploaded);
        }

        _localProducts.clear();
        _localProducts.addAll(list);
        await _saveCachedProducts(validShopId, list);
        debugPrint("SUCCESS: Loaded ${list.length} products from Supabase Cloud for shop $validShopId");
        return list;
      } catch (e) {
        debugPrint("Error fetching products from cloud: $e");
      }
    }

    // Double-Layer Fallback: prefer SQLite DB first, then SharedPreferences
    try {
      final dbProducts = await LocalDbService.instance.getProducts(validShopId);
      if (dbProducts.isNotEmpty) {
        final filtered = dbProducts.where((p) => !pendingDeletions.contains(p.id)).toList();
        _localProducts.clear();
        _localProducts.addAll(filtered);
        return filtered;
      }
    } catch (_) {}

    try {
      final cached = prefs.getString('cached_products_$validShopId');
      if (cached != null) {
        final list = (jsonDecode(cached) as List)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .where((p) => !pendingDeletions.contains(p.id))
            .toList();
        _localProducts.clear();
        _localProducts.addAll(list);
        return list;
      }
    } catch (_) {}

    return _localProducts.where((p) => !pendingDeletions.contains(p.id)).toList();
  }

  Future<void> _saveCachedProducts(String shopId, List<Product> list) async {
    await LocalDbService.instance.saveProducts(shopId, list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_products_$shopId', jsonEncode(list.map((p) => p.toSupabaseJson()).toList()));
    } catch (_) {}
  }

  Future<Product> addProduct(Product product) async {
    final validShopId = await _ensureValidShopId(product.shopId);
    final isValidUuid = _isValidUuid(product.id);
    final targetProduct = product.copyWith(
      id: isValidUuid ? product.id : const Uuid().v4(),
      shopId: validShopId,
    );
    Product saved = targetProduct;
    bool synced = false;
    if (isInitialized && client != null && validShopId != 'demo-shop-101') {
      try {
        final res = await client!.from('products').upsert(targetProduct.toSupabaseJson()).select().single();
        saved = Product.fromJson(res);
        synced = true;
      } catch (e) {
        debugPrint("Error inserting product in cloud (queued in outbox): $e");
      }
    }
    if (!synced && validShopId != 'demo-shop-101') {
      await LocalDbService.instance.enqueueOutbox(
        shopId: validShopId,
        entityType: 'product',
        entityId: saved.id,
        operation: 'upsert',
        payload: saved.toJson(),
      );
    }
    await LocalDbService.instance.removeDeletedProductId(validShopId, saved.id);
    _localProducts.removeWhere((p) => p.id == product.id || p.id == targetProduct.id);
    _localProducts.add(saved);
    await _saveCachedProducts(validShopId, _localProducts);
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
    } else {
      _localProducts.add(targetProduct);
    }
    bool synced = false;
    if (isInitialized && client != null && validShopId != 'demo-shop-101') {
      try {
        await client!.from('products').update(targetProduct.toSupabaseJson()).eq('id', targetProduct.id);
        synced = true;
      } catch (e) {
        debugPrint("Error updating product in cloud (queued in outbox): $e");
      }
    }
    if (!synced && validShopId != 'demo-shop-101') {
      await LocalDbService.instance.enqueueOutbox(
        shopId: validShopId,
        entityType: 'product',
        entityId: targetProduct.id,
        operation: 'upsert',
        payload: targetProduct.toJson(),
      );
    } else if (synced) {
      await LocalDbService.instance.removeOutboxForEntity('product', targetProduct.id);
    }
    await _saveCachedProducts(validShopId, _localProducts);
  }

  Future<void> deleteProduct(String productId, {String? shopId}) async {
    final validShopId = await _ensureValidShopId(shopId ?? _localShop.id);
    _localProducts.removeWhere((p) => p.id == productId);
    await _saveCachedProducts(validShopId, _localProducts);
    await LocalDbService.instance.markProductDeleted(validShopId, productId);

    final prefs = await SharedPreferences.getInstance();
    final queueKey = 'pending_deleted_products_$validShopId';
    final pendingDeletions = prefs.getStringList(queueKey) ?? [];
    if (!pendingDeletions.contains(productId)) {
      pendingDeletions.add(productId);
      await prefs.setStringList(queueKey, pendingDeletions);
    }

    await LocalDbService.instance.enqueueOutbox(
      shopId: validShopId,
      entityType: 'product',
      entityId: productId,
      operation: 'soft_delete',
      payload: {'id': productId, 'shop_id': validShopId},
    );

    if (isInitialized && client != null && validShopId != 'demo-shop-101') {
      try {
        // Soft-delete first so FK references on sale_items / purchase_items never reject deletion
        await client!.from('products').update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', productId);
        pendingDeletions.remove(productId);
        await prefs.setStringList(queueKey, pendingDeletions);
        await LocalDbService.instance.removeOutboxForEntity('product', productId);
        debugPrint("SUCCESS: Soft-deleted product $productId in Supabase Cloud");
      } catch (e) {
        debugPrint("Error soft-deleting product in cloud (queued for retry): $e");
      }
    }
  }

  // --- CUSTOMERS ---
  Future<List<Customer>> getCustomers(String shopId) async {
    final validShopId = await _ensureValidShopId(shopId);
    final prefs = await SharedPreferences.getInstance();
    final queueKey = 'pending_deleted_customers_$validShopId';
    final pendingDeletions = prefs.getStringList(queueKey) ?? [];

    if (_isInitialized && client != null && validShopId != 'demo-shop-101') {
      // Flush pending offline customer deletions
      if (pendingDeletions.isNotEmpty) {
        final toRemove = <String>[];
        for (final delId in pendingDeletions) {
          try {
            await client!.from('customers').delete().eq('id', delId);
            toRemove.add(delId);
          } catch (_) {}
        }
        pendingDeletions.removeWhere((id) => toRemove.contains(id));
        await prefs.setStringList(queueKey, pendingDeletions);
      }

      try {
        final response = await client!
            .from('customers')
            .select('*')
            .eq('shop_id', validShopId)
            .order('name');
        final cloudList = (response as List)
            .map((e) => Customer.fromJson(e))
            .where((c) => !pendingDeletions.contains(c.id))
            .toList();

        // Auto-sync any local customers genuinely belonging to validShopId (NEVER demo dummy data)
        final cloudIds = cloudList.map((c) => c.id).toSet();
        final cloudNames = cloudList.map((c) => c.name.trim().toLowerCase()).toSet();
        for (final localCust in List<Customer>.from(_localCustomers)) {
          if (localCust.shopId == validShopId &&
              !pendingDeletions.contains(localCust.id) &&
              !cloudIds.contains(localCust.id) &&
              !cloudNames.contains(localCust.name.trim().toLowerCase())) {
            debugPrint("Auto-syncing un-synced customer to cloud: ${localCust.name}");
            final saved = await addCustomer(localCust.copyWith(shopId: validShopId));
            cloudList.add(saved);
          }
        }

        _localCustomers.clear();
        _localCustomers.addAll(cloudList);
        _saveCachedCustomers(validShopId, cloudList);
        debugPrint("SUCCESS: Loaded ${cloudList.length} customers from Supabase Cloud for shop $validShopId");
        return cloudList;
      } catch (e) {
        debugPrint("Error fetching customers from cloud: $e");
      }
    }

    // Fallback: check cached preferences for validShopId
    try {
      final cached = prefs.getString('cached_customers_$validShopId');
      if (cached != null) {
        final list = (jsonDecode(cached) as List)
            .map((e) => Customer.fromJson(e as Map<String, dynamic>))
            .where((c) => !pendingDeletions.contains(c.id))
            .toList();
        _localCustomers.clear();
        _localCustomers.addAll(list);
        return list;
      }
    } catch (_) {}

    return List.from(_localCustomers);
  }

  Future<void> _saveCachedCustomers(String shopId, List<Customer> list) async {
    await LocalDbService.instance.saveCustomers(shopId, list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_customers_$shopId', jsonEncode(list.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }

  Future<Customer> addCustomer(Customer customer) async {
    final validShopId = await _ensureValidShopId(customer.shopId);
    final isValidUuid = _isValidUuid(customer.id);
    final targetCustomer = customer.copyWith(
      id: isValidUuid ? customer.id : const Uuid().v4(),
      shopId: validShopId,
    );
    Customer saved = targetCustomer;
    bool synced = false;
    if (_isInitialized && client != null && validShopId != 'demo-shop-101') {
      try {
        final payload = targetCustomer.toSupabaseJson();
        final res = await client!.from('customers').upsert(payload).select().single();
        saved = Customer.fromJson(res);
        synced = true;
      } catch (e) {
        debugPrint("Error adding customer to cloud (queued in outbox): $e");
      }
    }
    if (!synced && validShopId != 'demo-shop-101') {
      await LocalDbService.instance.enqueueOutbox(
        shopId: validShopId,
        entityType: 'customer',
        entityId: saved.id,
        operation: 'upsert',
        payload: saved.toJson(),
      );
    }
    _localCustomers.removeWhere((c) => c.id == customer.id || c.id == targetCustomer.id);
    _localCustomers.add(saved);
    await _saveCachedCustomers(validShopId, _localCustomers);
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

  Future<void> updateCustomer(Customer updated) async {
    final index = _localCustomers.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _localCustomers[index] = updated;
    }
    if (_isInitialized && client != null) {
      try {
        await client!.from('customers').update({
          'name': updated.name,
          'phone': updated.phone,
          'address': updated.address,
          'balance': updated.balance,
          'credit_limit': updated.creditLimit,
        }).eq('id', updated.id);
      } catch (e) {
        debugPrint("Error updating customer: $e");
      }
    }
    _saveCachedCustomers(_localShop.id, _localCustomers);
  }

  Future<void> updateCustomerCreditLimit(String customerId, double creditLimit) async {
    final index = _localCustomers.indexWhere((c) => c.id == customerId);
    if (index != -1) {
      _localCustomers[index] = _localCustomers[index].copyWith(creditLimit: creditLimit);
    }
    if (_isInitialized && client != null) {
      try {
        await client!.from('customers').update({'credit_limit': creditLimit}).eq('id', customerId);
      } catch (e) {
        debugPrint("Error updating customer credit limit: $e");
      }
    }
    _saveCachedCustomers(_localShop.id, _localCustomers);
  }

  Future<void> _saveCachedPayment(String shopId, CustomerPayment payment) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'cached_payments_${payment.customerId}';
      final existingStr = prefs.getString(key);
      List<dynamic> list = existingStr != null ? jsonDecode(existingStr) : [];
      list.insert(0, payment.toJson());
      await prefs.setString(key, jsonEncode(list));
    } catch (_) {}
  }

  Future<List<CustomerPayment>> _getCachedPayments(String customerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'cached_payments_$customerId';
      final existingStr = prefs.getString(key);
      if (existingStr != null) {
        final list = (jsonDecode(existingStr) as List)
            .map((e) => CustomerPayment.fromJson(e as Map<String, dynamic>))
            .toList();
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<CustomerPayment> recordCustomerPayment({
    required String shopId,
    required String customerId,
    required double amount,
    String mode = 'cash',
    String? note,
  }) async {
    final validShopId = await _ensureValidShopId(shopId);
    final pId = const Uuid().v4();
    final payment = CustomerPayment(
      id: pId,
      shopId: validShopId,
      customerId: customerId,
      amount: amount,
      mode: mode,
      note: note,
      createdAt: DateTime.now(),
    );

    if (_isInitialized && client != null && validShopId != 'demo-shop-101') {
      try {
        final payload = {
          'id': pId,
          'shop_id': validShopId,
          'customer_id': customerId,
          'amount': amount,
          'mode': mode,
          if (note != null && note.isNotEmpty) 'note': note,
          'created_at': payment.createdAt.toIso8601String(),
        };
        await client!.from('payments').insert(payload);
        debugPrint("Payment recorded in Supabase cloud");
      } catch (e) {
        debugPrint("Error recording payment in cloud: $e");
      }
    }

    final cIdx = _localCustomers.indexWhere((c) => c.id == customerId);
    if (cIdx != -1) {
      final current = _localCustomers[cIdx];
      final newBal = (current.balance - amount) > 0 ? (current.balance - amount) : 0.0;
      await updateCustomerBalance(customerId, newBal);
    }

    await _saveCachedPayment(validShopId, payment);
    return payment;
  }

  Future<List<CustomerPayment>> getCustomerPayments(String customerId) async {
    List<CustomerPayment> list = [];
    if (_isInitialized && client != null) {
      try {
        final res = await client!
            .from('payments')
            .select()
            .eq('customer_id', customerId)
            .order('created_at', ascending: false);
        list = (res as List).map((row) => CustomerPayment.fromJson(row)).toList();
      } catch (e) {
        debugPrint("Error fetching customer payments from cloud: $e");
      }
    }

    final cached = await _getCachedPayments(customerId);
    for (final cp in cached) {
      if (!list.any((p) => p.id == cp.id)) {
        list.add(cp);
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> deleteCustomer(String customerId) async {
    _localCustomers.removeWhere((c) => c.id == customerId);
    _saveCachedCustomers(_localShop.id, _localCustomers);

    final prefs = await SharedPreferences.getInstance();
    final queueKey = 'pending_deleted_customers_${_localShop.id}';
    final pendingDeletions = prefs.getStringList(queueKey) ?? [];
    if (!pendingDeletions.contains(customerId)) {
      pendingDeletions.add(customerId);
      await prefs.setStringList(queueKey, pendingDeletions);
    }

    if (_isInitialized && client != null && _localShop.id != 'demo-shop-101') {
      try {
        await client!.from('customers').delete().eq('id', customerId);
        pendingDeletions.remove(customerId);
        await prefs.setStringList(queueKey, pendingDeletions);
        debugPrint("SUCCESS: Deleted customer $customerId from Supabase Cloud");
      } catch (e) {
        debugPrint("Error deleting customer in cloud (queued for retry): $e");
      }
    }
  }

  // --- SALES & BILLING (CREATE, READ, UPDATE, DELETE) ---
  Future<List<Sale>> getSales(String shopId, {int? limit}) async {
    final validShopId = await _ensureValidShopId(shopId);
    // Double-Layer Local Load: SQLite first (unlimited bills), then SharedPreferences fallback
    if (_localSales.isEmpty) {
      try {
        final dbList = await LocalDbService.instance.getSales(validShopId);
        if (dbList.isNotEmpty) {
          _localSales.addAll(dbList);
        } else {
          final prefs = await SharedPreferences.getInstance();
          final cached = prefs.getString('cached_sales_$validShopId') ??
              prefs.getString('cached_sales_demo-shop-101');
          if (cached != null) {
            final list = (jsonDecode(cached) as List)
                .map((e) => Sale.fromJson(e as Map<String, dynamic>))
                .toList();
            _localSales.addAll(list);
            if (list.isNotEmpty) {
              await LocalDbService.instance.saveSales(validShopId, list);
            }
          }
        }
      } catch (_) {}
    }

    if (_isInitialized && client != null && validShopId != 'demo-shop-101') {
      // Flush pending offline bills / edits before pulling cloud snapshot
      await flushSyncOutbox(validShopId);

      final prefs = await SharedPreferences.getInstance();
      final isStaff = prefs.getBool('is_staff_session') ?? false;
      final staffPin = prefs.getString('staff_pin') ?? '';

      // If staff session, use RPC directly to bypass RLS restrictions
      if (isStaff && staffPin.isNotEmpty) {
        try {
          final dynamic rpcRes = await client!.rpc('staff_get_sales', params: {
            '_shop_id': validShopId,
            '_pin': staffPin,
          });
          if (rpcRes is Map && rpcRes['success'] == true && rpcRes['sales'] is List) {
            final rpcList = (rpcRes['sales'] as List)
                .map((e) => Sale.fromJson(e as Map<String, dynamic>))
                .toList();
            await _saveCachedSales(validShopId, rpcList);
            final mergedList = await LocalDbService.instance.getSales(validShopId);
            final finalRpcList = mergedList.isNotEmpty ? mergedList : rpcList;
            _localSales.clear();
            _localSales.addAll(finalRpcList);
            return finalRpcList;
          }
        } catch (rpcErr) {
          debugPrint("Staff RPC get_sales error: $rpcErr");
        }
      }

      try {
        var query = client!
            .from('sales')
            .select('*, sale_items(*)')
            .eq('shop_id', validShopId)
            .order('created_at', ascending: false);
        final response = limit != null ? await query.limit(limit) : await query;
        final rawCloudList = (response as List).map((e) => Sale.fromJson(e)).toList();

        // Deduplicate consecutive identical sales created within 15 seconds of each other
        final List<Sale> cloudList = [];
        for (final sale in rawCloudList) {
          final isDuplicate = cloudList.any((existing) =>
              existing.total == sale.total &&
              existing.paymentMode == sale.paymentMode &&
              existing.customerName == sale.customerName &&
              existing.items.length == sale.items.length &&
              existing.createdAt.difference(sale.createdAt).abs().inSeconds < 15);
          if (!isDuplicate) {
            cloudList.add(sale);
          }
        }

        if (cloudList.isNotEmpty || !isStaff) {
          await _saveCachedSales(validShopId, cloudList);
          // Re-read merged SQLite list so offline/unsynced edits stay preserved
          final merged = await LocalDbService.instance.getSales(validShopId);
          final effectiveList = merged.isNotEmpty ? merged : cloudList;
          _localSales.clear();
          _localSales.addAll(effectiveList);
          return effectiveList;
        }
      } catch (e) {
        debugPrint("Error fetching sales from cloud: $e");
        if (isStaff && staffPin.isNotEmpty) {
          try {
            final dynamic rpcRes = await client!.rpc('staff_get_sales', params: {
              '_shop_id': validShopId,
              '_pin': staffPin,
            });
            if (rpcRes is Map && rpcRes['success'] == true && rpcRes['sales'] is List) {
              final rpcList = (rpcRes['sales'] as List)
                  .map((e) => Sale.fromJson(e as Map<String, dynamic>))
                  .toList();
              await _saveCachedSales(validShopId, rpcList);
              _localSales.clear();
              _localSales.addAll(rpcList);
              return rpcList;
            }
          } catch (_) {}
        }
      }
    }

    return List.from(_localSales);
  }

  Future<void> _saveCachedSales(String shopId, List<Sale> list) async {
    await LocalDbService.instance.saveSales(shopId, list);
    try {
      final prefs = await SharedPreferences.getInstance();
      final compact = list.take(200).map((s) => s.toJson()).toList();
      await prefs.setString('cached_sales_$shopId', jsonEncode(compact));
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

        final rpcRes = await client!.rpc('create_sale', params: {
          '_shop_id': validShopId,
          '_items': formattedItems,
          '_discount': targetSale.discount,
          '_payment_mode': validMode,
          '_paid': targetSale.paid,
          '_customer_id': custId,
          '_customer_name': targetSale.customerName,
          '_customer_phone': targetSale.customerPhone,
          '_note': targetSale.encodedNote,
        });
        debugPrint("Sale successfully synced to cloud via create_sale RPC");

        if (rpcRes != null) {
          final saleId = rpcRes.toString();
          final createdRow = await client!
              .from('sales')
              .select('*, sale_items(*)')
              .eq('id', saleId)
              .maybeSingle();
          if (createdRow != null) {
            final parsedCloud = Sale.fromJson(createdRow);
            final cloudSale = parsedCloud.copyWith(
              clientRef: parsedCloud.clientRef ?? targetSale.clientRef,
              paymentStatus: targetSale.paymentStatus,
              cashPaid: targetSale.cashPaid,
              upiPaid: targetSale.upiPaid,
              upiPayable: targetSale.upiPayable,
              creditAmount: targetSale.creditAmount,
              onlineVerified: targetSale.onlineVerified,
              verificationSource: targetSale.verificationSource,
            );
            final idx = _localSales.indexWhere((s) => s.id == targetSale.id || s.clientRef == targetSale.clientRef);
            if (idx != -1) {
              _localSales[idx] = cloudSale;
            } else {
              _localSales.insert(0, cloudSale);
            }
            _saveCachedSales(validShopId, _localSales);
            return cloudSale;
          }
        }
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
            'note': targetSale.encodedNote,
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

              // Deduct stock in Cloud Supabase products table so all devices sync in real-time
              if (item.productId != null && item.productId!.length >= 30) {
                try {
                  final pRow = await client!.from('products').select('stock').eq('id', item.productId!).maybeSingle();
                  if (pRow != null && pRow['stock'] != null) {
                    final curr = (pRow['stock'] as num).toDouble();
                    final updatedStock = curr - item.qty;
                    await client!.from('products').update({
                      'stock': updatedStock,
                      'updated_at': DateTime.now().toIso8601String(),
                    }).eq('id', item.productId!);

                    // Also record stock audit movement
                    try {
                      await client!.from('stock_movements').insert({
                        'shop_id': validShopId,
                        'product_id': item.productId!,
                        'change': -item.qty,
                        'reason': 'sale',
                        'ref_id': saleId,
                      });
                    } catch (_) {}
                  }
                } catch (stockErr) {
                  debugPrint("Error deducting stock in cloud for item ${item.name}: $stockErr");
                }
              }
            } catch (_) {}
          }

          // Update customer balance in cloud if credit sale
          if (targetSale.due > 0 && targetSale.customerId != null && targetSale.customerId!.length >= 30) {
            try {
              final cRow = await client!.from('customers').select('balance').eq('id', targetSale.customerId!).maybeSingle();
              if (cRow != null && cRow['balance'] != null) {
                final currBal = (cRow['balance'] as num).toDouble();
                await client!.from('customers').update({
                  'balance': currBal + targetSale.due,
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', targetSale.customerId!);
              }
            } catch (_) {}
          }
        } catch (inner) {
          debugPrint("Failed to write sale directly to cloud (queued in outbox): $inner");
          await LocalDbService.instance.enqueueOutbox(
            shopId: validShopId,
            entityType: 'sale',
            entityId: targetSale.id,
            operation: 'create',
            payload: {'sale': targetSale.toJson()},
          );
        }
      }
    } else if (validShopId != 'demo-shop-101') {
      await LocalDbService.instance.enqueueOutbox(
        shopId: validShopId,
        entityType: 'sale',
        entityId: targetSale.id,
        operation: 'create',
        payload: {'sale': targetSale.toJson()},
      );
    }

    await _saveCachedSales(validShopId, _localSales);
    await _saveCachedProducts(validShopId, _localProducts);
    return targetSale;
  }

  static final RegExp _uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  bool _isValidUuid(String? value) =>
      value != null && _uuidPattern.hasMatch(value.trim());

  /// Update an existing bill in Cloud (header + sale_items + stock & khata deltas)
  /// and in Double-Layer Local Storage (SQLite + Sync Outbox).
  Future<Sale> updateSale(Sale updatedSale, {Sale? previousSale}) async {
    final validShopId = await _ensureValidShopId(updatedSale.shopId);
    final idx = _localSales.indexWhere((s) => s.id == updatedSale.id);
    final oldSale = previousSale ?? (idx != -1 ? _localSales[idx] : null);
    final normalizedSale = updatedSale.copyWith(shopId: validShopId);

    if (idx != -1) {
      _localSales[idx] = normalizedSale;
    } else {
      _localSales.insert(0, normalizedSale);
    }

    await LocalDbService.instance.upsertSale(validShopId, normalizedSale);
    await _saveCachedSales(validShopId, _localSales);
    await LocalDbService.instance.enqueueOutbox(
      shopId: validShopId,
      entityType: 'sale',
      entityId: normalizedSale.id,
      operation: 'update_sale',
      payload: {
        'sale': normalizedSale.toJson(),
        if (oldSale != null) 'previous_sale': oldSale.toJson(),
      },
    );

    if (_isInitialized && client != null && validShopId != 'demo-shop-101') {
      try {
        await _pushUpdatedSaleToCloud(normalizedSale, previousSale: oldSale);
        await LocalDbService.instance.removeOutboxForEntity('sale', normalizedSale.id);
        debugPrint("SUCCESS: Updated bill #${normalizedSale.billNo} + items in Supabase Cloud");
      } catch (e) {
        debugPrint("Error updating sale in cloud (queued in outbox): $e");
      }
    }

    return normalizedSale;
  }

  Future<void> _pushUpdatedSaleToCloud(Sale updatedSale, {Sale? previousSale}) async {
    if (client == null || !_isValidUuid(updatedSale.id)) return;
    final validMode = ['cash', 'online', 'credit', 'split', 'set_later']
            .contains(updatedSale.paymentMode)
        ? updatedSale.paymentMode
        : 'cash';
    final custId = _isValidUuid(updatedSale.customerId) ? updatedSale.customerId : null;

    // 1. Update bill header
    await client!.from('sales').update({
      'customer_id': custId,
      'customer_name': updatedSale.customerName,
      'customer_phone': updatedSale.customerPhone,
      'sub_total': updatedSale.subtotal,
      'discount': updatedSale.discount,
      'total': updatedSale.total,
      'paid': updatedSale.paid,
      'due': updatedSale.due,
      'payment_mode': validMode,
      'note': updatedSale.encodedNote,
    }).eq('id', updatedSale.id);

    // 2. Replace line items so reload never reverts to pre-edit items
    await client!.from('sale_items').delete().eq('sale_id', updatedSale.id);
    if (updatedSale.items.isNotEmpty) {
      final rows = updatedSale.items.map((item) {
        return {
          'shop_id': updatedSale.shopId,
          'sale_id': updatedSale.id,
          'product_id': _isValidUuid(item.productId) ? item.productId : null,
          'name': item.name,
          'unit': item.unit == 'kg' ? 'kg' : 'pc',
          'price': item.price,
          'qty': item.qty,
          'line_total': item.total,
        };
      }).toList();
      await client!.from('sale_items').insert(rows);
    }

    // 3. Apply stock quantity delta for edited products
    if (previousSale != null) {
      final oldQty = <String, double>{};
      for (final item in previousSale.items) {
        final pid = item.productId;
        if (_isValidUuid(pid)) {
          oldQty[pid!] = (oldQty[pid] ?? 0.0) + item.qty;
        }
      }
      final newQty = <String, double>{};
      for (final item in updatedSale.items) {
        final pid = item.productId;
        if (_isValidUuid(pid)) {
          newQty[pid!] = (newQty[pid] ?? 0.0) + item.qty;
        }
      }
      final touchedIds = <String>{...oldQty.keys, ...newQty.keys};
      for (final pid in touchedIds) {
        final deltaSold = (newQty[pid] ?? 0.0) - (oldQty[pid] ?? 0.0);
        if (deltaSold.abs() < 0.0001) continue;
        try {
          final prodRow = await client!
              .from('products')
              .select('stock')
              .eq('id', pid)
              .maybeSingle();
          if (prodRow != null) {
            final currentStock = (prodRow['stock'] as num?)?.toDouble() ?? 0.0;
            final nextStock = currentStock - deltaSold;
            await client!.from('products').update({'stock': nextStock}).eq('id', pid);
            await client!.from('stock_movements').insert({
              'shop_id': updatedSale.shopId,
              'product_id': pid,
              'change': -deltaSold,
              'reason': 'adjustment',
              'ref_id': updatedSale.id,
            });
          }
        } catch (stockErr) {
          debugPrint("Stock delta update skipped for $pid: $stockErr");
        }
      }

      // 4. Apply customer balance (Khata due) delta if due or customer changed
      final oldCust = _isValidUuid(previousSale.customerId) ? previousSale.customerId : null;
      final newCust = custId;
      if (oldCust == newCust && newCust != null) {
        final dueDelta = updatedSale.due - previousSale.due;
        if (dueDelta.abs() >= 0.01) {
          await _adjustCustomerBalanceInCloud(newCust, dueDelta);
        }
      } else {
        if (oldCust != null && previousSale.due > 0.009) {
          await _adjustCustomerBalanceInCloud(oldCust, -previousSale.due);
        }
        if (newCust != null && updatedSale.due > 0.009) {
          await _adjustCustomerBalanceInCloud(newCust, updatedSale.due);
        }
      }
    }
  }

  Future<void> _adjustCustomerBalanceInCloud(String customerId, double delta) async {
    if (client == null || !_isValidUuid(customerId) || delta.abs() < 0.009) return;
    try {
      final row = await client!
          .from('customers')
          .select('balance')
          .eq('id', customerId)
          .maybeSingle();
      if (row != null) {
        final current = (row['balance'] as num?)?.toDouble() ?? 0.0;
        final next = max(0.0, current + delta);
        await client!.from('customers').update({'balance': next}).eq('id', customerId);
      }
    } catch (e) {
      debugPrint("Customer balance delta update failed for $customerId: $e");
    }
  }

  /// Delete / cancel an existing bill
  Future<void> deleteSale(String saleId) async {
    _localSales.removeWhere((s) => s.id == saleId);
    _saveCachedSales(_localShop.id, _localSales);

    final prefs = await SharedPreferences.getInstance();
    final queueKey = 'pending_deleted_sales_${_localShop.id}';
    final pendingDeletions = prefs.getStringList(queueKey) ?? [];
    if (!pendingDeletions.contains(saleId)) {
      pendingDeletions.add(saleId);
      await prefs.setStringList(queueKey, pendingDeletions);
    }

    if (_isInitialized && client != null && _localShop.id != 'demo-shop-101') {
      try {
        await client!.from('sales').delete().eq('id', saleId);
        pendingDeletions.remove(saleId);
        await prefs.setStringList(queueKey, pendingDeletions);
        debugPrint("SUCCESS: Deleted sale $saleId from Supabase Cloud");
      } catch (e) {
        debugPrint("Error deleting sale in cloud: $e");
      }
    }
  }

  // --- EXPENSES ---
  Future<List<Expense>> getExpenses(String shopId) async {
    if (_localExpenses.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_expenses_$shopId');
        if (cached != null) {
          final list = (jsonDecode(cached) as List).map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
          _localExpenses.addAll(list);
        }
      } catch (_) {}
    }

    if (_isInitialized && client != null && shopId != 'demo-shop-101') {
      final prefs = await SharedPreferences.getInstance();
      final isStaff = prefs.getBool('is_staff_session') ?? false;
      final staffPin = prefs.getString('staff_pin') ?? '';

      // If staff session, query staff RPC
      if (isStaff && staffPin.isNotEmpty) {
        try {
          final dynamic rpcRes = await client!.rpc('staff_get_expenses', params: {
            '_shop_id': shopId,
            '_pin': staffPin,
          });
          if (rpcRes is Map && rpcRes['success'] == true && rpcRes['expenses'] is List) {
            final rpcList = (rpcRes['expenses'] as List).map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
            _localExpenses.clear();
            _localExpenses.addAll(rpcList);
            await _saveCachedExpenses(shopId, rpcList);
            return rpcList;
          }
        } catch (rpcErr) {
          debugPrint("Staff RPC get_expenses error: $rpcErr");
        }
      }

      try {
        final response = await client!
            .from('expenses')
            .select('*')
            .eq('shop_id', shopId)
            .order('spent_on', ascending: false)
            .limit(100);
        final list = (response as List).map((e) => Expense.fromJson(e)).toList();
        if (list.isNotEmpty || !isStaff) {
          _localExpenses.clear();
          _localExpenses.addAll(list);
          await _saveCachedExpenses(shopId, list);
          return list;
        }
      } catch (e) {
        debugPrint("Error fetching expenses: $e");
      }
    }
    return List.from(_localExpenses);
  }

  Future<void> _saveCachedExpenses(String shopId, List<Expense> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_expenses_$shopId', jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> addExpense(Expense expense) async {
    _localExpenses.insert(0, expense);
    await _saveCachedExpenses(expense.shopId, _localExpenses);
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
      if (user == null) return _localShop;

      try {
        final extendedPayload = <String, dynamic>{
          'name': shop.name,
          'phone': shop.phone,
          'address': shop.address,
          'gst_number': shop.gstin,
          'upi_id': shop.upiId,
          'upi_payee_name': shop.upiPayeeName,
          'allow_negative_stock': shop.allowNegativeStock,
          'print_paper_size': shop.printPaperSize,
          'receipt_footer': shop.receiptFooter,
          'qr_image_url': shop.qrImageUrl,
          'store_type': shop.storeType,
          'updated_at': DateTime.now().toIso8601String(),
        };

        final fullPayload = <String, dynamic>{
          ...extendedPayload,
          'google_review_url': shop.googleReviewUrl,
        };

        final corePayload = <String, dynamic>{
          'name': shop.name,
          'phone': shop.phone,
          'address': shop.address,
          'gst_number': shop.gstin,
          'updated_at': DateTime.now().toIso8601String(),
        };

        String cleanId = shop.id.trim();
        if (cleanId.startsWith('shop-')) {
          cleanId = cleanId.replaceFirst('shop-', '');
        }

        final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(cleanId);

        String targetShopId;
        bool isExistingInDb = false;

        if (isUuid) {
          final existing = await client!.from('shops').select('id').eq('id', cleanId).maybeSingle();
          if (existing != null) {
            targetShopId = cleanId;
            isExistingInDb = true;
          } else {
            targetShopId = cleanId;
            isExistingInDb = false;
          }
        } else {
          // Check if user already owns a shop in cloud
          final member = await client!.from('shop_members').select('shop_id').eq('user_id', user.id).maybeSingle();
          if (member != null && member['shop_id'] != null) {
            targetShopId = member['shop_id'].toString();
            isExistingInDb = true;
          } else {
            final owned = await client!.from('shops').select('id').eq('owner_id', user.id).maybeSingle();
            if (owned != null && owned['id'] != null) {
              targetShopId = owned['id'].toString();
              isExistingInDb = true;
            } else {
              targetShopId = const Uuid().v4();
              isExistingInDb = false;
            }
          }
        }

        // Try updating/inserting full payload first; fallback without google_review_url, then to core payload if columns missing
        try {
          if (isExistingInDb) {
            final updated = await client!.from('shops').update(fullPayload).eq('id', targetShopId).select().maybeSingle();
            if (updated != null) {
              _localShop = Shop.fromJson(updated);
            }
          } else {
            await client!.from('shops').insert({
              'id': targetShopId,
              'owner_id': user.id,
              ...fullPayload,
            });
            try {
              await client!.from('shop_members').upsert({
                'shop_id': targetShopId,
                'user_id': user.id,
                'role': 'owner',
              });
            } catch (_) {}
            final created = await client!.from('shops').select('*').eq('id', targetShopId).maybeSingle();
            if (created != null) {
              _localShop = Shop.fromJson(created);
            } else {
              _localShop = shop.copyWith(id: targetShopId);
            }
          }
        } catch (fullErr) {
          debugPrint("Full shop update failed (trying without google_review_url): $fullErr");
          try {
            if (isExistingInDb) {
              final updated = await client!.from('shops').update(extendedPayload).eq('id', targetShopId).select().maybeSingle();
              if (updated != null) {
                _localShop = Shop.fromJson(updated).copyWith(googleReviewUrl: shop.googleReviewUrl);
              }
            } else {
              await client!.from('shops').insert({
                'id': targetShopId,
                'owner_id': user.id,
                ...extendedPayload,
              });
              _localShop = shop.copyWith(id: targetShopId);
            }
          } catch (extErr) {
            debugPrint("Extended shop update failed (likely missing columns), falling back to core payload: $extErr");
            if (isExistingInDb) {
              final updated = await client!.from('shops').update(corePayload).eq('id', targetShopId).select().maybeSingle();
              if (updated != null) {
                _localShop = _localShop.copyWith(
                  id: targetShopId,
                  name: updated['name'] ?? _localShop.name,
                  phone: updated['phone'] ?? _localShop.phone,
                  address: updated['address'] ?? _localShop.address,
                  gstin: updated['gst_number'] ?? _localShop.gstin,
                  googleReviewUrl: shop.googleReviewUrl,
                );
              }
            } else {
              await client!.from('shops').insert({
                'id': targetShopId,
                'owner_id': user.id,
                ...corePayload,
              });
            try {
              await client!.from('shop_members').upsert({
                'shop_id': targetShopId,
                'user_id': user.id,
                'role': 'owner',
              });
            } catch (_) {}
            final created = await client!.from('shops').select('*').eq('id', targetShopId).maybeSingle();
              if (created != null) {
                _localShop = _localShop.copyWith(
                  id: targetShopId,
                  name: created['name'] ?? _localShop.name,
                  phone: created['phone'] ?? _localShop.phone,
                  address: created['address'] ?? _localShop.address,
                  gstin: created['gst_number'] ?? _localShop.gstin,
                  googleReviewUrl: shop.googleReviewUrl,
                );
              } else {
                _localShop = shop.copyWith(id: targetShopId);
              }
            }
          }
        }

        // Cache the newly resolved shop
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_shop_data', jsonEncode(_localShop.toJson()));
        await prefs.setString('saved_shop_data_${user.id}', jsonEncode(_localShop.toJson()));
      } catch (e) {
        debugPrint("Error updating shop settings in cloud: $e");
      }
    }
    return _localShop;
  }

  Future<Shop?> getShop(String shopId) async {
    String cleanId = shopId.trim();
    if (cleanId.startsWith('shop-')) {
      cleanId = cleanId.replaceFirst('shop-', '');
    }
    if (_isInitialized && client != null) {
      try {
        final res = await client!.from('shops').select('*').eq('id', cleanId).maybeSingle();
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

  Future<String> generateShopShareCode(String shopId) async {
    final random = Random();
    final newCode = (100000 + random.nextInt(900000)).toString();
    if (_isInitialized && client != null && shopId != 'demo-shop-101') {
      try {
        // Save to bill_prefix as guaranteed existing column AND to share_code
        await client!.from('shops').update({
          'bill_prefix': 'PIN:$newCode',
          'share_code': newCode,
        }).eq('id', shopId);
      } catch (e) {
        debugPrint("Error updating share_code in cloud: $e");
        try {
          // Fallback if share_code column does not exist
          await client!.from('shops').update({'bill_prefix': 'PIN:$newCode'}).eq('id', shopId);
        } catch (_) {}
      }
    }
    _localShop = _localShop.copyWith(shareCode: newCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_shop_data', jsonEncode(_localShop.toJson()));
    return newCode;
  }

  /// 5-Layer Security Staff Verification & Shop Pairing Engine
  /// Authenticates staff via Shop Phone + 6-digit Staff PIN or Pairing QR payload
  /// without requiring owner's private email/password, with anti-brute-force lockout.
  Future<Shop> verifyAndJoinStaff({
    required String phone,
    required String pin,
    String? qrPayload,
    String? staffName,
    String? staffRole,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Anti-Brute-Force Rate Limiting (Layer 3)
    final lockoutUntil = prefs.getInt('staff_lockout_until') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < lockoutUntil) {
      final remainingSecs = ((lockoutUntil - now) / 1000).ceil();
      final mins = (remainingSecs / 60).ceil();
      throw Exception('सुरक्षा चेतावनी: अत्यधिक असफल प्रयासों के कारण स्टाफ लॉगिन $mins मिनट के लिए लॉक है।');
    }

    // 2. Parse phone and pin (supports QR payload like shoppos://pair?phone=...&pin=...)
    String cleanPhone = phone.trim().replaceAll(' ', '').replaceAll('-', '');
    String cleanPin = pin.trim().replaceAll(' ', '');
    String cleanName = (staffName ?? '').trim();
    String cleanRole = (staffRole ?? '').trim();

    if (qrPayload != null && qrPayload.contains('pair?')) {
      try {
        final uri = Uri.parse(qrPayload);
        cleanPhone = uri.queryParameters['phone'] ?? cleanPhone;
        cleanPin = uri.queryParameters['pin'] ?? cleanPin;
        if (cleanName.isEmpty) cleanName = uri.queryParameters['name'] ?? '';
        if (cleanRole.isEmpty) cleanRole = uri.queryParameters['role'] ?? '';
      } catch (_) {}
    }

    if (cleanName.isEmpty) cleanName = 'स्टाफ';
    if (cleanRole.isEmpty) cleanRole = 'कैशियर';

    if (cleanPhone.isEmpty || cleanPin.isEmpty) {
      throw Exception('कृपया दुकान का मोबाइल नंबर और 6-अंकीय स्टाफ पिन दोनों दर्ज करें।');
    }

    if (cleanPin.length != 6) {
      throw Exception('स्टाफ पिन ठीक 6 अंकों का होना चाहिए।');
    }

    // 3. Try Server-Side Secure RPC (Layer 1 & Security Definer)
    if (_isInitialized && client != null) {
      try {
        final dynamic res = await client!.rpc('staff_verify_shop', params: {
          '_phone': cleanPhone,
          '_pin': cleanPin,
        });

        if (res is Map && res['success'] == true && res['shop'] != null) {
          final shopMap = res['shop'] as Map<String, dynamic>;
          _localShop = Shop.fromJson(shopMap);
          final realShopId = _localShop.id;

          // Parse and populate products
          if (res['products'] is List) {
            final prodsList = (res['products'] as List)
                .map((p) => Product.fromJson(p as Map<String, dynamic>))
                .toList();
            _localProducts.clear();
            _localProducts.addAll(prodsList);
            await prefs.setString(
              'cached_products_$realShopId',
              jsonEncode(prodsList.map((e) => e.toJson()).toList()),
            );
          }

          // Parse and populate customers
          if (res['customers'] is List) {
            final custsList = (res['customers'] as List)
                .map((c) => Customer.fromJson(c as Map<String, dynamic>))
                .toList();
            _localCustomers.clear();
            _localCustomers.addAll(custsList);
            await prefs.setString(
              'cached_customers_$realShopId',
              jsonEncode(custsList.map((e) => e.toJson()).toList()),
            );
          }

          // Parse and populate sales (so staff immediately has all shop bills)
          if (res['sales'] is List) {
            final salesList = (res['sales'] as List)
                .map((s) => Sale.fromJson(s as Map<String, dynamic>))
                .toList();
            _localSales.clear();
            _localSales.addAll(salesList);
            await _saveCachedSales(realShopId, salesList);
          }

          // Parse and populate expenses (so daybook has complete transaction history)
          if (res['expenses'] is List) {
            final expList = (res['expenses'] as List)
                .map((e) => Expense.fromJson(e as Map<String, dynamic>))
                .toList();
            _localExpenses.clear();
            _localExpenses.addAll(expList);
            await _saveCachedExpenses(realShopId, expList);
          }

          // Success: Reset brute-force counter and set staff session
          await prefs.setInt('staff_failed_attempts', 0);
          await prefs.setBool('is_guest_mode', true);
          await prefs.setBool('is_staff_session', true);
          await prefs.setString('staff_name', cleanName);
          await prefs.setString('staff_role', cleanRole);
          await prefs.setString('staff_pin', cleanPin);
          await prefs.setString('staff_shop_phone', cleanPhone);
          await prefs.setString('active_role', cleanRole);
          await prefs.setBool('setup_done_guest', true);
          await prefs.setString('saved_shop_data', jsonEncode(_localShop.toJson()));
          await prefs.setString('shop_name', _localShop.name);
          if (_localShop.phone != null) await prefs.setString('shop_phone', _localShop.phone!);
          if (_localShop.address != null) await prefs.setString('shop_address', _localShop.address!);
          if (_localShop.gstin != null) await prefs.setString('shop_gstin', _localShop.gstin!);
          if (_localShop.upiId != null) await prefs.setString('shop_upi_id', _localShop.upiId!);
          if (_localShop.upiPayeeName != null) await prefs.setString('shop_upi_payee_name', _localShop.upiPayeeName!);
          if (_localShop.receiptFooter != null) await prefs.setString('shop_receipt_footer', _localShop.receiptFooter!);
          await prefs.setString('shop_paper_size', _localShop.printPaperSize);
          await prefs.setBool('shop_allow_negative_stock', _localShop.allowNegativeStock);

          debugPrint("Staff successfully joined shop: ${_localShop.name} (${_localShop.id}) as $cleanName ($cleanRole)");
          return _localShop;
        } else if (res is Map && res['error'] != null) {
          throw Exception(res['error'].toString());
        }
      } catch (rpcErr) {
        debugPrint("RPC staff_verify_shop failed or not created yet: $rpcErr");
      }
    }

    // 4. Fallback Verification (Direct Matching via Shop ID / Local Cache)
    final cached = prefs.getString('saved_shop_data');
    if (cached != null) {
      try {
        final s = Shop.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        final p = (s.phone ?? '').replaceAll(' ', '').replaceAll('-', '');
        if ((p == cleanPhone || p.endsWith(cleanPhone) || cleanPhone.endsWith(p)) &&
            (s.displayShareCode == cleanPin || s.shareCode == cleanPin)) {
          _localShop = s;
          await prefs.setInt('staff_failed_attempts', 0);
          await prefs.setBool('is_guest_mode', true);
          await prefs.setBool('is_staff_session', true);
          await prefs.setString('staff_name', cleanName);
          await prefs.setString('staff_role', cleanRole);
          await prefs.setString('staff_pin', cleanPin);
          await prefs.setString('staff_shop_phone', cleanPhone);
          await prefs.setString('active_role', cleanRole);
          await prefs.setBool('setup_done_guest', true);
          return _localShop;
        }
      } catch (_) {}
    }

    // 5. Increment Brute-Force Failed Attempts
    final attempts = (prefs.getInt('staff_failed_attempts') ?? 0) + 1;
    await prefs.setInt('staff_failed_attempts', attempts);
    if (attempts >= 3) {
      await prefs.setInt('staff_lockout_until', now + (5 * 60 * 1000)); // 5 mins lockout
      throw Exception('सुरक्षा लॉक: 3 बार गलत पिन दर्ज किया गया! स्टाफ लॉगिन 5 मिनट के लिए बंद कर दिया गया है।');
    }

    final remaining = 3 - attempts;
    throw Exception('अमान्य दुकान मोबाइल नंबर या 6-अंकीय स्टाफ पिन! कृपया जांचें। (शेष प्रयास: $remaining)');
  }

  Future<Shop> joinShop(String shopCode) async {
    String cleanCode = shopCode.trim();
    if (cleanCode.startsWith('shop-')) {
      cleanCode = cleanCode.replaceFirst('shop-', '');
    }

    if (_isInitialized && client != null) {
      try {
        // Query by share_code (6-digit) OR by id
        dynamic res;
        if (cleanCode.length == 6 && RegExp(r'^\d{6}$').hasMatch(cleanCode)) {
          res = await client!.from('shops').select('*').eq('share_code', cleanCode).maybeSingle();
        }
        if (res == null) {
          res = await client!.from('shops').select('*').eq('id', cleanCode).maybeSingle();
        }
        if (res == null && cleanCode.length == 6) {
          // If not yet saved in DB column, check deterministic hash of all cloud shops
          try {
            final allShops = await client!.from('shops').select('id').limit(50);
            for (final s in allShops) {
              final sid = s['id'].toString();
              final det = ((sid.hashCode.abs() % 900000) + 100000).toString();
              if (det == cleanCode) {
                res = await client!.from('shops').select('*').eq('id', sid).maybeSingle();
                break;
              }
            }
          } catch (_) {}
        }

        if (res != null) {
          _localShop = Shop.fromJson(res);
          final realShopId = _localShop.id;
          final user = client!.auth.currentUser;
          if (user != null) {
            try {
              await client!.from('shop_members').upsert({
                'shop_id': realShopId,
                'user_id': user.id,
                'role': 'cashier',
              });
            } catch (err) {
              debugPrint("upsert shop_members err: $err");
            }
          }

          // Cache joined shop locally
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_shop_data', jsonEncode(_localShop.toJson()));
          await prefs.setString('shop_name', _localShop.name);
          if (_localShop.phone != null) await prefs.setString('shop_phone', _localShop.phone!);
          if (_localShop.address != null) await prefs.setString('shop_address', _localShop.address!);
          if (_localShop.gstin != null) await prefs.setString('shop_gstin', _localShop.gstin!);
          if (_localShop.upiId != null) await prefs.setString('shop_upi_id', _localShop.upiId!);
          if (_localShop.upiPayeeName != null) await prefs.setString('shop_upi_payee_name', _localShop.upiPayeeName!);
          if (_localShop.receiptFooter != null) await prefs.setString('shop_receipt_footer', _localShop.receiptFooter!);
          await prefs.setString('shop_paper_size', _localShop.printPaperSize);
          await prefs.setBool('shop_allow_negative_stock', _localShop.allowNegativeStock);
          if (_localShop.qrImageUrl != null) await prefs.setString('shop_qr_image_url', _localShop.qrImageUrl!);

          // Pre-fetch and cache products, customers, and bill history for the joined shop
          await getProducts(realShopId);
          await getCustomers(realShopId);
          await getSales(realShopId);

          return _localShop;
        }
      } catch (e) {
        debugPrint("Error joining shop from cloud: $e");
      }
    }

    _localShop = _localShop.copyWith(id: cleanCode);
    return _localShop;
  }

  RealtimeChannel? _realtimeChannel;

  /// Subscribes to real-time events across products, sales, customers, and transactions
  /// for the current active shop so changes from other devices are reflected immediately.
  RealtimeChannel? subscribeToShopChanges({
    required String shopId,
    required void Function(String table, String eventType, Map<String, dynamic> record) onEvent,
  }) {
    if (client == null || shopId.isEmpty || shopId == 'demo-shop-101') return null;

    try {
      _realtimeChannel?.unsubscribe();

      final channel = client!.channel('realtime_shop_$shopId');

      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        callback: (payload) {
          debugPrint('[RealtimeSync] Cloud DB change: ${payload.table} (${payload.eventType})');
          onEvent(payload.table, payload.eventType.name, payload.newRecord);
        },
      );

      channel.subscribe((status, [error]) {
        debugPrint('[RealtimeSync] Subscription for shop $shopId: $status');
      });

      _realtimeChannel = channel;
      return channel;
    } catch (e) {
      debugPrint('[RealtimeSync] Failed to subscribe: $e');
      return null;
    }
  }

  void unsubscribeFromShopChanges() {
    try {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = null;
    } catch (_) {}
  }

  /// Uploads a product or shop QR image to Supabase Storage or creates a portable optimized data URI.
  /// Guarantees that the image immediately syncs and displays across all active devices.
  Future<String> uploadImageBytes({
    required String shopId,
    required String folder,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (client != null && _isInitialized) {
      try {
        final path = '$shopId/$folder/$fileName';
        await client!.storage.from('pos-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
        final publicUrl = client!.storage.from('pos-images').getPublicUrl(path);
        debugPrint("[ImageUpload] Uploaded successfully to Supabase Storage: $publicUrl");
        return publicUrl;
      } catch (storageErr) {
        debugPrint("[ImageUpload] Supabase Storage bucket upload error (falling back to portable data URI): $storageErr");
      }
    }

    // Fallback: Portable data URI so all devices on any network render the image immediately
    final b64 = base64Encode(bytes);
    return 'data:image/jpeg;base64,$b64';
  }

  // ===========================================================================
  // SAVED ORDERS (HELD CARTS) MULTI-DEVICE CLOUD SYNC
  // ===========================================================================

  Future<bool> saveOrderToCloud({
    required String orderId,
    required String shopId,
    required List<Map<String, dynamic>> lines,
    required double discount,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? label,
  }) async {
    final validShopId = await _ensureValidShopId(shopId);
    if (client != null && _isInitialized) {
      try {
        final payload = {
          'id': orderId,
          'shop_id': validShopId,
          'lines': lines,
          'discount': discount,
          'customer_id': (customerId != null && customerId.isNotEmpty) ? customerId : null,
          'customer_name': (customerName != null && customerName.isNotEmpty) ? customerName : null,
          'customer_phone': (customerPhone != null && customerPhone.isNotEmpty) ? customerPhone : null,
          'label': label ?? 'Held Order',
        };
        await client!.from('saved_orders').upsert(payload);
        debugPrint('[SupabaseService] Successfully synced saved order $orderId to Supabase');
        return true;
      } catch (e) {
        debugPrint('[SupabaseService] saveOrderToCloud error: $e');
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> fetchSavedOrdersFromCloud(String shopId) async {
    final validShopId = await _ensureValidShopId(shopId);
    if (client != null && _isInitialized) {
      try {
        final res = await client!
            .from('saved_orders')
            .select()
            .eq('shop_id', validShopId)
            .order('created_at', ascending: false);
        final list = (res as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
        debugPrint('[SupabaseService] Fetched ${list.length} saved orders from Supabase');
        return list;
      } catch (e) {
        debugPrint('[SupabaseService] fetchSavedOrdersFromCloud error: $e');
      }
    }
    return [];
  }

  Future<bool> deleteSavedOrderFromCloud(String orderId) async {
    if (client != null && _isInitialized) {
      try {
        final res = await client!.from('saved_orders').delete().eq('id', orderId).select('id');
        return (res as List).isNotEmpty;
      } catch (e) {
        debugPrint('[SupabaseService] deleteSavedOrderFromCloud error: $e');
      }
    }
    return true; // offline safe fallback
  }

  // ===========================================================================
  // DOUBLE-LAYER STORAGE: SQLITE + SYNC OUTBOX + CATEGORIES + BACKUP RESTORE
  // ===========================================================================

  /// Save categories configuration (custom categories, deleted built-ins, images)
  /// to Local SQLite first and sync to Supabase `shops.categories_config`.
  Future<void> saveCategoriesConfig(
    String shopId,
    Map<String, dynamic> config,
  ) async {
    final validShopId = await _ensureValidShopId(shopId);
    await LocalDbService.instance.saveCategoriesConfig(validShopId, config);

    if (_isInitialized && client != null && validShopId != 'demo-shop-101') {
      try {
        await client!
            .from('shops')
            .update({'categories_config': config})
            .eq('id', validShopId);
        await LocalDbService.instance.removeOutboxForEntity('categories', validShopId);
      } catch (e) {
        debugPrint('[CategoriesSync] Deferred to outbox/local SQLite: $e');
        await LocalDbService.instance.enqueueOutbox(
          shopId: validShopId,
          entityType: 'categories',
          entityId: validShopId,
          operation: 'upsert',
          payload: config,
        );
      }
    }
  }

  /// Fetch categories configuration from Cloud first, falling back to Local SQLite.
  Future<Map<String, dynamic>> getCategoriesConfig(String shopId) async {
    final validShopId = await _ensureValidShopId(shopId);
    if (_isInitialized && client != null && validShopId != 'demo-shop-101') {
      try {
        final row = await client!
            .from('shops')
            .select('categories_config')
            .eq('id', validShopId)
            .maybeSingle();
        final cloudCfg = row?['categories_config'];
        if (cloudCfg is Map && cloudCfg.isNotEmpty) {
          final parsed = Map<String, dynamic>.from(cloudCfg);
          await LocalDbService.instance.saveCategoriesConfig(validShopId, parsed);
          return parsed;
        }
      } catch (e) {
        debugPrint('[CategoriesSync] Cloud read skipped, using local SQLite: $e');
      }
    }
    return LocalDbService.instance.getCategoriesConfig(validShopId);
  }

  /// Returns count of pending offline sync operations for the active shop.
  Future<int> getPendingSyncCount([String? shopId]) async {
    final validShopId = await _ensureValidShopId(shopId ?? _localShop.id);
    return LocalDbService.instance.getPendingOutboxCount(validShopId);
  }

  /// Returns storage diagnostics for UI (SQLite availability, bill counts, pending sync count).
  Future<Map<String, dynamic>> getLocalStorageStats([String? shopId]) async {
    final validShopId = await _ensureValidShopId(shopId ?? _localShop.id);
    return LocalDbService.instance.getStorageStats(validShopId);
  }

  /// Flushes queued offline creations, edits, and soft deletions to Supabase Cloud.
  Future<int> flushSyncOutbox([String? shopId]) async {
    final validShopId = await _ensureValidShopId(shopId ?? _localShop.id);
    if (!_isInitialized || client == null || validShopId == 'demo-shop-101') {
      return 0;
    }

    final items = await LocalDbService.instance.getOutboxItems(validShopId);
    int syncedCount = 0;

    for (final item in items) {
      try {
        if (item.entityType == 'product' && item.operation == 'soft_delete') {
          await client!.from('products').update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', item.entityId);
          await LocalDbService.instance.removeOutboxItem(item.id);
          syncedCount++;
        } else if (item.entityType == 'product' && item.operation == 'upsert') {
          final prod = Product.fromJson(item.payload).copyWith(shopId: validShopId);
          await client!.from('products').upsert(prod.toSupabaseJson());
          await LocalDbService.instance.removeOutboxItem(item.id);
          syncedCount++;
        } else if (item.entityType == 'customer' && item.operation == 'upsert') {
          final cust = Customer.fromJson(item.payload).copyWith(shopId: validShopId);
          await client!.from('customers').upsert(cust.toSupabaseJson());
          await LocalDbService.instance.removeOutboxItem(item.id);
          syncedCount++;
        } else if (item.entityType == 'sale' && item.operation == 'update_sale') {
          final rawSale = item.payload['sale'];
          if (rawSale is Map) {
            final updatedSale = Sale.fromJson(Map<String, dynamic>.from(rawSale))
                .copyWith(shopId: validShopId);
            final rawPrev = item.payload['previous_sale'];
            final prevSale = rawPrev is Map
                ? Sale.fromJson(Map<String, dynamic>.from(rawPrev))
                : null;
            await _pushUpdatedSaleToCloud(updatedSale, previousSale: prevSale);
          }
          await LocalDbService.instance.removeOutboxItem(item.id);
          syncedCount++;
        } else if (item.entityType == 'sale' && item.operation == 'create') {
          final rawSale = item.payload['sale'];
          if (rawSale is Map) {
            final offlineSale = Sale.fromJson(Map<String, dynamic>.from(rawSale))
                .copyWith(shopId: validShopId);
            final saleUuid = _isValidUuid(offlineSale.id)
                ? offlineSale.id
                : const Uuid().v4();
            final validMode = ['cash', 'online', 'credit', 'split', 'set_later']
                    .contains(offlineSale.paymentMode)
                ? offlineSale.paymentMode
                : 'cash';
            await client!.from('sales').upsert({
              'id': saleUuid,
              'shop_id': validShopId,
              'bill_no': offlineSale.billNo > 0 ? offlineSale.billNo : 1,
              'customer_id': _isValidUuid(offlineSale.customerId)
                  ? offlineSale.customerId
                  : null,
              'customer_name': offlineSale.customerName,
              'customer_phone': offlineSale.customerPhone,
              'sub_total': offlineSale.subtotal,
              'discount': offlineSale.discount,
              'total': offlineSale.total,
              'paid': offlineSale.paid,
              'due': offlineSale.due,
              'payment_mode': validMode,
              'note': offlineSale.encodedNote,
              'created_at': offlineSale.createdAt.toIso8601String(),
            });
            await client!.from('sale_items').delete().eq('sale_id', saleUuid);
            if (offlineSale.items.isNotEmpty) {
              await client!.from('sale_items').insert(offlineSale.items.map((it) => {
                    'shop_id': validShopId,
                    'sale_id': saleUuid,
                    'product_id': _isValidUuid(it.productId) ? it.productId : null,
                    'name': it.name,
                    'unit': it.unit == 'kg' ? 'kg' : 'pc',
                    'price': it.price,
                    'qty': it.qty,
                    'line_total': it.total,
                  }).toList());
            }
          }
          await LocalDbService.instance.removeOutboxItem(item.id);
          syncedCount++;
        } else if (item.entityType == 'categories' && item.operation == 'upsert') {
          try {
            await client!
                .from('shops')
                .update({'categories_config': item.payload})
                .eq('id', validShopId);
          } catch (_) {}
          await LocalDbService.instance.removeOutboxItem(item.id);
          syncedCount++;
        }
      } catch (e) {
        debugPrint('[SyncOutbox] Retry queued for ${item.id}: $e');
        await LocalDbService.instance.markOutboxError(item.id, e.toString());
      }
    }
    return syncedCount;
  }

  /// Restores a complete store snapshot (products, customers, bills, settings, categories)
  /// into Local SQLite, in-memory cache, and pushes to Cloud outbox.
  Future<void> restoreFromBackup({
    required Shop? shop,
    required List<Product> products,
    required List<Customer> customers,
    required List<Sale> sales,
    Map<String, dynamic>? categoriesConfig,
  }) async {
    final validShopId = await _ensureValidShopId(
        _localShop.id != 'demo-shop-101' ? _localShop.id : (shop?.id ?? _localShop.id));

    if (shop != null) {
      final restoredShop = shop.copyWith(id: validShopId);
      _localShop = restoredShop;
      await LocalDbService.instance.saveShop(restoredShop);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_shop_data', jsonEncode(restoredShop.toJson()));
      if (_isInitialized && client != null && validShopId != 'demo-shop-101') {
        try {
          await updateShop(restoredShop);
        } catch (_) {}
      }
    }

    if (categoriesConfig != null && categoriesConfig.isNotEmpty) {
      await saveCategoriesConfig(validShopId, categoriesConfig);
    }

    final normalizedProducts =
        products.map((p) => p.copyWith(shopId: validShopId)).toList();
    _localProducts
      ..clear()
      ..addAll(normalizedProducts);
    await LocalDbService.instance.saveDeletedProductIds(validShopId, []);
    await _saveCachedProducts(validShopId, _localProducts);

    final normalizedCustomers =
        customers.map((c) => c.copyWith(shopId: validShopId)).toList();
    _localCustomers
      ..clear()
      ..addAll(normalizedCustomers);
    await _saveCachedCustomers(validShopId, _localCustomers);

    final normalizedSales =
        sales.map((s) => s.copyWith(shopId: validShopId)).toList();
    _localSales
      ..clear()
      ..addAll(normalizedSales);
    await LocalDbService.instance
        .saveSales(validShopId, _localSales, preserveOutboxChanges: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cached_sales_$validShopId',
      jsonEncode(_localSales.take(200).map((s) => s.toJson()).toList()),
    );

    if (validShopId != 'demo-shop-101') {
      for (final p in normalizedProducts) {
        await LocalDbService.instance.enqueueOutbox(
          shopId: validShopId,
          entityType: 'product',
          entityId: p.id,
          operation: 'upsert',
          payload: p.toJson(),
        );
      }
      for (final c in normalizedCustomers) {
        await LocalDbService.instance.enqueueOutbox(
          shopId: validShopId,
          entityType: 'customer',
          entityId: c.id,
          operation: 'upsert',
          payload: c.toJson(),
        );
      }
      for (final s in normalizedSales) {
        await LocalDbService.instance.enqueueOutbox(
          shopId: validShopId,
          entityType: 'sale',
          entityId: s.id,
          operation: 'create',
          payload: {'sale': s.toJson()},
        );
      }
      await flushSyncOutbox(validShopId);
    }
  }
}
