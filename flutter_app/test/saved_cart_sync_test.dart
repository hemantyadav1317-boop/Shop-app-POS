import 'package:flutter_test/flutter_test.dart';
import 'package:shop_pos/data/models/cart_item.dart';
import 'package:shop_pos/data/models/customer.dart';
import 'package:shop_pos/providers/cart_provider.dart';

void main() {
  group('📦 SavedCart Serialization & Persistence Tests', () {
    test('SavedCart serializes and deserializes items, customer, and discount correctly', () {
      final customer = Customer(
        id: 'cust_999',
        shopId: 'shop_123',
        name: 'रमेश कुमार',
        phone: '9876543210',
        createdAt: DateTime.now(),
      );

      final items = [
        CartItem(productId: 'prod_1', name: 'आलू', unit: 'kg', price: 25.0, qty: 2.0),
        CartItem(productId: 'prod_2', name: 'टमाटर', unit: 'kg', price: 40.0, qty: 1.5),
      ];

      final saved = SavedCart(
        id: 'order_uuid_123',
        time: '07:30 PM',
        customer: customer,
        items: items,
        discount: 20.0,
        shopId: 'shop_123',
        label: 'Held Order',
      );

      expect(saved.subtotal, 25.0 * 2.0 + 40.0 * 1.5); // 50 + 60 = 110
      expect(saved.total, 110.0 - 20.0); // 90

      final json = saved.toJson();
      expect(json['id'], 'order_uuid_123');
      expect(json['discount'], 20.0);
      expect(json['shop_id'], 'shop_123');

      // Deserialize
      final restored = SavedCart.fromJson(json);
      expect(restored.id, 'order_uuid_123');
      expect(restored.discount, 20.0);
      expect(restored.customer?.name, 'रमेश कुमार');
      expect(restored.customer?.phone, '9876543210');
      expect(restored.items.length, 2);
      expect(restored.items[0].name, 'आलू');
      expect(restored.items[1].name, 'टमाटर');
      expect(restored.total, 90.0);
    });

    test('SavedCart handles Supabase raw rows with lines JSON and top-level customer fields', () {
      final supabaseRow = {
        'id': 'supabase_order_uuid_456',
        'shop_id': 'shop_123',
        'customer_id': 'cust_777',
        'customer_name': 'सुरेश जी',
        'customer_phone': '9123456780',
        'discount': 15.0,
        'label': 'Held Order',
        'lines': [
          {'product_id': 'prod_3', 'name': 'हरी मिर्च', 'unit': 'kg', 'price': 80.0, 'qty': 0.25},
        ],
        'created_at': '2026-11-05T14:00:00.000Z',
      };

      final restored = SavedCart.fromJson(supabaseRow);
      expect(restored.id, 'supabase_order_uuid_456');
      expect(restored.customer?.name, 'सुरेश जी');
      expect(restored.customer?.phone, '9123456780');
      expect(restored.discount, 15.0);
      expect(restored.items.length, 1);
      expect(restored.items[0].name, 'हरी मिर्च');
      expect(restored.subtotal, 20.0); // 80 * 0.25
      expect(restored.total, 5.0); // 20 - 15
    });
  });
}

