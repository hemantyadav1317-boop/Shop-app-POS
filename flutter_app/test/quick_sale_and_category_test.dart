import 'package:flutter_test/flutter_test.dart';
import 'package:shop_pos/screens/inventory/inventory_screen.dart';
import 'package:shop_pos/data/models/cart_item.dart';
import 'package:shop_pos/data/models/shop.dart';

void main() {
  group('🏷️ Category Emoji Mapping Tests', () {
    test('Maps vegetable and sabji to 🥦', () {
      expect(InventoryScreen.getCategoryEmoji('सब्जी'), '🥦');
      expect(InventoryScreen.getCategoryEmoji('Fresh Vegetables'), '🥦');
      expect(InventoryScreen.getCategoryEmoji('हरी सब्जियां'), '🥦');
    });

    test('Maps fruit and phal to 🍎', () {
      expect(InventoryScreen.getCategoryEmoji('फल'), '🍎');
      expect(InventoryScreen.getCategoryEmoji('Seasonal Fruits'), '🍎');
    });

    test('Maps Kirana and snacks correctly', () {
      expect(InventoryScreen.getCategoryEmoji('किराना'), '🥫');
      expect(InventoryScreen.getCategoryEmoji('स्नैक्स'), '🍟');
      expect(InventoryScreen.getCategoryEmoji('डेयरी'), '🥛');
      expect(InventoryScreen.getCategoryEmoji('पर्सनल केयर'), '🧴');
      expect(InventoryScreen.getCategoryEmoji('Unknown Category'), '📦');
    });
  });

  group('🥬 Shop Mode Barcode Policy Tests', () {
    test('isKiranaMode is true only for kirana stores', () {
      final vegShop = Shop(id: '1', name: 'Veg Mandi', phone: '123', storeType: 'vegetable');
      expect(vegShop.isKiranaMode, isFalse);
      expect(vegShop.isVegetableMode, isTrue);

      final kiranaShop = Shop(id: '2', name: 'Kirana Store', phone: '456', storeType: 'kirana');
      expect(kiranaShop.isKiranaMode, isTrue);
      expect(kiranaShop.isVegetableMode, isFalse);
    });
  });

  group('⚡ Quick Sale Rate x Qty Math Tests', () {
    test('Calculates 30 Rs/kg x 0.600 kg = 18.00 accurately', () {
      const rate = 30.0;
      const qty = 0.6; // 600gm
      final total = rate * qty;
      expect(total, closeTo(18.0, 0.001));

      final item = CartItem(
        productId: 'quick_test_1',
        name: 'हरी मिर्च',
        unit: 'kg',
        price: rate,
        qty: qty,
      );
      expect(item.total, closeTo(18.0, 0.001));
    });

    test('Calculates 25 Rs/kg x 25 kg = 625.00 accurately', () {
      const rate = 25.0;
      const qty = 25.0;
      final total = rate * qty;
      expect(total, 625.0);

      final item = CartItem(
        productId: 'quick_test_2',
        name: 'आलू',
        unit: 'kg',
        price: rate,
        qty: qty,
      );
      expect(item.total, 625.0);
    });
  });
}
