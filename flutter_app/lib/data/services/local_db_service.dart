import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' hide Category;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/customer_ledger_entry.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/shop.dart';

class SyncOutboxItem {
  final String id;
  final String shopId;
  final String entityType; // 'sale', 'product', 'customer', 'shop', 'categories'
  final String entityId;
  final String operation; // 'upsert', 'update_sale', 'soft_delete', 'delete_sale'
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  const SyncOutboxItem({
    required this.id,
    required this.shopId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  factory SyncOutboxItem.fromRow(Map<String, dynamic> row) {
    Map<String, dynamic> decoded = {};
    try {
      final raw = jsonDecode(row['payload_json'] as String? ?? '{}');
      if (raw is Map) {
        decoded = Map<String, dynamic>.from(raw);
      }
    } catch (_) {}

    return SyncOutboxItem(
      id: row['id'] as String,
      shopId: row['shop_id'] as String,
      entityType: row['entity_type'] as String,
      entityId: row['entity_id'] as String,
      operation: row['operation'] as String,
      payload: decoded,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      retryCount: (row['retry_count'] as num?)?.toInt() ?? 0,
      lastError: row['last_error'] as String?,
    );
  }
}

/// Persistent SQLite Double-Layer Local Database + Offline Sync Outbox Queue.
/// Safely no-ops on Web or headless widget tests without database initialization.
class LocalDbService {
  static final LocalDbService instance = LocalDbService._();
  LocalDbService._();

  static const int _dbVersion = 2;
  static const String _dbName = 'shop_pos_local.db';

  Database? _db;
  String? _dbPathOverride;
  bool _disabled = false;

  bool get isAvailable => !kIsWeb && !_disabled && _db != null;

  /// Optional test helper: initializes against custom path or `:memory:`
  Future<void> init({String? dbPathOverride}) async {
    if (kIsWeb) {
      _disabled = true;
      return;
    }
    if (dbPathOverride != null) {
      if (_db != null && _dbPathOverride != dbPathOverride) {
        await _db!.close();
        _db = null;
      }
      _dbPathOverride = dbPathOverride;
    }
    if (_db != null && _db!.isOpen) return;

    try {
      final path = _dbPathOverride ??
          p.join(await getDatabasesPath(), _dbName);
      _db = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      _disabled = false;
    } catch (e) {
      debugPrint('LocalDbService init skipped/unavailable: $e');
      _db = null;
      _disabled = true;
    }
  }

  Future<Database?> _ensureDb() async {
    if (kIsWeb || _disabled) return null;
    if (_db != null && _db!.isOpen) return _db;
    await init();
    return _db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createBaseTables(db);
    await _createV2Tables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createV2Tables(db);
    }
  }

  Future<void> _createBaseTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        category TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        data_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_shop ON products (shop_id, is_active)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        data_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_shop ON customers (shop_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        bill_no INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        edit_count INTEGER NOT NULL DEFAULT 0,
        data_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_shop ON sales (shop_id, created_at DESC)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shop_meta (
        shop_id TEXT PRIMARY KEY,
        shop_json TEXT,
        categories_json TEXT,
        deleted_products_json TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_outbox_shop ON sync_outbox (shop_id, created_at ASC)');
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        name TEXT NOT NULL,
        image_url TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        data_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_categories_shop ON categories (shop_id, is_active)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_ledger (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        entry_type TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        balance_after REAL NOT NULL DEFAULT 0,
        sale_id TEXT,
        payment_id TEXT,
        note TEXT,
        created_at TEXT NOT NULL,
        data_json TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ledger_shop_cust ON customer_ledger (shop_id, customer_id, created_at DESC)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shop_bill_counters (
        shop_id TEXT PRIMARY KEY,
        last_bill_no INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  // ===================== PRODUCTS =====================

  Future<void> saveProducts(String shopId, List<Product> products) async {
    final db = await _ensureDb();
    if (db == null) return;
    final deletedIds = (await getDeletedProductIds(shopId)).toSet();
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete('products', where: 'shop_id = ?', whereArgs: [shopId]);
      final batch = txn.batch();
      for (final prod in products) {
        if (!prod.isActive || deletedIds.contains(prod.id)) continue;
        batch.insert(
          'products',
          {
            'id': prod.id,
            'shop_id': shopId,
            'category': prod.category,
            'is_active': prod.isActive ? 1 : 0,
            'data_json': jsonEncode(prod.toJson()),
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertProduct(String shopId, Product product) async {
    final db = await _ensureDb();
    if (db == null) return;
    await db.insert(
      'products',
      {
        'id': product.id,
        'shop_id': shopId,
        'category': product.category,
        'is_active': product.isActive ? 1 : 0,
        'data_json': jsonEncode(product.toJson()),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markProductDeleted(String shopId, String productId) async {
    final db = await _ensureDb();
    if (db == null) return;
    await db.delete('products',
        where: 'id = ? AND shop_id = ?', whereArgs: [productId, shopId]);
    final deleted = (await getDeletedProductIds(shopId)).toSet()..add(productId);
    await _upsertShopMetaColumn(
        shopId, 'deleted_products_json', jsonEncode(deleted.toList()));
  }

  Future<List<Product>> getProducts(String shopId) async {
    final db = await _ensureDb();
    if (db == null) return [];
    final rows = await db.query(
      'products',
      where: 'shop_id = ? AND is_active = 1',
      whereArgs: [shopId],
    );
    final deleted = (await getDeletedProductIds(shopId)).toSet();
    final List<Product> result = [];
    for (final row in rows) {
      final id = row['id'] as String;
      if (deleted.contains(id)) continue;
      try {
        final decoded =
            Map<String, dynamic>.from(jsonDecode(row['data_json'] as String));
        result.add(Product.fromJson(decoded));
      } catch (e) {
        debugPrint('LocalDb decode product failed: $e');
      }
    }
    return result;
  }

  // ===================== CUSTOMERS =====================

  Future<void> saveCustomers(String shopId, List<Customer> customers) async {
    final db = await _ensureDb();
    if (db == null) return;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('customers', where: 'shop_id = ?', whereArgs: [shopId]);
      final batch = txn.batch();
      for (final c in customers) {
        batch.insert(
          'customers',
          {
            'id': c.id,
            'shop_id': shopId,
            'data_json': jsonEncode(c.toJson()),
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertCustomer(String shopId, Customer customer) async {
    final db = await _ensureDb();
    if (db == null) return;
    await db.insert(
      'customers',
      {
        'id': customer.id,
        'shop_id': shopId,
        'data_json': jsonEncode(customer.toJson()),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Customer>> getCustomers(String shopId) async {
    final db = await _ensureDb();
    if (db == null) return [];
    final rows = await db.query(
      'customers',
      where: 'shop_id = ?',
      whereArgs: [shopId],
    );
    final List<Customer> result = [];
    for (final row in rows) {
      try {
        final decoded =
            Map<String, dynamic>.from(jsonDecode(row['data_json'] as String));
        result.add(Customer.fromJson(decoded));
      } catch (e) {
        debugPrint('LocalDb decode customer failed: $e');
      }
    }
    return result;
  }

  // ===================== SALES / BILLS =====================

  /// Saves all sales without any 200-bill limit.
  /// Preserves local unsynced/pending-edit/pending-delete sales when merging cloud snapshots.
  Future<void> saveSales(String shopId, List<Sale> sales,
      {bool preserveOutboxChanges = true}) async {
    final db = await _ensureDb();
    if (db == null) return;

    final outboxItems = preserveOutboxChanges
        ? await getOutboxItems(shopId)
        : const <SyncOutboxItem>[];
    final pendingDeletedSaleIds = <String>{};
    final pendingLocalSalesById = <String, Sale>{};
    for (final item in outboxItems) {
      if (item.entityType == 'sale') {
        if (item.operation == 'delete_sale') {
          pendingDeletedSaleIds.add(item.entityId);
        } else {
          try {
            final raw = item.payload['sale'] is Map
                ? Map<String, dynamic>.from(item.payload['sale'] as Map)
                : item.payload;
            pendingLocalSalesById[item.entityId] = Sale.fromJson(raw);
          } catch (_) {}
        }
      }
    }

    final merged = <String, Sale>{};
    for (final s in sales) {
      if (!pendingDeletedSaleIds.contains(s.id)) {
        merged[s.id] = s;
      }
    }
    for (final entry in pendingLocalSalesById.entries) {
      if (!pendingDeletedSaleIds.contains(entry.key)) {
        merged[entry.key] = entry.value;
      }
    }

    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('sales', where: 'shop_id = ?', whereArgs: [shopId]);
      final batch = txn.batch();
      for (final s in merged.values) {
        batch.insert(
          'sales',
          {
            'id': s.id,
            'shop_id': shopId,
            'bill_no': s.billNo,
            'created_at': s.createdAt.toIso8601String(),
            'edit_count': s.editCount,
            'data_json': jsonEncode(s.toJson()),
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertSale(String shopId, Sale sale) async {
    final db = await _ensureDb();
    if (db == null) return;
    await db.insert(
      'sales',
      {
        'id': sale.id,
        'shop_id': shopId,
        'bill_no': sale.billNo,
        'created_at': sale.createdAt.toIso8601String(),
        'edit_count': sale.editCount,
        'data_json': jsonEncode(sale.toJson()),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSale(String shopId, String saleId) async {
    final db = await _ensureDb();
    if (db == null) return;
    await db.delete('sales',
        where: 'id = ? AND shop_id = ?', whereArgs: [saleId, shopId]);
  }

  Future<List<Sale>> getSales(String shopId) async {
    final db = await _ensureDb();
    if (db == null) return [];
    final rows = await db.query(
      'sales',
      where: 'shop_id = ?',
      whereArgs: [shopId],
      orderBy: 'created_at DESC',
    );
    final List<Sale> result = [];
    for (final row in rows) {
      try {
        final decoded =
            Map<String, dynamic>.from(jsonDecode(row['data_json'] as String));
        result.add(Sale.fromJson(decoded));
      } catch (e) {
        debugPrint('LocalDb decode sale failed: $e');
      }
    }
    return result;
  }

  // ===================== SHOP & CATEGORIES META =====================

  Future<void> _upsertShopMetaColumn(
      String shopId, String column, String jsonValue) async {
    final db = await _ensureDb();
    if (db == null) return;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'shop_meta',
      where: 'shop_id = ?',
      whereArgs: [shopId],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('shop_meta', {
        'shop_id': shopId,
        column: jsonValue,
        'updated_at': now,
      });
    } else {
      await db.update(
        'shop_meta',
        {column: jsonValue, 'updated_at': now},
        where: 'shop_id = ?',
        whereArgs: [shopId],
      );
    }
  }

  Future<void> saveShop(Shop shop) async {
    await _upsertShopMetaColumn(shop.id, 'shop_json', jsonEncode(shop.toJson()));
  }

  Future<Shop?> getShop(String shopId) async {
    final db = await _ensureDb();
    if (db == null) return null;
    final rows = await db.query(
      'shop_meta',
      columns: ['shop_json'],
      where: 'shop_id = ?',
      whereArgs: [shopId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['shop_json'] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      return Shop.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCategoriesConfig(
      String shopId, Map<String, dynamic> config) async {
    await _upsertShopMetaColumn(shopId, 'categories_json', jsonEncode(config));
  }

  Future<Map<String, dynamic>> getCategoriesConfig(String shopId) async {
    final db = await _ensureDb();
    if (db == null) return {};
    final rows = await db.query(
      'shop_meta',
      columns: ['categories_json'],
      where: 'shop_id = ?',
      whereArgs: [shopId],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    final raw = rows.first['categories_json'] as String?;
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return {};
    }
  }

  Future<List<String>> getDeletedProductIds(String shopId) async {
    final db = await _ensureDb();
    if (db == null) return [];
    final rows = await db.query(
      'shop_meta',
      columns: ['deleted_products_json'],
      where: 'shop_id = ?',
      whereArgs: [shopId],
      limit: 1,
    );
    if (rows.isEmpty) return [];
    final raw = rows.first['deleted_products_json'] as String?;
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> saveDeletedProductIds(String shopId, List<String> ids) async {
    await _upsertShopMetaColumn(
        shopId, 'deleted_products_json', jsonEncode(ids.toSet().toList()));
  }

  Future<void> removeDeletedProductId(String shopId, String productId) async {
    final current = (await getDeletedProductIds(shopId)).toSet();
    if (current.remove(productId)) {
      await saveDeletedProductIds(shopId, current.toList());
    }
  }

  /// Reconciles active products returned authoritatively by Supabase Cloud.
  /// Automatically purges stale local deletion flags and outbox soft-delete tasks.
  Future<void> reconcileCloudActiveProducts(String shopId, List<Product> cloudActiveProducts) async {
    final activeIds = cloudActiveProducts.map((p) => p.id).toSet();
    final currentDeleted = (await getDeletedProductIds(shopId)).toSet();
    final beforeLen = currentDeleted.length;
    currentDeleted.removeAll(activeIds);
    if (currentDeleted.length != beforeLen) {
      await saveDeletedProductIds(shopId, currentDeleted.toList());
    }
    for (final id in activeIds) {
      await removeOutboxForEntity('product', id);
    }
    await saveProducts(shopId, cloudActiveProducts);
  }

  // ===================== SYNC OUTBOX =====================

  Future<void> enqueueOutbox({
    required String shopId,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _ensureDb();
    if (db == null) return;
    final id = '${entityType}_$entityId';
    await db.insert(
      'sync_outbox',
      {
        'id': id,
        'shop_id': shopId,
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation,
        'payload_json': jsonEncode(payload),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
        'last_error': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SyncOutboxItem>> getOutboxItems(String shopId) async {
    final db = await _ensureDb();
    if (db == null) return [];
    final rows = await db.query(
      'sync_outbox',
      where: 'shop_id = ?',
      whereArgs: [shopId],
      orderBy: 'created_at ASC',
    );
    return rows.map(SyncOutboxItem.fromRow).toList();
  }

  Future<int> getPendingOutboxCount(String shopId) async {
    final db = await _ensureDb();
    if (db == null) return 0;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM sync_outbox WHERE shop_id = ?',
      [shopId],
    );
    return (res.first['cnt'] as num?)?.toInt() ?? 0;
  }

  Future<void> removeOutboxItem(String id) async {
    final db = await _ensureDb();
    if (db == null) return;
    await db.delete('sync_outbox', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> removeOutboxForEntity(String entityType, String entityId) async {
    final db = await _ensureDb();
    if (db == null) return;
    await db.delete(
      'sync_outbox',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
    );
  }

  Future<void> markOutboxError(String id, String error) async {
    final db = await _ensureDb();
    if (db == null) return;
    await db.rawUpdate(
      'UPDATE sync_outbox SET retry_count = retry_count + 1, last_error = ? WHERE id = ?',
      [error, id],
    );
  }

  Future<Map<String, dynamic>> getStorageStats(String shopId) async {
    final db = await _ensureDb();
    if (db == null) {
      return {
        'sqliteAvailable': false,
        'productsCount': 0,
        'customersCount': 0,
        'salesCount': 0,
        'pendingSyncCount': 0,
      };
    }
    Future<int> countTable(String table) async {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM $table WHERE shop_id = ?',
        [shopId],
      );
      return (rows.first['cnt'] as num?)?.toInt() ?? 0;
    }

    return {
      'sqliteAvailable': true,
      'productsCount': await countTable('products'),
      'customersCount': await countTable('customers'),
      'salesCount': await countTable('sales'),
      'categoriesCount': await countTable('categories'),
      'pendingSyncCount': await getPendingOutboxCount(shopId),
    };
  }

  // ===================== CATEGORIES =====================

  Future<void> saveCategories(String shopId, List<Category> categories) async {
    final db = await _ensureDb();
    if (db == null) return;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('categories', where: 'shop_id = ?', whereArgs: [shopId]);
      final batch = txn.batch();
      for (final cat in categories) {
        batch.insert(
          'categories',
          {
            'id': cat.id,
            'shop_id': shopId,
            'name': cat.name,
            'image_url': cat.imageUrl,
            'is_active': cat.isActive ? 1 : 0,
            'data_json': jsonEncode(cat.toJson()),
            'updated_at': cat.updatedAt?.toIso8601String() ?? now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertCategory(String shopId, Category category) async {
    final db = await _ensureDb();
    if (db == null) return;
    await db.insert(
      'categories',
      {
        'id': category.id,
        'shop_id': shopId,
        'name': category.name,
        'image_url': category.imageUrl,
        'is_active': category.isActive ? 1 : 0,
        'data_json': jsonEncode(category.toJson()),
        'updated_at': category.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCategory(String shopId, String categoryId) async {
    final db = await _ensureDb();
    if (db == null) return;
    await db.delete('categories', where: 'id = ? AND shop_id = ?', whereArgs: [categoryId, shopId]);
  }

  Future<List<Category>> getCategories(String shopId) async {
    final db = await _ensureDb();
    if (db == null) return [];
    final rows = await db.query(
      'categories',
      where: 'shop_id = ? AND is_active = 1',
      whereArgs: [shopId],
      orderBy: 'name ASC',
    );
    final List<Category> result = [];
    for (final row in rows) {
      try {
        final decoded = Map<String, dynamic>.from(jsonDecode(row['data_json'] as String));
        result.add(Category.fromJson(decoded));
      } catch (e) {
        debugPrint('LocalDb decode category failed: $e');
      }
    }
    return result;
  }

  // ===================== CUSTOMER LEDGER =====================

  Future<void> saveCustomerLedgerEntries(String shopId, List<CustomerLedgerEntry> entries) async {
    final db = await _ensureDb();
    if (db == null) return;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final e in entries) {
        batch.insert(
          'customer_ledger',
          {
            'id': e.id,
            'shop_id': shopId,
            'customer_id': e.customerId,
            'entry_type': e.entryType,
            'amount': e.amount,
            'balance_after': e.balanceAfter,
            'sale_id': e.saleId,
            'payment_id': e.paymentId,
            'note': e.note,
            'created_at': e.createdAt.toIso8601String(),
            'data_json': jsonEncode(e.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> addCustomerLedgerEntry(String shopId, CustomerLedgerEntry entry) async {
    final db = await _ensureDb();
    if (db == null) return;
    await db.insert(
      'customer_ledger',
      {
        'id': entry.id,
        'shop_id': shopId,
        'customer_id': entry.customerId,
        'entry_type': entry.entryType,
        'amount': entry.amount,
        'balance_after': entry.balanceAfter,
        'sale_id': entry.saleId,
        'payment_id': entry.paymentId,
        'note': entry.note,
        'created_at': entry.createdAt.toIso8601String(),
        'data_json': jsonEncode(entry.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CustomerLedgerEntry>> getCustomerLedger(String shopId, String customerId) async {
    final db = await _ensureDb();
    if (db == null) return [];
    final rows = await db.query(
      'customer_ledger',
      where: 'shop_id = ? AND customer_id = ?',
      whereArgs: [shopId, customerId],
      orderBy: 'created_at DESC',
    );
    final List<CustomerLedgerEntry> result = [];
    for (final row in rows) {
      try {
        final decoded = Map<String, dynamic>.from(jsonDecode(row['data_json'] as String));
        result.add(CustomerLedgerEntry.fromJson(decoded));
      } catch (e) {
        debugPrint('LocalDb decode ledger failed: $e');
      }
    }
    return result;
  }

  // ===================== ATOMIC BILL COUNTERS =====================

  /// Peeks the upcoming bill number without incrementing
  Future<int> peekNextBillNo(String shopId) async {
    final db = await _ensureDb();
    if (db == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return (prefs.getInt('shop_last_bill_no_$shopId') ?? 0) + 1;
      } catch (_) {
        return 1;
      }
    }
    final rows = await db.query(
      'shop_bill_counters',
      where: 'shop_id = ?',
      whereArgs: [shopId],
    );
    // Ignore 5-digit millisecond timestamps (> 50,000) that were created by old random fallback bug
    final sRows = await db.rawQuery(
      'SELECT MAX(bill_no) as max_b FROM sales WHERE shop_id = ? AND bill_no < 50000',
      [shopId],
    );
    final maxSales = (sRows.first['max_b'] as num?)?.toInt() ?? 0;
    int current = 0;
    if (rows.isNotEmpty) {
      current = (rows.first['last_bill_no'] as num?)?.toInt() ?? 0;
    }
    int peekNo = (current > 0) ? (current + 1) : (maxSales + 1);

    // Guarantee candidate number has no collisions with existing sales
    while (true) {
      final existing = await db.rawQuery(
        'SELECT 1 FROM sales WHERE shop_id = ? AND bill_no = ? LIMIT 1',
        [shopId, peekNo],
      );
      if (existing.isEmpty) break;
      peekNo++;
    }
    return peekNo;
  }

  /// Atomically allocates and increments the next sequential bill number.
  /// Strictly ensures bill number continues monotonically past all legitimate historical sales.
  Future<int> getNextBillNo(String shopId) async {
    final db = await _ensureDb();
    if (db == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final last = prefs.getInt('shop_last_bill_no_$shopId') ?? 0;
        final next = last + 1;
        await prefs.setInt('shop_last_bill_no_$shopId', next);
        return next;
      } catch (_) {
        return 1;
      }
    }
    return await db.transaction((txn) async {
      final rows = await txn.query(
        'shop_bill_counters',
        where: 'shop_id = ?',
        whereArgs: [shopId],
      );
      // Ignore 5-digit millisecond timestamps (> 50,000) from old fallback bug
      final sRows = await txn.rawQuery(
        'SELECT MAX(bill_no) as max_b FROM sales WHERE shop_id = ? AND bill_no < 50000',
        [shopId],
      );
      final maxSales = (sRows.first['max_b'] as num?)?.toInt() ?? 0;
      int current = 0;
      if (rows.isNotEmpty) {
        current = (rows.first['last_bill_no'] as num?)?.toInt() ?? 0;
      }
      int nextNo = (current > 0) ? (current + 1) : (maxSales + 1);

      // Guarantee candidate number has no collisions with existing sales
      while (true) {
        final existing = await txn.rawQuery(
          'SELECT 1 FROM sales WHERE shop_id = ? AND bill_no = ? LIMIT 1',
          [shopId, nextNo],
        );
        if (existing.isEmpty) break;
        nextNo++;
      }

      final now = DateTime.now().toIso8601String();
      await txn.insert(
        'shop_bill_counters',
        {'shop_id': shopId, 'last_bill_no': nextNo, 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('shop_last_bill_no_$shopId', nextNo);
      } catch (_) {}

      return nextNo;
    });
  }

  Future<void> setLastBillNo(String shopId, int lastBillNo) async {
    final db = await _ensureDb();
    if (db == null) return;
    await db.insert(
      'shop_bill_counters',
      {
        'shop_id': shopId,
        'last_bill_no': lastBillNo,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Close and clear tables in unit tests
  @visibleForTesting
  Future<void> closeForTest() async {
    await _db?.close();
    _db = null;
    _dbPathOverride = null;
    _disabled = false;
  }
}

