import 'package:flutter/foundation.dart';
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
    name: 'यादव जनरल स्टोर (Yadav Store)',
    phone: '9876543210',
    address: 'दुकान नं. 4, मेन मार्केट',
    gstin: '07AAAAA0000A1Z5',
    upiId: '9876543210@upi',
    upiPayeeName: 'Yadav Store',
    allowNegativeStock: true,
    printPaperSize: '58mm',
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

    // Populate initial local catalog
    _localProducts.addAll(CatalogData.getInitialProducts(_localShop.id));
    _localCustomers.addAll([
      Customer(
        id: 'c1',
        shopId: _localShop.id,
        name: 'रमेश कुमार (Ramesh Kumar)',
        phone: '9812345678',
        balance: 450.0,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Customer(
        id: 'c2',
        shopId: _localShop.id,
        name: 'सुरेश शर्मा (Suresh Sharma)',
        phone: '9988776655',
        balance: 1200.0,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Customer(
        id: 'c3',
        shopId: _localShop.id,
        name: 'अमित वर्मा (Amit Verma)',
        phone: '9123456789',
        balance: 0.0,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);
  }

  // --- PRODUCTS ---
  Future<List<Product>> getProducts(String shopId) async {
    if (_isInitialized && client != null) {
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
          return list;
        }
      } catch (e) {
        debugPrint("Error fetching products from cloud: $e");
      }
    }
    return List.from(_localProducts);
  }

  Future<Product> addProduct(Product product) async {
    _localProducts.add(product);
    if (isInitialized && client != null) {
      try {
        await client!.from('products').insert(product.toSupabaseJson());
      } catch (e) {
        debugPrint("Error inserting product in cloud: $e");
      }
    }
    return product;
  }

  Future<void> updateProduct(Product product) async {
    final index = _localProducts.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _localProducts[index] = product;
    }
    if (isInitialized && client != null) {
      try {
        await client!.from('products').update(product.toSupabaseJson()).eq('id', product.id);
      } catch (e) {
        debugPrint("Error updating product in cloud: $e");
      }
    }
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
  }

  // --- CUSTOMERS ---
  Future<List<Customer>> getCustomers(String shopId) async {
    if (_isInitialized && client != null) {
      try {
        final response = await client!
            .from('customers')
            .select('*')
            .eq('shop_id', shopId)
            .order('name');
        final list = (response as List).map((e) => Customer.fromJson(e)).toList();
        if (list.isNotEmpty) {
          _localCustomers.clear();
          _localCustomers.addAll(list);
          return list;
        }
      } catch (e) {
        debugPrint("Error fetching customers from cloud: $e");
      }
    }
    return List.from(_localCustomers);
  }

  Future<Customer> addCustomer(Customer customer) async {
    _localCustomers.add(customer);
    if (_isInitialized && client != null) {
      try {
        await client!.from('customers').insert(customer.toJson());
      } catch (e) {
        debugPrint("Error adding customer: $e");
      }
    }
    return customer;
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
  }

  // --- SALES & BILLING ---
  Future<List<Sale>> getSales(String shopId) async {
    if (_isInitialized && client != null) {
      try {
        final response = await client!
            .from('sales')
            .select('*')
            .eq('shop_id', shopId)
            .order('created_at', ascending: false)
            .limit(100);
        final list = (response as List).map((e) => Sale.fromJson(e)).toList();
        if (list.isNotEmpty) {
          _localSales.clear();
          _localSales.addAll(list);
          return list;
        }
      } catch (e) {
        debugPrint("Error fetching sales: $e");
      }
    }
    return List.from(_localSales);
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

    if (_isInitialized && client != null) {
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

    return sale;
  }

  // --- EXPENSES ---
  Future<List<Expense>> getExpenses(String shopId) async {
    if (_isInitialized && client != null) {
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
      try {
        await client!.from('shops').update(shop.toJson()).eq('id', shop.id);
      } catch (e) {
        debugPrint("Error updating shop settings: $e");
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
