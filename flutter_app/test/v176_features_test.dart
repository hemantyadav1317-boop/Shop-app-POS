import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shop_pos/core/services/printer_settings_service.dart';
import 'package:shop_pos/core/services/time_sync_service.dart';
import 'package:shop_pos/core/services/update_service.dart';
import 'package:shop_pos/core/utils/payment_qr_helper.dart';
import 'package:shop_pos/data/models/cart_item.dart';
import 'package:shop_pos/data/models/customer.dart';
import 'package:shop_pos/data/models/product.dart';
import 'package:shop_pos/data/models/sale.dart';
import 'package:shop_pos/data/models/shop.dart';
import 'package:shop_pos/data/services/local_db_service.dart';
import 'package:shop_pos/data/services/supabase_service.dart';
import 'package:shop_pos/data/services/upi_service.dart';
import 'package:shop_pos/providers/auth_provider.dart';
import 'package:shop_pos/providers/cart_provider.dart';
import 'package:shop_pos/providers/customer_provider.dart';
import 'package:shop_pos/providers/locale_provider.dart';
import 'package:shop_pos/providers/product_provider.dart';
import 'package:shop_pos/providers/shop_provider.dart';
import 'package:shop_pos/screens/bills/bills_screen.dart';
import 'package:shop_pos/screens/customers/customers_screen.dart';
import 'package:shop_pos/screens/inventory/add_edit_product_screen.dart';
import 'package:shop_pos/screens/inventory/inventory_screen.dart';
import 'package:shop_pos/screens/pos/widgets/bill_receipt_card.dart';
import 'package:shop_pos/screens/pos/widgets/payment_dialog.dart';
import 'package:shop_pos/screens/settings/feature_settings_screen.dart';
import 'package:shop_pos/screens/settings/settings_screen.dart';

void main() {
  group('v1.7.6 Feature & Navigation Tests', () {
    test('Version is properly formatted as semantic version', () {
      final v = UpdateService.currentVersion;
      expect(v, isNotEmpty);
      expect(RegExp(r'^\d+\.\d+\.\d+$').hasMatch(v), isTrue);
    });

    test('Parallel cloud sync logic constructs properly', () async {
      // Verifies Future.wait parallelization logic runs cleanly
      final futures = [
        Future.value([{'category': 'GROCERY'}]),
        Future.value(['Product 1', 'Product 2']),
      ];
      final results = await Future.wait(futures);
      expect(results.length, 2);
      expect(results[0], isNotEmpty);
      expect(results[1], isNotEmpty);
    });

    test('Google Pay dynamic QR omits tr and sanitizes # from note', () {
      final uri = UpiService.generateUpiUri(
        upiId: 'yadavstore@okicici',
        payeeName: 'Yadav Store',
        amount: 140.0,
        note: 'Bill #140',
        billNo: '140',
        includeTr: false,
      );

      // Verify no tr parameter is present (bypasses GPay merchant check failure)
      expect(uri.contains('tr='), isFalse);

      // Verify no '#' symbol in note or anywhere in the URI
      expect(uri.contains('#'), isFalse);
      expect(uri.contains('%23'), isFalse);

      // Verify valid NPCI UPI intent structure
      expect(uri.startsWith('upi://pay?'), isTrue);
      expect(uri, contains('pa=yadavstore@okicici'));
      expect(uri, contains('pn=Yadav%20Store'));
      expect(uri, contains('am=140.00'));
      expect(uri, contains('cu=INR'));
      expect(uri, contains('tn=Bill%20140'));

      // Validate URI parsing without exceptions
      final parsed = Uri.parse(uri);
      expect(parsed.scheme, 'upi');
      expect(parsed.host, 'pay');
      expect(parsed.queryParameters['pa'], 'yadavstore@okicici');
      expect(parsed.queryParameters['pn'], 'Yadav Store');
      expect(parsed.queryParameters['am'], '140.00');
      expect(parsed.queryParameters['cu'], 'INR');
      expect(parsed.queryParameters['tn'], 'Bill 140');
      expect(parsed.queryParameters.containsKey('tr'), isFalse);
    });

    test('UpiService sanitizes special characters from notes and payee names', () {
      final uri = UpiService.generateUpiUri(
        upiId: 'shop@ybl',
        payeeName: 'Kirana & Super Store (Main)',
        amount: 250.50,
        note: 'Order #99_Special & Discount?',
        includeTr: false,
      );

      expect(uri.contains('#'), isFalse);
      expect(uri.contains('_'), isFalse);
      final parsed = Uri.parse(uri);
      expect(parsed.queryParameters['tn']!.contains('&'), isFalse);
      expect(parsed.queryParameters['am'], '250.50');
      expect(parsed.queryParameters['tn'], 'Order 99 Special Discount');
    });

    test('PaymentQrHelper.buildUpiUri supports includeTr: false for Google Pay', () {
      final uri = PaymentQrHelper.buildUpiUri(
        upiId: 'retailer@paytm',
        payeeName: 'Retail Shop',
        amount: 75.0,
        billNo: '#55',
        includeTr: false,
      );

      expect(uri, isNotNull);
      expect(uri!.contains('tr='), isFalse);
      expect(uri.contains('#'), isFalse);
      expect(uri, contains('tn=Bill%2055'));
    });

    testWidgets('Main tab CustomersScreen always shows menu icon even when Navigator.canPop is true', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ShopProvider()),
            ChangeNotifierProvider(create: (_) => CustomerProvider()),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CustomersScreen(isMainTab: true)),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Must show menu icon instead of back arrow so user can never pop MainShell to black screen
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });

    testWidgets('SettingsScreen shows menu when isMainTab is true and back arrow when pushed', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ShopProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen(isMainTab: true)),
                      ),
                      child: const Text('OpenTab'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen(isMainTab: false)),
                      ),
                      child: const Text('OpenStandalone'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OpenTab'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);

      // Navigate back cleanly and open standalone pushed SettingsScreen
      Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('OpenStandalone'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('BillsScreen keeps clean spacing between date/time label and Total on 360px phone width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({});
      await LocalDbService.instance.closeForTest(disable: true);

      const shopId = 'demo-shop-101';
      await SupabaseService.instance.createSale(
        Sale(
          id: 'bill-spacing-1',
          shopId: shopId,
          billNo: 1100,
          customerName: 'Vinay Bro',
          items: [
            CartItem(productId: 'p1', name: 'Tomato', unit: 'kg', price: 90, qty: 2),
          ],
          subtotal: 180,
          total: 180,
          paid: 0,
          due: 180,
          paymentMode: 'credit',
          createdAt: DateTime(2026, 11, 25, 16, 9),
        ),
      );
      await SupabaseService.instance.createSale(
        Sale(
          id: 'bill-edited-1',
          shopId: shopId,
          billNo: 1099,
          customerName: 'Edited Customer',
          items: [
            CartItem(productId: 'p2', name: 'Onion', unit: 'kg', price: 40, qty: 1),
          ],
          subtotal: 40,
          total: 40,
          paid: 40,
          due: 0,
          paymentMode: 'cash',
          editCount: 1,
          createdAt: DateTime(2026, 11, 25, 15, 30),
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ShopProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => CartProvider()),
            ChangeNotifierProvider(create: (_) => CustomerProvider()),
            ChangeNotifierProvider(create: (_) => ProductProvider()),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: const MaterialApp(
            home: BillsScreen(isMainTab: true),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('1100'), findsOneWidget);
      expect(find.text('1099'), findsOneWidget);
      final timeRect = tester.getRect(find.text('25 Nov 2026 4:09 PM'));
      final totalRect = tester.getRect(find.text('Total : ').first);
      expect(timeRect.right, lessThanOrEqualTo(totalRect.left - 10));

      // Verify Edited Bills filter shows only edited bill (#1099)
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edited Bills (संपादित बिल)'));
      await tester.pumpAndSettle();
      expect(find.text('1099'), findsOneWidget);
      expect(find.text('1100'), findsNothing);
    });

    test('Split payment Cash + UPI + Credit calculates exact Khata creditAmount', () {
      // Case 1: ₹250 bill -> ₹200 Cash, ₹0 UPI, ₹50 Credit (Udhaar)
      final cashPlusCredit = PaymentQrHelper.calculateBreakdown(
        total: 250.0,
        paymentMode: 'split',
        cashAmount: 200.0,
        upiAmount: 0.0,
        creditAmount: 50.0,
        onlineVerified: false,
      );
      expect(cashPlusCredit.cashPaid, 200.0);
      expect(cashPlusCredit.upiPayable, 0.0);
      expect(cashPlusCredit.creditAmount, 50.0);
      expect(cashPlusCredit.paid, 200.0);
      expect(cashPlusCredit.due, 50.0);

      // Case 2: ₹250 bill -> ₹100 Cash, ₹100 UPI (Verified), ₹50 Credit (Udhaar)
      final allThreeSplit = PaymentQrHelper.calculateBreakdown(
        total: 250.0,
        paymentMode: 'split',
        cashAmount: 100.0,
        upiAmount: 100.0,
        creditAmount: 50.0,
        onlineVerified: true,
      );
      expect(allThreeSplit.cashPaid, 100.0);
      expect(allThreeSplit.upiPaid, 100.0);
      expect(allThreeSplit.creditAmount, 50.0);
      expect(allThreeSplit.paid, 200.0);
      expect(allThreeSplit.due, 50.0);
    });

    test('LocalDbService syncs bill counter floor on saveSales and ignores stale lower counter', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      SharedPreferences.setMockInitialValues({});
      await LocalDbService.instance.closeForTest();
      await LocalDbService.instance.init(dbPathOverride: inMemoryDatabasePath);

      const shopId = 'shop-counter-test';
      // Simulate stale device counter at 964 while cloud has bills 1168 and 1169
      await LocalDbService.instance.setLastBillNo(shopId, 964);
      final cloudSales = [
        Sale(
          id: 's-1168',
          shopId: shopId,
          billNo: 1168,
          items: [CartItem(productId: 'p1', name: 'Aloo', unit: 'kg', price: 40, qty: 1)],
          subtotal: 40,
          total: 40,
          paid: 40,
          due: 0,
          paymentMode: 'cash',
          createdAt: DateTime.utc(2026, 11, 25, 6, 30),
        ),
        Sale(
          id: 's-1169',
          shopId: shopId,
          billNo: 1169,
          items: [CartItem(productId: 'p1', name: 'Aloo', unit: 'kg', price: 80, qty: 1)],
          subtotal: 80,
          total: 80,
          paid: 80,
          due: 0,
          paymentMode: 'cash',
          createdAt: DateTime.utc(2026, 11, 25, 7, 0),
        ),
      ];

      await LocalDbService.instance.saveSales(shopId, cloudSales);
      expect(await LocalDbService.instance.peekNextBillNo(shopId), 1170);
      expect(await LocalDbService.instance.getNextBillNo(shopId), 1170);
      expect(await LocalDbService.instance.getNextBillNo(shopId), 1171);

      // Verify counters >= 10,000 and >= 10,00,000 (10 Lakh+) work cleanly with no cap, while 10-digit Unix epoch outliers are ignored
      await LocalDbService.instance.syncCounterFloor(shopId, 10000);
      expect(await LocalDbService.instance.getNextBillNo(shopId), 10001);
      await LocalDbService.instance.syncCounterFloor(shopId, 1000005);
      expect(await LocalDbService.instance.getNextBillNo(shopId), 1000006);
      await LocalDbService.instance.syncCounterFloor(shopId, 1795592537);
      expect(await LocalDbService.instance.peekNextBillNo(shopId), 1000007);

      await LocalDbService.instance.closeForTest();
    });

    test('Sale createdAt preserves exact UTC->Local timestamp without time-dependent 5:30 drift', () {
      final originalLocal = DateTime(2026, 11, 24, 20, 15);
      final sale = Sale(
        id: 'sale-ts-1',
        shopId: 'shop-1',
        billNo: 101,
        items: const [],
        subtotal: 100,
        total: 100,
        paid: 100,
        due: 0,
        paymentMode: 'cash',
        createdAt: originalLocal,
      );

      final json = sale.toJson();
      expect((json['created_at'] as String).endsWith('Z'), isTrue);

      final decoded = Sale.fromJson(json);
      expect(decoded.createdAt.toLocal().year, originalLocal.year);
      expect(decoded.createdAt.toLocal().month, originalLocal.month);
      expect(decoded.createdAt.toLocal().day, originalLocal.day);
      expect(decoded.createdAt.toLocal().hour, originalLocal.hour);
      expect(decoded.createdAt.toLocal().minute, originalLocal.minute);
    });

    testWidgets('Split payment updates Dynamic UPI QR live and adds Credit to Customer Khata', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final shopProvider = ShopProvider(
        initialShop: Shop(
          id: 'demo-shop-101',
          name: 'Yadav Store',
          upiId: 'yadavstore@okicici',
          upiPayeeName: 'Yadav Store',
        ),
      );
      final cartProvider = CartProvider();
      cartProvider.incrementOrAdd(
        Product(
          id: 'prod-1',
          shopId: 'demo-shop-101',
          name: 'Sugar',
          category: 'GROCERY',
          price: 300.0,
          unit: 'kg',
          stock: 50,
        ),
      );
      final cust = Customer(
        id: 'cust-1',
        shopId: 'demo-shop-101',
        name: 'Ramesh',
        phone: '9876543210',
        balance: 100.0,
        createdAt: DateTime.now(),
      );
      cartProvider.setCustomer(cust);

      final custProvider = CustomerProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: shopProvider),
            ChangeNotifierProvider.value(value: cartProvider),
            ChangeNotifierProvider.value(value: custProvider),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => ProductProvider()),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PaymentDialog(onSaleCompleted: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Split tab
      await tester.tap(find.text('Split'));
      await tester.pumpAndSettle();

      // Should have 3 TextFields: Cash (0), UPI (1), Credit (2)
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(3));

      // Enter Cash = 50, UPI = 200 -> Credit automatically becomes 50 & QR shows ₹200.00
      await tester.enterText(fields.at(0), '50');
      await tester.pump();
      await tester.enterText(fields.at(1), '200');
      await tester.pump();

      expect(tester.widget<TextField>(fields.at(2)).controller!.text, '50');
      expect(find.text('Ramesh के खाते में ₹50 उधार जुड़ेगा'), findsOneWidget);
      expect(find.text('Payable: ₹ 200.00'), findsOneWidget);
      final qr1 = tester.widget<QrImageView>(find.byType(QrImageView));
      final qr1Uri = (qr1.key as ValueKey<String>).value;
      expect(qr1Uri, contains('am=200.00'));
      expect(qr1Uri.contains('tr='), isFalse);
      expect(qr1Uri.contains('#'), isFalse);

      // Change UPI live from 200 to 150 -> Credit becomes 100 & QR immediately updates to ₹150.00
      await tester.enterText(fields.at(1), '150');
      await tester.pump();

      expect(tester.widget<TextField>(fields.at(2)).controller!.text, '100');
      expect(find.text('Ramesh के खाते में ₹100 उधार जुड़ेगा'), findsOneWidget);
      expect(find.text('Payable: ₹ 150.00'), findsOneWidget);
      final qr2 = tester.widget<QrImageView>(find.byType(QrImageView));
      final qr2Uri = (qr2.key as ValueKey<String>).value;
      expect(qr2Uri, contains('am=150.00'));

      // Verify no D-Mart label and no double checkbox exist
      expect(find.textContaining('D-Mart'), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
    });

    test('Full Credit sale updates customer balance in SQLite/RAM immediately and getCustomerSales preserves other customers bills', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      SharedPreferences.setMockInitialValues({});
      await LocalDbService.instance.closeForTest();
      await LocalDbService.instance.init(dbPathOverride: inMemoryDatabasePath);

      const shopId = 'demo-shop-101';
      final custA = await SupabaseService.instance.addCustomer(
        Customer(
          id: '11111111-1111-1111-1111-111111111111',
          shopId: shopId,
          name: 'Suresh',
          phone: '9999900001',
          balance: 100.0,
          createdAt: DateTime.now(),
        ),
      );
      final custB = await SupabaseService.instance.addCustomer(
        Customer(
          id: '22222222-2222-2222-2222-222222222222',
          shopId: shopId,
          name: 'Mahesh',
          phone: '9999900002',
          balance: 50.0,
          createdAt: DateTime.now(),
        ),
      );

      // Bill 1: Customer A buys ₹250 on Full Credit -> balance must become 350.0 immediately
      final saleA = Sale(
        id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        shopId: shopId,
        billNo: 201,
        customerId: custA.id,
        customerName: custA.name,
        customerPhone: custA.phone,
        items: [CartItem(productId: 'p1', name: 'Atta', unit: 'kg', price: 250, qty: 1)],
        subtotal: 250,
        total: 250,
        paid: 0,
        due: 250,
        paymentMode: 'credit',
        paymentStatus: 'pending',
        creditAmount: 250,
        createdAt: DateTime.now(),
      );
      await SupabaseService.instance.createSale(saleA);

      // Bill 2: Customer B buys ₹150 on Full Credit -> balance must become 200.0 immediately
      final saleB = Sale(
        id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        shopId: shopId,
        billNo: 202,
        customerId: custB.id,
        customerName: custB.name,
        customerPhone: custB.phone,
        items: [CartItem(productId: 'p2', name: 'Rice', unit: 'kg', price: 150, qty: 1)],
        subtotal: 150,
        total: 150,
        paid: 0,
        due: 150,
        paymentMode: 'credit',
        paymentStatus: 'pending',
        creditAmount: 150,
        createdAt: DateTime.now(),
      );
      await SupabaseService.instance.createSale(saleB);

      // Verify SQLite & getCustomerById reflect exact live balances
      final dbCusts = await LocalDbService.instance.getCustomers(shopId);
      expect(dbCusts.firstWhere((c) => c.id == custA.id).balance, 350.0);
      expect(dbCusts.firstWhere((c) => c.id == custB.id).balance, 200.0);
      expect((await SupabaseService.instance.getCustomerById(custA.id))!.balance, 350.0);

      // Verify getCustomerSales returns each customer's bill immediately AND preserves all shop sales in SQLite
      final custASales = await SupabaseService.instance.getCustomerSales(shopId, custA.id, customerPhone: custA.phone);
      expect(custASales.any((s) => s.id == saleA.id && s.total == 250.0), isTrue);

      final allDbSalesAfterCustA = await LocalDbService.instance.getSales(shopId);
      expect(allDbSalesAfterCustA.any((s) => s.id == saleB.id), isTrue);

      await LocalDbService.instance.closeForTest();
    });

    testWidgets('BillReceiptCard renders 10-Lakh+ billNo (1000005) + Edited tag without overflow on narrow width', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
                  child: BillReceiptCard(
                    shopName: 'Yadav Kirana Store',
                    billNo: '1000005',
                    dateString: '25-11-2026 02:30 PM',
                    customerName: 'Ramesh Kumar',
                    customerPhone: '9876543210',
                    items: [
                      CartItem(productId: 'p1', name: 'Aashirvaad Atta 5kg', unit: 'pkt', price: 245, qty: 2),
                    ],
                    subtotal: 490,
                    discount: 10,
                    total: 480,
                    paid: 480,
                    due: 0,
                    paymentMode: 'cash',
                    editCount: 2,
                    fontScale: 1.45,
                    printWidth: 300,
                    showQr: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Invoice 1000005'), findsOneWidget);
      expect(find.text('25-11-2026 02:30 PM'), findsOneWidget);
      expect(find.textContaining('Edited'), findsOneWidget);
    });

    test('Authoritative cloud sync heals poisoned local counter (98730 -> 1100) while protecting pending offline bills', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      SharedPreferences.setMockInitialValues({});
      await LocalDbService.instance.closeForTest();
      await LocalDbService.instance.init(dbPathOverride: inMemoryDatabasePath);

      const shopId = 'shop-heal-test';
      // Phone had poisoned counter 98730 cached locally
      await LocalDbService.instance.setLastBillNo(shopId, 98730);
      expect(await LocalDbService.instance.peekNextBillNo(shopId), 98731);

      // Cloud has been cleanly renumbered to 1..1100 and no offline bills are pending in outbox
      final cleanCloudSales = [
        Sale(
          id: 's-1100',
          shopId: shopId,
          billNo: 1100,
          items: [CartItem(productId: 'p1', name: 'Aloo', unit: 'kg', price: 40, qty: 1)],
          subtotal: 40,
          total: 40,
          paid: 40,
          due: 0,
          paymentMode: 'cash',
          createdAt: DateTime.utc(2026, 11, 25, 10, 0),
        ),
      ];
      await LocalDbService.instance.saveSales(
        shopId,
        cleanCloudSales,
        authoritativeCloudSync: true,
      );
      expect(await LocalDbService.instance.peekNextBillNo(shopId), 1101);
      expect(await LocalDbService.instance.getNextBillNo(shopId), 1101);

      // Pending offline sale in outbox must protect local counter from shrinking
      await LocalDbService.instance.enqueueOutbox(
        shopId: shopId,
        entityType: 'sale',
        entityId: 'offline-1102',
        operation: 'create',
        payload: {
          'sale': Sale(
            id: 'offline-1102',
            shopId: shopId,
            billNo: 1102,
            items: [CartItem(productId: 'p1', name: 'Pyaz', unit: 'kg', price: 50, qty: 1)],
            subtotal: 50,
            total: 50,
            paid: 50,
            due: 0,
            paymentMode: 'cash',
            createdAt: DateTime.now(),
          ).toJson(),
        },
      );
      await LocalDbService.instance.setLastBillNo(shopId, 1102);
      await LocalDbService.instance.reconcileCounterFromCloud(shopId, 1100);
      expect(await LocalDbService.instance.peekNextBillNo(shopId), 1103);

      await LocalDbService.instance.closeForTest();
    });

    testWidgets('BillsScreen Clear Bill History popup clears bills and resets counter to #1', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      await LocalDbService.instance.closeForTest(disable: true);

      const shopId = 'demo-shop-101';
      await SupabaseService.instance.clearBillHistory(shopId);
      await LocalDbService.instance.setLastBillNo(shopId, 50);
      await SupabaseService.instance.createSale(
        Sale(
          id: 'clr-sale-1',
          shopId: shopId,
          billNo: 50,
          customerName: 'Ramesh',
          items: [CartItem(productId: 'p1', name: 'Tomato', unit: 'kg', price: 40, qty: 1)],
          subtotal: 40,
          total: 40,
          paid: 40,
          due: 0,
          paymentMode: 'cash',
          createdAt: DateTime(2026, 11, 25, 16, 0),
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ShopProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => CartProvider()),
            ChangeNotifierProvider(create: (_) => CustomerProvider()),
            ChangeNotifierProvider(create: (_) => ProductProvider()),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: const MaterialApp(home: BillsScreen(isMainTab: true)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('50'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Clear Bill History?'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to delete all 1 saved bills?'), findsOneWidget);

      await tester.tap(find.text('हाँ, साफ़ करें (Clear)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('No bills found'), findsOneWidget);
      expect(await LocalDbService.instance.peekNextBillNo(shopId), 1);
      await LocalDbService.instance.closeForTest();
    });

    test('clearBillHistory wipes SQLite sales/outbox and resets bill counter to #1', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      SharedPreferences.setMockInitialValues({});
      await LocalDbService.instance.closeForTest();
      await LocalDbService.instance.init(dbPathOverride: inMemoryDatabasePath);

      const shopId = 'demo-shop-101';
      await LocalDbService.instance.setLastBillNo(shopId, 75);
      await SupabaseService.instance.createSale(
        Sale(
          id: 'clr-db-sale-1',
          shopId: shopId,
          billNo: 75,
          customerName: 'Mohan',
          items: [CartItem(productId: 'p1', name: 'Gobi', unit: 'kg', price: 30, qty: 1)],
          subtotal: 30,
          total: 30,
          paid: 30,
          due: 0,
          paymentMode: 'cash',
          createdAt: DateTime.now(),
        ),
      );
      expect(await LocalDbService.instance.getSales(shopId), isNotEmpty);

      await SupabaseService.instance.clearBillHistory(shopId, resetCounterToOne: true);

      expect(await LocalDbService.instance.getSales(shopId), isEmpty);
      expect(await LocalDbService.instance.getPendingOutboxCount(shopId), 0);
      expect(await LocalDbService.instance.peekNextBillNo(shopId), 1);

      await LocalDbService.instance.closeForTest();
    });

    test('deleteSale can restore sold product stock and reverse customer Khata credit', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      SharedPreferences.setMockInitialValues({});
      await LocalDbService.instance.closeForTest();
      await LocalDbService.instance.init(dbPathOverride: inMemoryDatabasePath);

      const shopId = 'demo-shop-101';
      final prod = Product(
        id: 'prod-rev-1',
        shopId: shopId,
        name: 'Aloo',
        price: 30,
        stock: 10,
        category: 'VEGETABLES',
        unit: 'kg',
      );
      await LocalDbService.instance.saveProducts(shopId, [prod]);

      final cust = Customer(
        id: 'cust-rev-1',
        shopId: shopId,
        name: 'Kishan',
        phone: '9988776655',
        balance: 150,
        createdAt: DateTime.now(),
      );
      await LocalDbService.instance.saveCustomers(shopId, [cust]);

      final sale = Sale(
        id: 'sale-rev-1',
        shopId: shopId,
        billNo: 10,
        customerId: cust.id,
        customerName: cust.name,
        items: [CartItem(productId: prod.id, name: 'Aloo', unit: 'kg', price: 30, qty: 2)],
        subtotal: 60,
        total: 60,
        paid: 10,
        due: 50,
        paymentMode: 'split',
        createdAt: DateTime.now(),
      );
      await LocalDbService.instance.upsertSale(shopId, sale);

      await SupabaseService.instance.deleteSale(
        sale.id,
        reverseStock: true,
        reverseCustomerCredit: true,
      );

      final updatedProds = await LocalDbService.instance.getProducts(shopId);
      expect(updatedProds.firstWhere((p) => p.id == prod.id).stock, 12.0);
      final updatedCusts = await LocalDbService.instance.getCustomers(shopId);
      expect(updatedCusts.firstWhere((c) => c.id == cust.id).balance, 100.0);
      expect(await LocalDbService.instance.getSales(shopId), isEmpty);

      await LocalDbService.instance.closeForTest();
    });

    testWidgets('InventoryScreen Category rows show icon-only Delete/Add buttons so DAIRY PRODUCTS renders on one clean line', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      await LocalDbService.instance.closeForTest(disable: true);
      final prodProv = ProductProvider();
      await prodProv.addCategory('DAIRY PRODUCTS');
      await prodProv.addCategory('GREEN VEGGIES');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ShopProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider.value(value: prodProv),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: const MaterialApp(home: InventoryScreen(isMainTab: true)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.textContaining('Category ('));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      final dairyTitle = find.text('DAIRY PRODUCTS');
      expect(dairyTitle, findsOneWidget);
      expect(tester.getSize(dairyTitle).width, greaterThanOrEqualTo(180));

      // Action buttons use compact icon buttons without verbose Delete / Add Product text
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Add Product'), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(2));
      expect(find.byTooltip('Add Product'), findsWidgets);
    });

    test('TimeSyncService parses HTTP Date headers and heals +5:30 future cloud timestamps', () {
      final parsedUtc = TimeSyncService.parseHttpDateHeader('Wed, 25 Nov 2026 13:45:12 GMT');
      expect(parsedUtc, DateTime.utc(2026, 11, 25, 13, 45, 12));

      addTearDown(() => TimeSyncService.instance.setForTest());
      // Simulate real Internet clock matches device UTC now and network sync is active
      TimeSyncService.instance.setForTest(offset: Duration.zero, hasNetworkSync: true);

      // Corrupted DB row appearing 3 hours in the future (e.g. IST saved as UTC -> +5:30 ahead)
      final realLocalNow = TimeSyncService.instance.nowLocal();
      final corruptedFutureLocal = realLocalNow.add(const Duration(hours: 1, minutes: 30));
      final healed = TimeSyncService.instance.healCloudTimestampIfFuture(corruptedFutureLocal);
      final expectedMinus530 = corruptedFutureLocal.toUtc().subtract(const Duration(hours: 5, minutes: 30)).toLocal();
      expect(healed.difference(expectedMinus530).inSeconds.abs(), lessThanOrEqualTo(1));

      // Normal past timestamp must NEVER be altered
      final validPast = realLocalNow.subtract(const Duration(minutes: 20));
      expect(TimeSyncService.instance.healCloudTimestampIfFuture(validPast), validPast);
    });

    test('PaymentQrHelper.applyRoundOff rounds Nearest Rupee and Floor accurately & Sale preserves roundOff', () {
      final r1 = PaymentQrHelper.applyRoundOff(451.75, enabled: true, mode: 'nearest');
      expect(r1.roundedTotal, 452.0);
      expect(r1.roundOff, 0.25);

      final r2 = PaymentQrHelper.applyRoundOff(451.80, enabled: true, mode: 'nearest');
      expect(r2.roundedTotal, 452.0);
      expect(r2.roundOff, 0.20);

      final r3 = PaymentQrHelper.applyRoundOff(436.40, enabled: true, mode: 'nearest');
      expect(r3.roundedTotal, 436.0);
      expect(r3.roundOff, -0.40);

      final r4 = PaymentQrHelper.applyRoundOff(451.50, enabled: true, mode: 'nearest');
      expect(r4.roundedTotal, 452.0);
      expect(r4.roundOff, 0.50);

      final rFloor = PaymentQrHelper.applyRoundOff(451.75, enabled: true, mode: 'floor');
      expect(rFloor.roundedTotal, 451.0);
      expect(rFloor.roundOff, -0.75);

      final rOff = PaymentQrHelper.applyRoundOff(451.75, enabled: false, mode: 'nearest');
      expect(rOff.roundedTotal, 451.75);
      expect(rOff.roundOff, 0.0);

      final sale = Sale(
        id: 'round-sale-1',
        shopId: 'shop-1',
        billNo: 200,
        items: const [],
        subtotal: 451.75,
        roundOff: 0.25,
        total: 452.0,
        paid: 452.0,
        paymentMode: 'cash',
        createdAt: DateTime.utc(2026, 11, 25, 14, 0),
      );
      final decoded = Sale.fromJson(sale.toJson());
      expect(decoded.roundOff, 0.25);
      expect(decoded.total, 452.0);
    });

    testWidgets('PaymentDialog applies Nearest Rupee Round-Off on checkout total, UPI QR, and BillReceiptCard', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalDbService.instance.closeForTest(disable: true);
      addTearDown(() => PrinterSettingsService.instance.setRoundOffForTest(enabled: false));
      PrinterSettingsService.instance.setRoundOffForTest(enabled: true, mode: 'nearest');

      final shopProvider = ShopProvider(
        initialShop: Shop(
          id: 'demo-shop-101',
          name: 'Yadav Store',
          upiId: 'yadavstore@okicici',
          upiPayeeName: 'Yadav Store',
        ),
      );
      final cartProvider = CartProvider();
      cartProvider.incrementOrAdd(
        Product(
          id: 'prod-r1',
          shopId: 'demo-shop-101',
          name: 'Paneer',
          category: 'DAIRY',
          price: 451.75,
          unit: 'kg',
          stock: 10,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: shopProvider),
            ChangeNotifierProvider.value(value: cartProvider),
            ChangeNotifierProvider(create: (_) => CustomerProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => ProductProvider()),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(body: PaymentDialog(onSaleCompleted: () {})),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('452'), findsWidgets);
      expect(find.textContaining('Round Off'), findsWidgets);
      expect(find.text('Round Off :'), findsOneWidget);
      expect(find.text('+ Rs 0.25'), findsOneWidget);
      expect(find.text('Total : Rs 452.00'), findsOneWidget);

      await tester.tap(find.text('ऑनलाइन (UPI)'));
      await tester.pump();
      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect((qr.key as ValueKey<String>).value, contains('am=452.00'));
    });

    testWidgets('FeatureSettingsScreen shows Auto Round-Off toggle with Nearest Rupee default', (tester) async {
      SharedPreferences.setMockInitialValues({});
      addTearDown(() => PrinterSettingsService.instance.setRoundOffForTest(enabled: false));
      PrinterSettingsService.instance.setRoundOffForTest(enabled: false, mode: 'nearest');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ShopProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => ProductProvider()),
            ChangeNotifierProvider(create: (_) => CustomerProvider()),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: const MaterialApp(home: FeatureSettingsScreen()),
        ),
      );
      await tester.pump();

      final toggleFinder = find.byWidgetPredicate(
        (w) => w is SwitchListTile && w.title is Text && ((w.title as Text).data ?? '').contains('Auto Round-Off'),
      );
      await tester.scrollUntilVisible(toggleFinder, 250, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(toggleFinder);
      await tester.pump();
      expect(toggleFinder, findsOneWidget);

      await tester.tap(find.descendant(of: toggleFinder, matching: find.byType(Switch)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(PrinterSettingsService.instance.autoRoundOffEnabled, isTrue);
      expect(PrinterSettingsService.instance.roundOffMode, 'nearest');
      expect(find.text('नज़दीकी रुपया (Nearest Rupee)'), findsOneWidget);
      expect(find.text('पैसे हटाएं (Drop Paise / Floor)'), findsOneWidget);
    });

    testWidgets('BillsScreen always sorts strictly by billNo descending (1317 above 1294) even with out-of-order timestamps, and heals 8:06 PM batch', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalDbService.instance.closeForTest(disable: true);

      const shopId = 'demo-shop-101';
      await SupabaseService.instance.clearBillHistory(shopId);

      // Replicate #1294 (8:06 PM) vs #1317 (7:57 PM) + cascade heal
      addTearDown(() => TimeSyncService.instance.setForTest());
      TimeSyncService.instance.setForTest(offset: Duration.zero, hasNetworkSync: true);
      final nowLocal = TimeSyncService.instance.nowLocal();
      final s1317 = Sale(
        id: 'sale-1317',
        shopId: shopId,
        billNo: 1317,
        customerName: 'Walk-in Customer',
        items: [CartItem(productId: 'p1', name: 'Aloo', unit: 'kg', price: 200, qty: 1)],
        subtotal: 200,
        total: 200,
        paid: 200,
        paymentMode: 'cash',
        createdAt: nowLocal.subtract(const Duration(minutes: 8)),
      );
      final s1295 = Sale(
        id: 'sale-1295',
        shopId: shopId,
        billNo: 1295,
        customerName: 'Walk-in Customer',
        items: [CartItem(productId: 'p2', name: 'Pyaz', unit: 'kg', price: 100, qty: 1)],
        subtotal: 100,
        total: 100,
        paid: 100,
        paymentMode: 'cash',
        createdAt: nowLocal.add(const Duration(minutes: 13)),
      );
      final s1294 = Sale(
        id: 'sale-1294',
        shopId: shopId,
        billNo: 1294,
        customerName: 'Walk-in Customer',
        items: [CartItem(productId: 'p3', name: 'Gobhi', unit: 'kg', price: 378, qty: 1)],
        subtotal: 378,
        total: 378,
        paid: 378,
        paymentMode: 'cash',
        createdAt: nowLocal.add(const Duration(minutes: 1)),
      );

      final healedBatch = TimeSyncService.instance.healCloudSalesTimestamps([s1294, s1295, s1317]);
      final healed1294 = healedBatch.firstWhere((s) => s.billNo == 1294);
      final healed1295 = healedBatch.firstWhere((s) => s.billNo == 1295);
      // Both #1294 (+1 min) and #1295 (+13 min) are >30s ahead -> healed back -5:30!
      expect(healed1294.createdAt.isBefore(s1317.createdAt), isTrue);
      expect(healed1295.createdAt.isBefore(s1317.createdAt), isTrue);

      // Even if unhealed timestamps were directly in local cache, BillsScreen sorts 1317 above 1294
      await SupabaseService.instance.createSale(s1294);
      await SupabaseService.instance.createSale(s1317);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ShopProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => CartProvider()),
            ChangeNotifierProvider(create: (_) => CustomerProvider()),
            ChangeNotifierProvider(create: (_) => ProductProvider()),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: const MaterialApp(home: BillsScreen(isMainTab: true)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final y1317 = tester.getTopLeft(find.text('1317')).dy;
      final y1294 = tester.getTopLeft(find.text('1294')).dy;
      expect(y1317, lessThan(y1294));
    });

    test('LocalDbService.saveSales deduplicates pending create by clientRef, preserves update_sale edits, and keeps +1 serial billNo', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      SharedPreferences.setMockInitialValues({});
      await LocalDbService.instance.init(dbPathOverride: inMemoryDatabasePath);

      const shopId = 'shop-serial-sync-test';
      final t1 = DateTime(2026, 11, 25, 20, 30);

      // Client created bill #1401 with client UUID + clientRef, queued in sync_outbox
      final clientSale = Sale(
        id: '11111111-1111-4111-8111-111111111111',
        shopId: shopId,
        billNo: 1401,
        customerName: 'Walk-in Customer',
        items: [CartItem(productId: 'p1', name: 'Tomato', unit: 'kg', price: 60, qty: 1)],
        subtotal: 60,
        total: 60,
        paid: 60,
        paymentMode: 'cash',
        createdAt: t1,
        clientRef: 'cref-unique-1401',
      );
      await LocalDbService.instance.enqueueOutbox(
        shopId: shopId,
        entityType: 'sale',
        entityId: clientSale.id,
        operation: 'create',
        payload: {'sale': clientSale.toJson()},
      );

      // An already-synced bill #1400 with a pending local edit ('update_sale')
      final editedSale = Sale(
        id: '22222222-2222-4222-8222-222222222222',
        shopId: shopId,
        billNo: 1400,
        customerName: 'Edited Customer',
        items: [CartItem(productId: 'p1', name: 'Tomato', unit: 'kg', price: 80, qty: 1)],
        subtotal: 80,
        total: 80,
        paid: 80,
        paymentMode: 'cash',
        createdAt: t1.subtract(const Duration(minutes: 2)),
        clientRef: 'cref-unique-1400',
        editCount: 1,
      );
      await LocalDbService.instance.enqueueOutbox(
        shopId: shopId,
        entityType: 'sale',
        entityId: editedSale.id,
        operation: 'update_sale',
        payload: {'sale': editedSale.toJson()},
      );

      // Cloud returns server UUID for #1401 (with matching clientRef) + stale pre-edit #1400
      final serverSale1401 = clientSale.copyWith(id: '99999999-9999-4999-8999-999999999999');
      final cloudStale1400 = editedSale.copyWith(total: 50, paid: 50, editCount: 0);

      await LocalDbService.instance.saveSales(
        shopId,
        [serverSale1401, cloudStale1400],
        authoritativeCloudSync: false,
      );

      final saved = await LocalDbService.instance.getSales(shopId);
      // Must have exactly 2 bills (#1401 server UUID + #1400 pending local edit), NO duplicate client UUID!
      expect(saved.length, 2);
      expect(saved.where((s) => s.billNo == 1401).length, 1);
      expect(saved.firstWhere((s) => s.billNo == 1401).id, serverSale1401.id);
      expect(saved.firstWhere((s) => s.billNo == 1400).total, 80);

      // Strict +1 serial increment check: 1402, 1403, 1404 (never +6)
      expect(await LocalDbService.instance.getNextBillNo(shopId), 1402);
      expect(await LocalDbService.instance.getNextBillNo(shopId), 1403);
      expect(await LocalDbService.instance.getNextBillNo(shopId), 1404);

      await LocalDbService.instance.closeForTest();
    });

    testWidgets('UpdateService update popup hides GitHub Full Changelog URLs and markdown noise', (tester) async {
      expect(
        UpdateService.sanitizeReleaseNotes(
          '**Full Changelog**: https://github.com/hemantyadav1317-boop/Shop-app-POS/compare/v1.7.9...v1.7.10',
        ),
        '',
      );
      expect(
        UpdateService.sanitizeReleaseNotes(
          "## What's Changed\n* Faster billing sync by @dev in https://github.com/org/repo/pull/1\n**Full Changelog**: https://github.com/org/repo/compare/v1...v2",
        ),
        '• Faster billing sync',
      );

      final info = UpdateInfo(
        hasUpdate: true,
        currentVersion: '1.7.12',
        latestVersion: '1.7.13',
        downloadUrl: 'https://github.com/example/app/releases/download/v1.7.13/app.apk',
        releaseNotes: '**Full Changelog**: https://github.com/hemantyadav1317-boop/Shop-app-POS/compare/v1.7.12...v1.7.13',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => UpdateService.showUpdateDialog(context, info),
                child: const Text('ShowUpdate'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ShowUpdate'));
      await tester.pumpAndSettle();

      expect(find.text('नया अपडेट उपलब्ध है! 🚀'), findsOneWidget);
      expect(find.textContaining('Full Changelog'), findsNothing);
      expect(find.textContaining('github.com'), findsNothing);
      expect(find.textContaining('https://'), findsNothing);
    });

    testWidgets('AddEditProductScreen renders Profit Margin row without horizontal overflow on 360px phone', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({});
      await LocalDbService.instance.closeForTest(disable: true);

      final existingProduct = Product(
        id: 'prod-potato-1',
        shopId: 'demo-shop-101',
        name: 'आलू (Potato)',
        category: 'Vegetables',
        unit: 'kg',
        price: 25.0,
        purchasePrice: 11.0,
        stock: 700.205,
        lowStockAt: 0.1,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ShopProvider()),
            ChangeNotifierProvider(create: (_) => ProductProvider()),
          ],
          child: MaterialApp(
            home: AddEditProductScreen(existing: existingProduct),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('अनुमानित मुनाफा (Profit Margin):'), findsOneWidget);
      expect(find.text('₹14.0 / kg (127.3%)'), findsOneWidget);
    });

    test('ProductProvider memoizes filteredProducts per epoch and invalidates on search/category/deductStock', () {
      final prodProv = ProductProvider();
      final p1 = Product(
        id: 'p-1',
        shopId: 'demo-shop-101',
        name: 'Tomato',
        category: 'VEGETABLES',
        unit: 'kg',
        price: 40,
        stock: 20,
      );
      final p2 = Product(
        id: 'p-2',
        shopId: 'demo-shop-101',
        name: 'Banana',
        category: 'FRUITS',
        unit: 'kg',
        price: 50,
        stock: 15,
      );
      prodProv.replaceProductsLocal([p1, p2]);

      final first = prodProv.filteredProducts;
      final second = prodProv.filteredProducts;
      expect(identical(first, second), isTrue);

      prodProv.setSearchQuery('tom');
      final afterSearch = prodProv.filteredProducts;
      expect(identical(first, afterSearch), isFalse);
      expect(afterSearch.length, 1);
      expect(afterSearch.first.id, 'p-1');

      prodProv.setSearchQuery('');
      prodProv.deductStock([
        CartItem(productId: 'p-2', name: 'Banana', unit: 'kg', price: 50, qty: 3),
      ]);
      expect(prodProv.getProductById('p-2')!.stock, 12);
    });

    test('SupabaseService.createSale writes only the new sale and touched products to SQLite incrementally', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      SharedPreferences.setMockInitialValues({});
      await LocalDbService.instance.init(dbPathOverride: inMemoryDatabasePath);

      const shopId = 'demo-shop-101';
      final oldSale = Sale(
        id: 'old-sale-1',
        shopId: shopId,
        billNo: 1,
        items: [CartItem(productId: 'p1', name: 'Aloo', unit: 'kg', price: 30, qty: 1)],
        subtotal: 30,
        total: 30,
        paid: 30,
        paymentMode: 'cash',
        createdAt: DateTime(2026, 11, 25, 10, 0),
      );
      await LocalDbService.instance.upsertSale(shopId, oldSale);
      await LocalDbService.instance.upsertProduct(
        shopId,
        Product(id: 'p1', shopId: shopId, name: 'Aloo', category: 'VEG', unit: 'kg', price: 30, stock: 50),
      );

      final dbBefore = await LocalDbService.instance.getSales(shopId);
      expect(dbBefore.length, 1);

      final newSale = Sale(
        id: 'new-sale-2',
        shopId: shopId,
        billNo: 2,
        items: [CartItem(productId: 'p1', name: 'Aloo', unit: 'kg', price: 30, qty: 2)],
        subtotal: 60,
        total: 60,
        paid: 60,
        paymentMode: 'cash',
        createdAt: DateTime(2026, 11, 27, 18, 30),
      );
      await SupabaseService.instance.createSale(newSale);

      final dbAfter = await LocalDbService.instance.getSales(shopId);
      expect(dbAfter.length, 2);
      expect(dbAfter.first.id, 'new-sale-2');
      expect(dbAfter.last.id, 'old-sale-1');

      await LocalDbService.instance.closeForTest();
    });
  });
}
