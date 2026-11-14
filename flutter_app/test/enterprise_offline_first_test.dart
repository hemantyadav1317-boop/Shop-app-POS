import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shop_pos/data/models/category.dart';
import 'package:shop_pos/data/models/customer_ledger_entry.dart';
import 'package:shop_pos/data/models/product.dart';
import 'package:shop_pos/data/services/local_db_service.dart';
import 'package:shop_pos/providers/product_provider.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Enterprise Offline-First Schema & Local Database Tests', () {
    const shopId = 'test-shop-phase2';

    setUp(() async {
      await LocalDbService.instance.closeForTest();
      await LocalDbService.instance.init(dbPathOverride: inMemoryDatabasePath);
    });

    tearDown(() async {
      await LocalDbService.instance.closeForTest();
    });

    test('Category model serializes, deserializes and compares accurately', () {
      final now = DateTime.now();
      final cat = Category(
        id: 'cat-veg-101',
        shopId: shopId,
        name: 'Vegetables',
        imageUrl: 'https://example.com/veg.png',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final json = cat.toJson();
      expect(json['name'], 'Vegetables');
      expect(json['shop_id'], shopId);

      final restored = Category.fromJson(json);
      expect(restored.name, 'Vegetables');
      expect(restored.imageUrl, 'https://example.com/veg.png');
      expect(restored.isActive, isTrue);
      expect(restored, equals(cat));
    });

    test('Product model supports optional categoryId without breaking legacy category string', () {
      final prod = Product(
        id: 'p-sugar-1',
        shopId: shopId,
        name: 'Sugar',
        category: 'GROCERY',
        categoryId: 'cat-grocery-uuid',
        unit: 'kg',
        price: 42.0,
      );

      final json = prod.toJson();
      expect(json['category'], 'GROCERY');
      expect(json['category_id'], 'cat-grocery-uuid');

      final restored = Product.fromJson(json);
      expect(restored.category, 'GROCERY');
      expect(restored.categoryId, 'cat-grocery-uuid');
    });

    test('LocalDbService stores and retrieves normalized Categories with soft-delete', () async {
      final cat1 = Category(
        id: 'cat-1',
        shopId: shopId,
        name: 'Dairy',
        imageUrl: 'dairy.png',
      );
      final cat2 = Category(
        id: 'cat-2',
        shopId: shopId,
        name: 'Bakery',
      );

      await LocalDbService.instance.saveCategories(shopId, [cat1, cat2]);
      final loaded = await LocalDbService.instance.getCategories(shopId);
      expect(loaded.length, 2);
      expect(loaded.map((c) => c.name), containsAll(['Dairy', 'Bakery']));

      // Delete cat-2
      await LocalDbService.instance.deleteCategory(shopId, 'cat-2');
      final afterDelete = await LocalDbService.instance.getCategories(shopId);
      expect(afterDelete.length, 1);
      expect(afterDelete.single.name, 'Dairy');
    });

    test('LocalDbService records immutable Customer Ledger entries in chronological order', () async {
      final t1 = DateTime(2026, 11, 14, 10, 0);
      final t2 = DateTime(2026, 11, 14, 10, 30);

      final entry1 = CustomerLedgerEntry(
        id: 'ledg-1',
        shopId: shopId,
        customerId: 'cust-101',
        entryType: 'opening_balance',
        amount: 500,
        balanceAfter: 500,
        note: 'Old balance',
        createdAt: t1,
      );

      final entry2 = CustomerLedgerEntry(
        id: 'ledg-2',
        shopId: shopId,
        customerId: 'cust-101',
        entryType: 'payment',
        amount: 200,
        balanceAfter: 300,
        note: 'Cash payment received',
        createdAt: t2,
      );

      await LocalDbService.instance.addCustomerLedgerEntry(shopId, entry1);
      await LocalDbService.instance.addCustomerLedgerEntry(shopId, entry2);

      final ledger = await LocalDbService.instance.getCustomerLedger(shopId, 'cust-101');
      expect(ledger.length, 2);
      // Ordered by created_at DESC (latest first)
      expect(ledger.first.entryType, 'payment');
      expect(ledger.first.balanceAfter, 300);
      expect(ledger.last.entryType, 'opening_balance');
      expect(ledger.last.balanceAfter, 500);
    });

    test('LocalDbService provides sequential, non-repeating atomic Bill Numbers', () async {
      // First bill starts at 1 (or max bill + 1)
      final bill1 = await LocalDbService.instance.getNextBillNo(shopId);
      final bill2 = await LocalDbService.instance.getNextBillNo(shopId);
      final bill3 = await LocalDbService.instance.getNextBillNo(shopId);

      expect(bill1, 1);
      expect(bill2, 2);
      expect(bill3, 3);

      // Seed with existing store counter e.g. 500
      await LocalDbService.instance.setLastBillNo(shopId, 500);
      final billAfterSeed = await LocalDbService.instance.getNextBillNo(shopId);
      expect(billAfterSeed, 501);
    });

    test('ProductProvider has 0 default categories and only surfaces shopkeeper-created categories', () {
      expect(ProductProvider.defaultCategories, isEmpty);
    });

    test('Bills chronologically sort descending and filter accurately by date periods', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 14, 30);
      final yesterday = today.subtract(const Duration(days: 1));
      final threeDaysAgo = today.subtract(const Duration(days: 3));
      final tenDaysAgo = today.subtract(const Duration(days: 10));

      final bills = [
        {'id': 'b1', 'date': tenDaysAgo, 'total': 100.0},
        {'id': 'b2', 'date': today, 'total': 500.0},
        {'id': 'b3', 'date': yesterday, 'total': 250.0},
        {'id': 'b4', 'date': threeDaysAgo, 'total': 300.0},
      ];

      // Sort descending (latest first)
      bills.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      expect(bills.first['id'], 'b2'); // Today is first
      expect(bills[1]['id'], 'b3');     // Yesterday is second
      expect(bills[2]['id'], 'b4');     // 3 days ago is third
      expect(bills.last['id'], 'b1');   // 10 days ago is last

      // Filter Today
      final todayBills = bills.where((b) {
        final d = b['date'] as DateTime;
        return d.year == today.year && d.month == today.month && d.day == today.day;
      }).toList();
      expect(todayBills.length, 1);
      expect(todayBills.single['total'], 500.0);

      // Filter Yesterday
      final yestBills = bills.where((b) {
        final d = b['date'] as DateTime;
        return d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day;
      }).toList();
      expect(yestBills.length, 1);
      expect(yestBills.single['total'], 250.0);
    });
  });
}
