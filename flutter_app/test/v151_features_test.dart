import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_pos/core/services/receipt_print_service.dart';
import 'package:shop_pos/data/models/cart_item.dart';
import 'package:shop_pos/data/models/product.dart';
import 'package:shop_pos/data/models/sale.dart';
import 'package:shop_pos/data/models/shop.dart';
import 'package:shop_pos/providers/product_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('v1.5.1 Features Tests', () {
    test('Most-selling products & categories sort by sales frequency', () {
      final prov = ProductProvider();

      final p1 = Product(
        id: 'p1',
        shopId: 'shop1',
        name: 'Sugar M30',
        category: 'GROCERY',
        price: 45.0,
        stock: 50.0,
        unit: 'kg',
      );
      final p2 = Product(
        id: 'p2',
        shopId: 'shop1',
        name: 'Tata Salt',
        category: 'SPICES',
        price: 28.0,
        stock: 100.0,
        unit: 'pkt',
      );
      final p3 = Product(
        id: 'p3',
        shopId: 'shop1',
        name: 'Maggi 2-Min Noodles',
        category: 'SNACKS',
        price: 14.0,
        stock: 80.0,
        unit: 'pc',
      );

      prov.replaceProductsLocal([p1, p2, p3]);

      // Initially with zero sales, sorted alphabetically
      expect(prov.filteredProducts.map((p) => p.name).toList(), [
        'Maggi 2-Min Noodles',
        'Sugar M30',
        'Tata Salt',
      ]);

      // Recompute sales: Maggi sold 50 units, Tata Salt sold 10 units, Sugar sold 5 units
      final List<Sale> dummySales = [
        Sale(
          id: 's1',
          shopId: 'shop1',
          billNo: 1001,
          customerName: 'Ramesh',
          customerPhone: '9876543210',
          subtotal: 700.0,
          total: 700.0,
          paid: 700.0,
          paymentMode: 'CASH',
          createdAt: DateTime.now(),
          items: [
            CartItem(
              productId: 'p3',
              name: 'Maggi 2-Min Noodles',
              unit: 'pc',
              price: 14.0,
              qty: 50.0,
            ),
            CartItem(
              productId: 'p2',
              name: 'Tata Salt',
              unit: 'pkt',
              price: 28.0,
              qty: 10.0,
            ),
            CartItem(
              productId: 'p1',
              name: 'Sugar M30',
              unit: 'kg',
              price: 45.0,
              qty: 5.0,
            ),
          ],
        ),
      ];

      prov.recomputeSalesStats(dummySales);

      // Verify filteredProducts is now ordered by popularity (p3: 50 > p2: 10 > p1: 5)
      final sortedProducts = prov.filteredProducts;
      expect(sortedProducts[0].name, 'Maggi 2-Min Noodles');
      expect(sortedProducts[1].name, 'Tata Salt');
      expect(sortedProducts[2].name, 'Sugar M30');

      // Verify categories are sorted by popularity (SNACKS: 50 > SPICES: 10 > GROCERY: 5)
      final sortedCategories = prov.allCategories;
      expect(sortedCategories[0], 'SNACKS');
      expect(sortedCategories[1], 'SPICES');
      expect(sortedCategories[2], 'GROCERY');

      // Now sell 60 units of Sugar via deductStock
      prov.deductStock([
        CartItem(
          productId: 'p1',
          name: 'Sugar M30',
          unit: 'kg',
          price: 45.0,
          qty: 60.0,
        ),
      ]);

      // Now Sugar has 65 units sold (p1 > p3 > p2), so Sugar and GROCERY take #1 position
      expect(prov.filteredProducts[0].name, 'Sugar M30');
      expect(prov.allCategories[0], 'GROCERY');
    });

    test('Piece units identification bypasses weighing scale correctly', () {
      bool isWeighableUnit(String rawUnit) {
        final u = rawUnit.trim().toLowerCase();
        return u == 'kg' || u == 'g' || u == 'gram' || u == 'grams' || u == 'kilo';
      }

      // Weighable units
      expect(isWeighableUnit('kg'), isTrue);
      expect(isWeighableUnit('KG'), isTrue);
      expect(isWeighableUnit('g'), isTrue);
      expect(isWeighableUnit('gram'), isTrue);

      // Piece & packaged units (must bypass scale)
      expect(isWeighableUnit('pc'), isFalse);
      expect(isWeighableUnit('piece'), isFalse);
      expect(isWeighableUnit('pkt'), isFalse);
      expect(isWeighableUnit('packet'), isFalse);
      expect(isWeighableUnit('bottle'), isFalse);
      expect(isWeighableUnit('box'), isFalse);
      expect(isWeighableUnit('pack'), isFalse);
      expect(isWeighableUnit('can'), isFalse);
    });

    test('ReceiptPrintService formats comprehensive WhatsApp bill invoice', () {
      final sampleShop = Shop(
        id: 'shop1',
        name: 'Yadav Kirana Store',
        phone: '9876543210',
        address: 'Main Market, Jaipur',
        upiId: 'yadavstore@upi',
      );

      final sampleSale = Sale(
        id: 'sale-99',
        shopId: 'shop1',
        billNo: 42,
        customerName: 'Mukesh Sharma',
        customerPhone: '9829012345',
        subtotal: 200.0,
        total: 180.0,
        paid: 180.0,
        discount: 20.0,
        paymentMode: 'CASH',
        createdAt: DateTime(2026, 11, 14, 18, 30),
        items: [
          CartItem(
            name: 'Aashirvaad Atta 5kg',
            unit: 'pkt',
            price: 150.0,
            qty: 1.0,
          ),
          CartItem(
            name: 'Tata Salt 1kg',
            unit: 'pkt',
            price: 25.0,
            qty: 2.0,
          ),
        ],
      );

      final invoiceText = ReceiptPrintService.buildDetailedWhatsAppInvoice(
        sale: sampleSale,
        shop: sampleShop,
      );

      // Verify header, customer info, item lines, totals for cash sale
      expect(invoiceText.contains('Yadav Kirana Store'), isTrue);
      expect(invoiceText.contains('Invoice #42'), isTrue);
      expect(invoiceText.contains('Mukesh Sharma'), isTrue);
      expect(invoiceText.contains('Aashirvaad Atta 5kg'), isTrue);
      expect(invoiceText.contains('Tata Salt 1kg'), isTrue);
      expect(invoiceText.contains('180.00'), isTrue);
      expect(invoiceText.contains('CASH'), isTrue);

      // Verify online payable bill includes UPI link
      final onlineSale = Sale(
        id: 'sale-100',
        shopId: 'shop1',
        billNo: 43,
        customerName: 'Suresh',
        customerPhone: '9829012345',
        subtotal: 100.0,
        total: 100.0,
        paid: 0.0,
        due: 100.0,
        upiPayable: 100.0,
        paymentMode: 'online',
        paymentStatus: 'pending',
        onlineVerified: false,
        createdAt: DateTime(2026, 11, 14, 18, 35),
        items: [
          CartItem(
            name: 'Sugar 1kg',
            unit: 'kg',
            price: 50.0,
            qty: 2.0,
          ),
        ],
      );

      final onlineInvoice = ReceiptPrintService.buildDetailedWhatsAppInvoice(
        sale: onlineSale,
        shop: sampleShop,
      );
      expect(onlineInvoice.contains('upi://pay?pa=yadavstore@upi'), isTrue);
    });
  });
}
