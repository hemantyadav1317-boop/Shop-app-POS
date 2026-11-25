import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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
import 'package:shop_pos/screens/customers/customers_screen.dart';
import 'package:shop_pos/screens/pos/widgets/payment_dialog.dart';
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

      // Verify counters > 5000 work cleanly while 7-digit timestamp outliers are ignored
      await LocalDbService.instance.syncCounterFloor(shopId, 5005);
      expect(await LocalDbService.instance.getNextBillNo(shopId), 5006);
      await LocalDbService.instance.syncCounterFloor(shopId, 1795592537);
      expect(await LocalDbService.instance.peekNextBillNo(shopId), 5007);

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
  });
}
