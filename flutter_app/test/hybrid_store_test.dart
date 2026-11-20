import 'package:flutter_test/flutter_test.dart';
import 'package:shop_pos/data/models/shop.dart';

void main() {
  group('🏪 Hybrid Store & Barcode Dynamic Capability Tests', () {
    test('1. Pure Vegetable store hides barcode and keeps scale active', () {
      final vegShop = Shop(
        id: 'shop_veg_1',
        name: 'Yadav Veggie Store',
        storeType: 'vegetable',
        hybridModules: const [],
      );

      expect(vegShop.isVegetableMode, isTrue);
      expect(vegShop.hasVegetableOrProduce, isTrue);
      expect(vegShop.hasGroceryOrFmcg, isFalse);
      expect(vegShop.hasBarcodeSupport, isFalse, reason: 'Pure veggie shop must NOT show barcode');
      expect(vegShop.hasScaleSupport, isTrue, reason: 'Pure veggie shop must have scale enabled');
    });

    test('2. Pure Dairy store hides barcode', () {
      final dairyShop = Shop(
        id: 'shop_dairy_1',
        name: 'Sharma Dairy Parlour',
        storeType: 'dairy',
        hybridModules: const [],
      );

      expect(dairyShop.hasDairy, isTrue);
      expect(dairyShop.hasGroceryOrFmcg, isFalse);
      expect(dairyShop.hasBarcodeSupport, isFalse, reason: 'Pure dairy shop must NOT show barcode');
    });

    test('3. Pure Kirana / FMCG store enables barcode', () {
      final kiranaShop = Shop(
        id: 'shop_kirana_1',
        name: 'Gupta Kirana Store',
        storeType: 'kirana',
        hybridModules: const [],
      );

      expect(kiranaShop.isKiranaMode, isTrue);
      expect(kiranaShop.hasGroceryOrFmcg, isTrue);
      expect(kiranaShop.hasBarcodeSupport, isTrue, reason: 'Kirana shop must show barcode');
    });

    test('4. Hybrid Vegetable + Kirana auto-enables barcode AND scale', () {
      final hybridShop = Shop(
        id: 'shop_hybrid_1',
        name: 'Kisan Veg & Daily Mart',
        storeType: 'vegetable',
        hybridModules: const ['kirana'],
      );

      expect(hybridShop.hasVegetableOrProduce, isTrue);
      expect(hybridShop.hasGroceryOrFmcg, isTrue);
      expect(hybridShop.hasBarcodeSupport, isTrue, reason: 'Adding Kirana to Veggie must auto-enable barcode');
      expect(hybridShop.hasScaleSupport, isTrue, reason: 'Veggie base must retain scale support');
    });

    test('5. Hybrid Dairy + Kirana auto-enables barcode', () {
      final hybridDairy = Shop(
        id: 'shop_hybrid_dairy',
        name: 'Amul Dairy & General Store',
        storeType: 'dairy',
        hybridModules: const ['kirana'],
      );

      expect(hybridDairy.hasDairy, isTrue);
      expect(hybridDairy.hasGroceryOrFmcg, isTrue);
      expect(hybridDairy.hasBarcodeSupport, isTrue, reason: 'Adding Kirana to Dairy must auto-enable barcode');
    });

    test('6. Hybrid Vegetable + Dairy (without Kirana) keeps barcode hidden', () {
      final vegDairy = Shop(
        id: 'shop_veg_dairy',
        name: 'Fresh Veg & Milk Corner',
        storeType: 'vegetable',
        hybridModules: const ['dairy'],
      );

      expect(vegDairy.hasVegetableOrProduce, isTrue);
      expect(vegDairy.hasDairy, isTrue);
      expect(vegDairy.hasGroceryOrFmcg, isFalse);
      expect(vegDairy.hasBarcodeSupport, isFalse, reason: 'No Kirana means barcode remains hidden');
      expect(vegDairy.hasScaleSupport, isTrue);
    });

    test('7. JSON serialization & copyWith preserves hybridModules cleanly', () {
      final original = Shop(
        id: 'test_shop',
        name: 'Multi Store',
        storeType: 'vegetable',
        hybridModules: const ['kirana', 'dairy'],
      );

      final json = original.toJson();
      expect(json['hybrid_modules'], ['kirana', 'dairy']);

      final restored = Shop.fromJson(json);
      expect(restored.hybridModules, ['kirana', 'dairy']);
      expect(restored.hasBarcodeSupport, isTrue);
      expect(restored.hasScaleSupport, isTrue);
      expect(restored.hasDairy, isTrue);

      final modified = restored.copyWith(hybridModules: const ['dairy']);
      expect(modified.hasBarcodeSupport, isFalse);
      expect(modified.hasDairy, isTrue);
    });
  });
}
