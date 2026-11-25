import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_pos/core/constants/aliases.dart';
import 'package:shop_pos/data/models/cart_item.dart';
import 'package:shop_pos/data/models/product.dart';
import 'package:shop_pos/providers/auth_provider.dart';
import 'package:shop_pos/providers/locale_provider.dart';
import 'package:shop_pos/providers/product_provider.dart';
import 'package:shop_pos/providers/shop_provider.dart';
import 'package:shop_pos/screens/inventory/mandi_order_screen.dart';
import 'package:shop_pos/screens/reports/daily_profit_screen.dart';
import 'package:shop_pos/screens/widgets/app_drawer.dart';
import 'package:shop_pos/core/services/update_service.dart';

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

  group('🌟 v1.7.0 Daily Profit, Mandi Order & App Drawer Tests', () {
    testWidgets('1. DailyProfitScreen renders date chips and profit cards', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const DailyProfitScreen()));
      await tester.pumpAndSettle();

      expect(find.text('आज की कमाई'), findsOneWidget);
      expect(find.text('आज'), findsOneWidget);
      expect(find.text('कल'), findsOneWidget);
      expect(find.text('7 दिन'), findsOneWidget);
      expect(find.text('शुद्ध मुनाफा'), findsOneWidget);
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

      expect(find.text('मुनाफा रिपोर्ट'), findsOneWidget);
      expect(find.text('सप्लायर ऑर्डर'), findsOneWidget);
      expect(find.text('रोकड़ बही'), findsOneWidget);
      expect(find.text('दुकान सेटिंग्स'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('BillZo POS v${UpdateService.currentVersion}'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('BillZo POS v${UpdateService.currentVersion}'), findsOneWidget);
    });

    test('4. Product and CartItem dynamic multi-language localization', () {
      final p1 = Product(
        id: '1',
        shopId: 's1',
        name: 'स्ट्रॉबेरी (Strawberry)',
        nameEn: 'Strawberry',
        nameHi: 'स्ट्रॉबेरी',
        category: 'FRUITS',
        unit: 'pc',
        price: 80,
      );

      expect(p1.localizedName('hi'), 'स्ट्रॉबेरी');
      expect(p1.localizedName('en'), 'Strawberry');
      expect(p1.localizedCategory('hi'), 'फल');
      expect(p1.localizedCategory('en'), 'Fruits');

      // Legacy fallback parsing without explicit nameEn/nameHi
      final p2 = Product(
        id: '2',
        shopId: 's1',
        name: 'पालक (Spinach)',
        category: 'VEGETABLES',
        unit: 'kg',
        price: 40,
      );
      expect(p2.localizedName('hi'), 'पालक');
      expect(p2.localizedName('en'), 'Spinach');
      expect(p2.localizedCategory('hi'), 'सब्जियां');
      expect(p2.localizedCategory('en'), 'Vegetables');

      // Reverse order: English (Hindi)
      final p3 = Product(
        id: '3',
        shopId: 's1',
        name: 'Potato (आलू)',
        category: 'VEGETABLES',
        unit: 'kg',
        price: 30,
      );
      expect(p3.localizedName('hi'), 'आलू');
      expect(p3.localizedName('en'), 'Potato');
      // Regional languages for Potato
      expect(p3.localizedName('mr'), 'बटाटा');
      expect(p3.localizedName('gu'), 'બટાકા');
      expect(p3.localizedName('bn'), 'আলু');
      expect(p3.localizedName('ta'), 'உருளைக்கிழங்கு');
      expect(p3.localizedName('te'), 'బంగాళాదుంప');
      expect(p3.localizedName('kn'), 'ಆಲೂಗಡ್ಡೆ');
      expect(p3.localizedName('pa'), 'ਆਲੂ');

      // Category across all 9 languages
      expect(Product.localizeCategory('FRUITS', 'en'), 'Fruits');
      expect(Product.localizeCategory('FRUITS', 'hi'), 'फल');
      expect(Product.localizeCategory('FRUITS', 'mr'), 'फळे');
      expect(Product.localizeCategory('FRUITS', 'gu'), 'ફળો');
      expect(Product.localizeCategory('FRUITS', 'bn'), 'ফলমূল');
      expect(Product.localizeCategory('FRUITS', 'pa'), 'ਫਲ');
      expect(Product.localizeCategory('FRUITS', 'ta'), 'பழங்கள்');
      expect(Product.localizeCategory('FRUITS', 'te'), 'పండ్లు');
      expect(Product.localizeCategory('FRUITS', 'kn'), 'ಹಣ್ಣುಗಳು');

      // CartItem localization
      final item = CartItem(
        productId: '1',
        name: 'स्ट्रॉबेरी (Strawberry)',
        nameEn: 'Strawberry',
        nameHi: 'स्ट्रॉबेरी',
        unit: 'pc',
        price: 80,
        qty: 2,
      );
      expect(item.localizedName('hi'), 'स्ट्रॉबेरी');
      expect(item.localizedName('en'), 'Strawberry');
      expect(item.localizedName('gu'), 'સ્ટ્રોબેરી');
      expect(item.localizedName('bn'), 'স্ট্রবেরি');
    });

    test('5. ProductAliases.matches works seamlessly across languages', () {
      expect(ProductAliases.matches('स्ट्रॉबेरी (Strawberry)', 'FRUITS', null, 'strawberry', nameEn: 'Strawberry', nameHi: 'स्ट्रॉबेरी'), isTrue);
      expect(ProductAliases.matches('स्ट्रॉबेरी (Strawberry)', 'FRUITS', null, 'स्ट्रॉबेरी', nameEn: 'Strawberry', nameHi: 'स्ट्रॉबेरी'), isTrue);
      expect(ProductAliases.matches('आलू (Potato)', 'VEGETABLES', null, 'aloo'), isTrue);
      expect(ProductAliases.matches('आलू (Potato)', 'VEGETABLES', null, 'potato'), isTrue);
      expect(ProductAliases.matches('आलू (Potato)', 'VEGETABLES', null, 'आलू'), isTrue);
    });

    testWidgets('6. MandiOrderScreen header title does not overlap + button on narrow width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(340, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final localeProvider = LocaleProvider();
      await localeProvider.setLocale('en');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ShopProvider()),
            ChangeNotifierProvider(create: (_) => ProductProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider.value(value: localeProvider),
          ],
          child: const MaterialApp(
            home: MandiOrderScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final titleRect = tester.getRect(find.text('Mandi / Supplier Order'));
      final addBtnRect = tester.getRect(find.byIcon(Icons.add_circle_outline_rounded));
      expect(titleRect.right, lessThanOrEqualTo(addBtnRect.left));
    });

    testWidgets('7. DailyProfitScreen SafeArea protects content from bottom navigation bar inset', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ShopProvider()),
            ChangeNotifierProvider(create: (_) => ProductProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(360, 720),
                padding: EdgeInsets.only(bottom: 48),
              ),
              child: DailyProfitScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final bodySafeAreaFinder = find.ancestor(
        of: find.byType(ListView),
        matching: find.byType(SafeArea),
      );
      expect(bodySafeAreaFinder, findsOneWidget);
      final safeArea = tester.widget<SafeArea>(bodySafeAreaFinder);
      expect(safeArea.bottom, isTrue);
      final listViewRect = tester.getRect(find.byType(ListView));
      // Bottom of ListView must stop above the 48px system navigation bar inset (720 - 48 = 672)
      expect(listViewRect.bottom, lessThanOrEqualTo(672.0));
    });
  });
}
