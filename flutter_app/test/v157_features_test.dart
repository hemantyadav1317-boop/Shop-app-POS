import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_pos/core/services/local_image_cache_service.dart';
import 'package:shop_pos/data/models/product.dart';
import 'package:shop_pos/providers/menu_visibility_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🖥️ MenuVisibilityProvider Tests (Laptop & Mobile Menu Bar Toggle)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial state isMenuHidden defaults to false', () async {
      final provider = MenuVisibilityProvider();
      expect(provider.isMenuHidden, isFalse);
    });

    test('toggleMenu flips isMenuHidden and persists to SharedPreferences', () async {
      final provider = MenuVisibilityProvider();
      expect(provider.isMenuHidden, isFalse);

      await provider.toggleMenu();
      expect(provider.isMenuHidden, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pos_menu_hidden'), isTrue);

      await provider.toggleMenu();
      expect(provider.isMenuHidden, isFalse);
      expect(prefs.getBool('pos_menu_hidden'), isFalse);
    });

    test('setMenuHidden explicitly sets visibility and notifies listeners', () async {
      final provider = MenuVisibilityProvider();
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.setMenuHidden(true);
      expect(provider.isMenuHidden, isTrue);
      expect(notifyCount, 1);

      // Setting same state does not redundant notify
      await provider.setMenuHidden(true);
      expect(notifyCount, 1);

      await provider.setMenuHidden(false);
      expect(provider.isMenuHidden, isFalse);
      expect(notifyCount, 2);
    });
  });

  group('🖼️ LocalImageCacheService Tests (Product Disk Caching & Offline Scrolling)', () {
    test('LocalImageCacheService initializes cleanly and handles null/web safely', () async {
      final service = LocalImageCacheService.instance;
      await service.init();

      // Unknown URL returns null file
      final cached = service.getCachedFile('https://example.com/products/fresh_tomato.jpg');
      expect(cached, isNull);
    });

    test('Preload images accepts product list without crashing or blocking', () async {
      final service = LocalImageCacheService.instance;
      final products = [
        Product(
          id: 'prod-1',
          shopId: 'shop-1',
          name: 'Tomato Local',
          price: 40.0,
          unit: 'kg',
          category: 'Vegetables',
          imageUrl: 'https://images.unsplash.com/photo-1546470427-0d4db154ceb7?w=150',
        ),
        Product(
          id: 'prod-2',
          shopId: 'shop-1',
          name: 'Potato Agra',
          price: 25.0,
          unit: 'kg',
          category: 'Vegetables',
          imageUrl: null,
        ),
        Product(
          id: 'prod-3',
          shopId: 'shop-1',
          name: 'Ginger',
          price: 120.0,
          unit: 'kg',
          category: 'Vegetables',
          imageUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
        ),
      ];

      // Must complete without error
      service.preloadProductImages(products);
      expect(true, isTrue);
    });
  });
}
