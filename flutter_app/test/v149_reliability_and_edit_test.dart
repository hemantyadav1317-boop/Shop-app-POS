import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_update/ota_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shop_pos/core/services/backup_service.dart';
import 'package:shop_pos/core/services/printer_settings_service.dart';
import 'package:shop_pos/core/services/receipt_print_service.dart';
import 'package:shop_pos/core/services/update_service.dart';
import 'package:shop_pos/data/models/cart_item.dart';
import 'package:shop_pos/data/models/customer.dart';
import 'package:shop_pos/data/models/product.dart';
import 'package:shop_pos/data/models/sale.dart';
import 'package:shop_pos/data/models/shop.dart';
import 'package:shop_pos/data/services/local_db_service.dart';
import 'package:shop_pos/data/services/supabase_service.dart';
import 'package:shop_pos/providers/cart_provider.dart';
import 'package:shop_pos/providers/product_provider.dart';
import 'package:shop_pos/screens/pos/widgets/bill_receipt_card.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  for (final channelName in const [
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers',
    'com.shop.pos/native_sound',
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channelName), (call) async {
      if (channelName == 'com.shop.pos/native_sound') return true;
      return null;
    });
  }

  SharedPreferences.setMockInitialValues({});
  await PrinterSettingsService.instance.loadSettings();

  final sampleShop = Shop(
    id: 'demo-shop-101',
    name: 'Shree Ganesh Store',
    phone: '9876543210',
    upiId: 'ganesh@okaxis',
    upiPayeeName: 'Ganesh Store',
    googleReviewUrl: 'https://g.page/r/ganesh/review',
  );

  group('v1.4.9 OTA Single-Execution Fix', () {
    tearDown(() {
      UpdateService.otaStreamFactory = null;
      UpdateService.resetOtaState();
    });

    testWidgets('startInAppDownload executes OtaUpdate strictly once across progress rebuilds',
        (tester) async {
      int executeCount = 0;
      final controller = StreamController<OtaEvent>();
      UpdateService.otaStreamFactory = (url, file) {
        executeCount++;
        return controller.stream;
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => UpdateService.startInAppDownload(
                  context,
                  'https://example.com/ShopPOS-Release.apk',
                ),
                child: const Text('Start Update'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start Update'));
      await tester.pump();

      expect(executeCount, 1);

      controller.add(OtaEvent(OtaStatus.DOWNLOADING, '25'));
      await tester.pump();
      expect(find.text('डाउनलोड हो रहा है: 25%'), findsOneWidget);

      controller.add(OtaEvent(OtaStatus.DOWNLOADING, '80'));
      await tester.pump();
      expect(find.text('डाउनलोड हो रहा है: 80%'), findsOneWidget);

      // Even after multiple setState rebuilds, OTA stream was created strictly once
      expect(executeCount, 1);

      await controller.close();
      await tester.pumpAndSettle();
    });
  });

  group('v1.4.9 Double-Layer SQLite & Outbox Tests', () {
    setUp(() async {
      await LocalDbService.instance.closeForTest();
      await LocalDbService.instance.init(dbPathOverride: inMemoryDatabasePath);
    });

    tearDown(() async {
      await LocalDbService.instance.closeForTest();
    });

    test('Stores unlimited (>200) sales locally and preserves offline edits against cloud merge',
        () async {
      const shopId = 'shop-sqlite-test';
      final bulkSales = List.generate(
        250,
        (i) => Sale(
          id: 'sale-$i',
          shopId: shopId,
          billNo: 1000 + i,
          items: [
            CartItem(productId: 'p1', name: 'Atta', unit: 'kg', price: 45, qty: 2),
          ],
          subtotal: 90,
          total: 90,
          paid: 90,
          paymentMode: 'cash',
          createdAt: DateTime(2026, 11, 1).add(Duration(minutes: i)),
        ),
      );

      await LocalDbService.instance.saveSales(shopId, bulkSales);
      final loadedAll = await LocalDbService.instance.getSales(shopId);
      expect(loadedAll.length, 250);

      // Simulate offline edit on sale-5 that is queued in sync_outbox
      final editedOffline = loadedAll.firstWhere((s) => s.id == 'sale-5').copyWith(
        items: [
          CartItem(productId: 'p1', name: 'Atta', unit: 'kg', price: 45, qty: 5),
        ],
        subtotal: 225,
        total: 225,
        paid: 225,
        editCount: 1,
      );
      await LocalDbService.instance.upsertSale(shopId, editedOffline);
      await LocalDbService.instance.enqueueOutbox(
        shopId: shopId,
        entityType: 'sale',
        entityId: editedOffline.id,
        operation: 'update_sale',
        payload: {'sale': editedOffline.toJson()},
      );

      expect(await LocalDbService.instance.getPendingOutboxCount(shopId), 1);

      // Now simulate stale cloud reload trying to overwrite sale-5 back to original qty=2
      await LocalDbService.instance.saveSales(shopId, bulkSales);
      final afterMerge = await LocalDbService.instance.getSales(shopId);
      final mergedSale5 = afterMerge.firstWhere((s) => s.id == 'sale-5');
      expect(mergedSale5.editCount, 1);
      expect(mergedSale5.items.first.qty, 5);
      expect(mergedSale5.total, 225);
    });

    test('Soft-deleted product stays excluded across SQLite product snapshot reloads', () async {
      const shopId = 'shop-del-prod';
      final p1 = Product(
        id: 'prod-1',
        shopId: shopId,
        name: 'Aalu',
        category: 'VEGETABLES',
        unit: 'kg',
        price: 30,
        stock: 10,
      );
      final p2 = Product(
        id: 'prod-2',
        shopId: shopId,
        name: 'Tamatar',
        category: 'VEGETABLES',
        unit: 'kg',
        price: 50,
        stock: 8,
      );

      await LocalDbService.instance.saveProducts(shopId, [p1, p2]);
      await LocalDbService.instance.markProductDeleted(shopId, 'prod-1');

      // Re-saving snapshot still keeps prod-1 hidden until cloud deletion confirmed
      await LocalDbService.instance.saveProducts(shopId, [p1, p2]);
      final loaded = await LocalDbService.instance.getProducts(shopId);
      expect(loaded.map((p) => p.id).toList(), ['prod-2']);
    });
  });

  group('v1.4.9 Phone Backup Export & Restore Tests', () {
    test('BackupService exports full store JSON and parses back accurately', () async {
      final tempDir = await Directory.systemTemp.createTemp('shop_pos_backup_test_');
      try {
        final products = [
          Product(
            id: 'p-100',
            shopId: sampleShop.id,
            name: 'Sugar',
            category: 'GRAINS',
            unit: 'kg',
            price: 44,
            stock: 25,
          ),
        ];
        final customers = [
          Customer(
            id: 'c-100',
            shopId: sampleShop.id,
            name: 'Ramesh',
            phone: '9988776655',
            balance: 120,
            createdAt: DateTime(2026, 11, 5),
          ),
        ];
        final sales = [
          Sale(
            id: 's-100',
            shopId: sampleShop.id,
            billNo: 88,
            items: [CartItem(productId: 'p-100', name: 'Sugar', unit: 'kg', price: 44, qty: 2)],
            subtotal: 88,
            total: 88,
            paid: 88,
            paymentMode: 'cash',
            createdAt: DateTime(2026, 11, 5, 14, 30),
            editCount: 2,
          ),
        ];
        final catCfg = {
          'custom_categories': ['MASALA'],
          'deleted_categories': ['SNACKS'],
        };

        final exported = await BackupService.exportBackupToPhone(
          shop: sampleShop,
          products: products,
          customers: customers,
          sales: sales,
          categoriesConfig: catCfg,
          directoryOverride: tempDir.path,
        );

        expect(await exported.file.exists(), isTrue);
        expect(exported.productsCount, 1);
        expect(exported.customersCount, 1);
        expect(exported.salesCount, 1);

        final raw = await exported.file.readAsString();
        final parsed = BackupService.parseBackupJson(raw);

        expect(parsed.shop?.name, sampleShop.name);
        expect(parsed.products.single.name, 'Sugar');
        expect(parsed.customers.single.balance, 120);
        expect(parsed.sales.single.editCount, 2);
        expect(parsed.categoriesConfig['deleted_categories'], ['SNACKS']);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('BackupService rejects invalid JSON payload', () {
      expect(
        () => BackupService.parseBackupJson('{"random": 123}'),
        throwsFormatException,
      );
    });
  });

  group('v1.4.9 Bill Edit Mode & Edited Count Tag Tests', () {
    test('Sale encodes & parses editCount + lastEditedAt through cloud-safe note metadata', () {
      final editedAt = DateTime(2026, 11, 12, 18, 45);
      final sale = Sale(
        id: 'sale-edit-meta',
        shopId: sampleShop.id,
        billNo: 55,
        items: [CartItem(name: 'Rice', unit: 'kg', price: 70, qty: 3)],
        subtotal: 210,
        total: 210,
        paid: 210,
        paymentMode: 'online',
        paymentStatus: 'completed',
        upiPaid: 210,
        onlineVerified: true,
        verificationSource: 'cashier_verified',
        createdAt: DateTime(2026, 11, 12, 15, 0),
        editCount: 3,
        lastEditedAt: editedAt,
      );

      final reparsed = Sale.fromJson({
        'id': sale.id,
        'shop_id': sale.shopId,
        'bill_no': sale.billNo,
        'sub_total': sale.subtotal,
        'discount': sale.discount,
        'total': sale.total,
        'paid': sale.paid,
        'due': sale.due,
        'payment_mode': sale.paymentMode,
        'note': sale.encodedNote,
        'created_at': sale.createdAt.toIso8601String(),
        'sale_items': sale.items.map((e) => e.toJson()).toList(),
      });

      expect(reparsed.editCount, 3);
      expect(reparsed.isEdited, isTrue);
      expect(reparsed.editedTagText, 'Edited (3)');
      expect(reparsed.lastEditedAt?.year, 2026);
      expect(reparsed.onlineVerified, isTrue);
    });

    test('CartProvider.startEditingSale loads saved bill items, customer & discount for cart editing',
        () {
      final cart = CartProvider();
      final originalSale = Sale(
        id: 'sale-cart-1',
        shopId: sampleShop.id,
        billNo: 301,
        customerId: 'cust-1',
        customerName: 'Suresh',
        customerPhone: '9876500000',
        items: [
          CartItem(productId: 'p1', name: 'Onion', unit: 'kg', price: 35, qty: 2),
        ],
        subtotal: 70,
        discount: 10,
        total: 60,
        paid: 60,
        paymentMode: 'cash',
        createdAt: DateTime(2026, 11, 10),
        editCount: 1,
      );

      cart.startEditingSale(originalSale);
      expect(cart.isEditingBill, isTrue);
      expect(cart.editingSale?.billNo, 301);
      expect(cart.lines.length, 1);
      expect(cart.lines.first.qty, 2);
      expect(cart.discount, 10);
      expect(cart.customer?.name, 'Suresh');

      // Mutating cart during edit
      cart.setQty('p1', 'Onion', 4);
      expect(cart.lines.first.qty, 4);
      expect(cart.total, 130); // (35 * 4) - 10

      cart.cancelEditing();
      expect(cart.isEditingBill, isFalse);
      expect(cart.lines, isEmpty);
      expect(cart.discount, 0);
    });

    testWidgets('BillReceiptCard & Share Caption display Edited (N) badge when editCount > 0',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BillReceiptCard(
                shopName: sampleShop.name,
                billNo: '301',
                dateString: '12-11-2026 07:00 PM',
                items: [
                  CartItem(productId: 'p1', name: 'Onion', unit: 'kg', price: 35, qty: 2),
                ],
                subtotal: 70,
                total: 70,
                paid: 70,
                paymentMode: 'cash',
                editCount: 2,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edited (2)'), findsOneWidget);

      final editedSale = Sale(
        id: 's-cap',
        shopId: sampleShop.id,
        billNo: 301,
        items: [CartItem(name: 'Onion', unit: 'kg', price: 35, qty: 2)],
        subtotal: 70,
        total: 70,
        paid: 70,
        paymentMode: 'cash',
        createdAt: DateTime.now(),
        editCount: 2,
      );
      final caption = ReceiptPrintService.buildShareCaption(
        sale: editedSale,
        shop: sampleShop,
      );
      expect(caption, contains('[Edited (2)]'));
    });

    test('ProductProvider adds/deletes categories & items persistently and applies stock diff',
        () async {
      SharedPreferences.setMockInitialValues({});
      await LocalDbService.instance.closeForTest();
      await LocalDbService.instance.init(dbPathOverride: inMemoryDatabasePath);
      SupabaseService.instance.resetLocalData();

      final prov = ProductProvider();
      await prov.addCategory('MASALA');
      expect(prov.allCategories, contains('MASALA'));

      await prov.addProduct(Product(
        id: 'prod-masala-1',
        shopId: 'demo-shop-101',
        name: 'Haldi',
        category: 'MASALA',
        unit: 'kg',
        price: 200,
        stock: 15,
      ));
      expect(prov.products.length, 1);
      final savedProd = prov.products.single;

      // Stock diff from bill edit (old qty 2 -> new qty 5 => -3 stock)
      prov.applyStockDiff(
        [CartItem(productId: savedProd.id, name: 'Haldi', unit: 'kg', price: 200, qty: 2)],
        [CartItem(productId: savedProd.id, name: 'Haldi', unit: 'kg', price: 200, qty: 5)],
      );
      expect(prov.products.single.stock, 12);

      // Delete category cascade removes its items and category stays gone on reload
      await prov.deleteCategory('MASALA');
      expect(prov.allCategories, isNot(contains('MASALA')));
      expect(prov.products, isEmpty);

      await prov.loadProducts('demo-shop-101');
      expect(prov.allCategories, isNot(contains('MASALA')));
      expect(prov.products, isEmpty);
    });
  });
}

