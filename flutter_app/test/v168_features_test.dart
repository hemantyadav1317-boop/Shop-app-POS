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
        find.text('BillZo POS v1.7.3'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('BillZo POS v1.7.3'), findsOneWidget);
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
  });
}
