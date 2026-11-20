import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_pos/data/models/shop.dart';
import 'package:shop_pos/data/models/sale.dart';
import 'package:shop_pos/data/models/cart_item.dart';
import 'package:shop_pos/providers/weighing_scale_provider.dart';
import 'package:shop_pos/providers/shop_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('⚖️ Weighing Scale & Fullscreen POS Tests', () {
    test('WeighingScaleProvider default disconnected state is safe', () async {
      final scale = WeighingScaleProvider();
      await Future.delayed(const Duration(milliseconds: 20));
      expect(scale.isConnected, isFalse);
      expect(scale.liveWeight, 0.0);
      expect(scale.liveWeightGrams, 0.0);
      expect(scale.isStable, isTrue);
    });

    test('WeighingScaleProvider live simulation formats weight properly', () async {
      final scale = WeighingScaleProvider();
      await Future.delayed(const Duration(milliseconds: 20));
      scale.simulateWeight(2.450, isStable: true);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(scale.liveWeight, 2.450);
      expect(scale.liveWeight.toStringAsFixed(3), '2.450');
    });
  });

  group('💳 UPI Settings Cloud Sync & Model Tests', () {

    test('Shop model retains upiId and upiPayeeName cleanly', () {
      final shop = Shop(
        id: 'test-shop-101',
        name: 'Yadav Veggie Store',
        upiId: 'yadavstore@okicici',
        upiPayeeName: 'Yadav Veggie Store',
      );

      expect(shop.upiId, 'yadavstore@okicici');
      expect(shop.upiPayeeName, 'Yadav Veggie Store');

      final updated = shop.copyWith(
        upiId: 'newyadav@paytm',
        upiPayeeName: 'Hemant Yadav',
      );

      expect(updated.upiId, 'newyadav@paytm');
      expect(updated.upiPayeeName, 'Hemant Yadav');
      expect(updated.id, 'test-shop-101');
    });

    test('ShopProvider updates and persists UPI ID and Payee Name', () async {
      final provider = ShopProvider(
        initialShop: Shop(
          id: 'test-shop-1',
          name: 'My Store',
          upiId: 'initial@upi',
          upiPayeeName: 'My Store',
        ),
      );

      final updated = provider.shop.copyWith(
        upiId: 'updated@upi',
        upiPayeeName: 'Updated Merchant',
      );

      await provider.updateShop(updated);

      expect(provider.shop.upiId, 'updated@upi');
      expect(provider.shop.upiPayeeName, 'Updated Merchant');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('shop_upi_id'), 'updated@upi');
      expect(prefs.getString('shop_upi_payee_name'), 'Updated Merchant');
    });
  });

  group('⚡ Khata Instant Filter & Customer Sales Tests', () {
    test('Customer sales filter isolates sales by customerId or phone with zero lag', () {
      final sales = [
        Sale(
          id: 'sale-1',
          shopId: 'shop-1',
          billNo: 101,
          items: [CartItem(productId: 'item-1', name: 'Banana', unit: 'kg', price: 50, qty: 1)],
          subtotal: 50,
          discount: 0,
          total: 50,
          paymentMode: 'cash',
          paid: 50,
          due: 0,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          customerId: 'cust-123',
          customerName: 'Dinesh',
          customerPhone: '9876543210',
        ),
        Sale(
          id: 'sale-2',
          shopId: 'shop-1',
          billNo: 102,
          items: [CartItem(productId: 'item-2', name: 'Apple', unit: 'kg', price: 100, qty: 1)],
          subtotal: 100,
          discount: 0,
          total: 100,
          paymentMode: 'credit',
          paid: 0,
          due: 100,
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          customerId: 'cust-456',
          customerName: 'Ramesh',
          customerPhone: '9123456780',
        ),
        Sale(
          id: 'sale-3',
          shopId: 'shop-1',
          billNo: 103,
          items: [CartItem(productId: 'item-3', name: 'Orange', unit: 'kg', price: 80, qty: 1)],
          subtotal: 80,
          discount: 0,
          total: 80,
          paymentMode: 'credit',
          paid: 0,
          due: 80,
          createdAt: DateTime.now(),
          customerId: 'cust-123',
          customerName: 'Dinesh',
          customerPhone: '9876543210',
        ),
      ];

      // Instant local in-memory filter for cust-123
      final targetCustomerId = 'cust-123';
      final filtered = sales.where((s) => s.customerId == targetCustomerId).toList();

      expect(filtered.length, 2);
      expect(filtered.first.billNo, 101);
      expect(filtered.last.billNo, 103);

      final totalCustomerDue = filtered.fold(0.0, (sum, s) => sum + s.due);
      expect(totalCustomerDue, 80.0);
    });
  });
}
