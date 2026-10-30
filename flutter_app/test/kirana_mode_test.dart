import 'package:flutter_test/flutter_test.dart';
import 'package:shop_pos/core/services/fmcg_catalog_service.dart';
import 'package:shop_pos/core/constants/aliases.dart';
import 'package:shop_pos/data/models/shop.dart';
import 'package:shop_pos/data/models/product.dart';
import 'package:shop_pos/providers/cart_provider.dart';

void main() {
  group('🏪 Kirana & FMCG Catalog 2026 Tests', () {
    test('FmcgCatalogService has 2026 updated Maggi price of ₹15', () {
      final maggi = FmcgCatalogService.instance.findByBarcode('8901058852448');
      expect(maggi, isNotNull);
      expect(maggi!.name, contains('Maggi 2-Minute Masala Noodles 70g'));
      expect(maggi.mrp, equals(15.0));
      expect(maggi.defaultCostPrice, lessThan(15.0));
      expect(maggi.marginAmount, greaterThan(0));
    });

    test('FmcgCatalogService has Tata Salt, Parle-G, Amul Butter with correct 2026 MRP', () {
      final tataSalt = FmcgCatalogService.instance.findByBarcode('8901030381014');
      expect(tataSalt, isNotNull);
      expect(tataSalt!.mrp, equals(28.0));

      final parleG5 = FmcgCatalogService.instance.findByBarcode('8901719101018');
      expect(parleG5, isNotNull);
      expect(parleG5!.mrp, equals(5.0));

      final amulButter = FmcgCatalogService.instance.findByBarcode('8901262010052');
      expect(amulButter, isNotNull);
      expect(amulButter!.mrp, equals(60.0));
    });

    test('FmcgCatalogService search handles Hindi and English keywords', () {
      final hindiSearch = FmcgCatalogService.instance.search('मैगी');
      expect(hindiSearch.isNotEmpty, isTrue);
      expect(hindiSearch.first.name, contains('Maggi'));

      final brandSearch = FmcgCatalogService.instance.search('haldiram');
      expect(brandSearch.isNotEmpty, isTrue);

      final soapSearch = FmcgCatalogService.instance.search('dettol');
      expect(soapSearch.isNotEmpty, isTrue);
    });
  });

  group('🚪 3-Door Store Mode Tests', () {
    test('Shop defaults to vegetable mode for existing users', () {
      final shop = Shop(id: 'shop-1', name: 'Sabzi Mandi');
      expect(shop.storeType, equals('vegetable'));
    });

    test('Shop serializes and deserializes storeType correctly', () {
      final kiranaShop = Shop(
        id: 'shop-2',
        name: 'Gupta Kirana Store',
        storeType: 'kirana',
      );
      final json = kiranaShop.toJson();
      expect(json['store_type'], equals('kirana'));

      final loaded = Shop.fromJson(json);
      expect(loaded.storeType, equals('kirana'));

      final mixShop = kiranaShop.copyWith(storeType: 'mix');
      expect(mixShop.storeType, equals('mix'));
    });
  });

  group('🛒 Cart Fast Increment & Aliases Tests', () {
    test('CartProvider.incrementOrAdd adds new item or increments existing', () {
      final cart = CartProvider();
      final prod = Product(
        id: 'p-101',
        shopId: 'shop-1',
        name: 'Maggi Noodles',
        category: 'KIRANA',
        unit: 'pkt',
        price: 15.0,
      );

      // First scan: adds 1
      cart.incrementOrAdd(prod);
      expect(cart.itemCount, equals(1));
      expect(cart.totalQty, equals(1.0));
      expect(cart.total, equals(15.0));

      // Second scan (same barcode/product): increments to 2
      cart.incrementOrAdd(prod);
      expect(cart.itemCount, equals(1));
      expect(cart.totalQty, equals(2.0));
      expect(cart.total, equals(30.0));
    });

    test('ProductAliases matches Kirana keywords in Hindi and English', () {
      expect(ProductAliases.matches('Maggi Masala Noodles', 'KIRANA', '8901058852448', 'मैगी'), isTrue);
      expect(ProductAliases.matches('Parle-G Biscuit', 'SNACKS', '8901719101018', 'बिस्कुट'), isTrue);
      expect(ProductAliases.matches('Fortune Sunflower Oil', 'OIL', '8906007281012', 'तेल'), isTrue);
      expect(ProductAliases.matches('Tata Salt', 'STAPLES', '8901030381014', 'नमक'), isTrue);
    });
  });
}
