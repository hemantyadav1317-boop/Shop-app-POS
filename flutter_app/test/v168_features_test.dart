import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_pos/data/models/product.dart';
import 'package:shop_pos/data/models/shop.dart';
import 'package:shop_pos/providers/auth_provider.dart';
import 'package:shop_pos/providers/locale_provider.dart';
import 'package:shop_pos/providers/product_provider.dart';
import 'package:shop_pos/providers/shop_provider.dart';
import 'package:shop_pos/screens/inventory/mandi_order_screen.dart';
import 'package:shop_pos/screens/reports/daily_profit_screen.dart';
import 'package:shop_pos/screens/widgets/app_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ShopProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          drawer: const AppDrawer(),
          body: child,
        ),
      ),
    );
  }

  group('🌟 v1.6.9 Daily Profit, Mandi Order & App Drawer Tests', () {
    testWidgets('1. DailyProfitScreen renders date chips and profit cards', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const DailyProfitScreen()));
      await tester.pumpAndSettle();

      expect(find.text('आज की कमाई (Net Profit)'), findsOneWidget);
      expect(find.text('आज (Today)'), findsOneWidget);
      expect(find.text('कल (Yesterday)'), findsOneWidget);
      expect(find.text('7 दिन (7 Days)'), findsOneWidget);
      expect(find.text('शुद्ध मुनाफा (NET PROFIT)'), findsOneWidget);
    });

    testWidgets('2. MandiOrderScreen initializes with order list structure', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const MandiOrderScreen()));
      await tester.pumpAndSettle();

      expect(find.text('मंडी / सप्लायर पर्ची'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
    });

    testWidgets('3. AppDrawer renders high-graphic header and all 3 business sections', (tester) async {
      final key = GlobalKey<ScaffoldState>();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ShopProvider()),
            ChangeNotifierProvider(create: (_) => ProductProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              key: key,
              drawer: const AppDrawer(),
              body: const Text('Home'),
            ),
          ),
        ),
      );

      key.currentState?.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('आज की कमाई व मुनाफा'), findsOneWidget);
      expect(find.text('मंडी / सप्लायर पर्ची'), findsOneWidget);
      expect(find.text('दुकान खर्च व गल्ला (Daybook)'), findsOneWidget);
      expect(find.text('पूरी दुकान सेटिंग्स'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('BillZo POS v1.6.9'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('BillZo POS v1.6.9'), findsOneWidget);
    });
  });
}
