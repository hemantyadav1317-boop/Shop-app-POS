import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_pos/data/models/shop.dart';
import 'package:shop_pos/data/models/payment_transaction.dart';
import 'package:shop_pos/data/services/phonepe_service.dart';
import 'package:shop_pos/core/utils/payment_qr_helper.dart';
import 'package:shop_pos/core/services/printer_settings_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('⚡ PhonePe Dynamic QR & Auto-Verification Integration Tests', () {
    test('Shop model serializes and parses PhonePe integration configuration', () {
      final now = DateTime.now();
      final shop = Shop(
        id: 'shop-test-101',
        name: 'Yadav Veggie & Fruit Store',
        phone: '9876543210',
        upiId: 'yadavstore@ybl',
        phonePeEnabled: true,
        phonePeMerchantId: 'MYADAV101',
        phonePeMobileNumber: '9876543210',
        phonePeStoreName: 'Yadav Veggie & Fruit Store',
        phonePeEnvironment: 'sandbox',
        phonePeConnectedAt: now,
      );

      final json = shop.toJson();
      expect(json['phonepe_enabled'], isTrue);
      expect(json['phonepe_merchant_id'], 'MYADAV101');
      expect(json['phonepe_mobile_number'], '9876543210');
      expect(json['phonepe_store_name'], 'Yadav Veggie & Fruit Store');
      expect(json['phonepe_environment'], 'sandbox');

      final parsed = Shop.fromJson(json);
      expect(parsed.phonePeEnabled, isTrue);
      expect(parsed.phonePeMerchantId, 'MYADAV101');
      expect(parsed.phonePeMobileNumber, '9876543210');
      expect(parsed.phonePeStoreName, 'Yadav Veggie & Fruit Store');
      expect(parsed.phonePeEnvironment, 'sandbox');
      expect(parsed.phonePeConnectedAt, isNotNull);
    });

    test('PaymentTransaction model serializes, deserializes, and reports state', () {
      final now = DateTime.now();
      final tx = PaymentTransaction(
        id: 'tx-uuid-1',
        shopId: 'shop-test-101',
        billNo: 615,
        clientRef: 'client-ref-abc',
        merchantTransactionId: 'BILLZO_SHOP101_615_12345678',
        amount: 350.50,
        status: 'PENDING',
        paymentMode: 'online',
        qrData: 'upi://pay?pa=yadavstore@ybl&am=350.50',
        createdAt: now,
        updatedAt: now,
      );

      expect(tx.isPending, isTrue);
      expect(tx.isSuccess, isFalse);
      expect(tx.isFailed, isFalse);

      final json = tx.toJson();
      expect(json['merchant_transaction_id'], 'BILLZO_SHOP101_615_12345678');
      expect(json['amount'], 350.50);
      expect(json['status'], 'PENDING');

      final parsed = PaymentTransaction.fromJson(json);
      expect(parsed.merchantTransactionId, tx.merchantTransactionId);
      expect(parsed.amount, 350.50);
      expect(parsed.billNo, 615);
      expect(parsed.isPending, isTrue);
    });

    test('PhonePeService creates dynamic payment order with unique transaction ref', () async {
      final shop = Shop(
        id: 'b80dfa6b-f27b-4660-97cb-6505b3fb1baf',
        name: 'Yadav Veggie & Fruit Store',
        upiId: 'yadavstore@ybl',
        phonePeEnabled: true,
        phonePeMerchantId: 'MYADAVVEGGIE',
        phonePeEnvironment: 'sandbox',
      );

      final tx = await PhonePeService.instance.createPaymentOrder(
        shop: shop,
        billNo: 615,
        amount: 450.0,
        clientRef: 'client-ref-test',
        paymentMode: 'online',
      );

      expect(tx.amount, 450.0);
      expect(tx.billNo, 615);
      expect(tx.merchantTransactionId, contains('BILLZO_'));
      expect(tx.merchantTransactionId, contains('_615_'));
      expect(tx.qrData, isNotNull);
      expect(tx.qrData, contains('upi://pay?pa=yadavstore@ybl'));
      expect(tx.qrData, contains('am=450.00'));
      expect(tx.qrData, contains('&tr=BILLZO_'));
      expect(tx.status, 'PENDING');
    });

    test('PhonePeService simulation verifies payment to SUCCESS state', () async {
      final txId = 'BILLZO_SIM_615_99999';
      final verifiedTx = await PhonePeService.instance.simulatePaymentSuccess(txId);

      expect(verifiedTx, isNotNull);
      expect(verifiedTx!.isSuccess, isTrue);
      expect(verifiedTx.status, 'SUCCESS');
      expect(verifiedTx.verifiedAt, isNotNull);
    });

    test('PaymentQrHelper calculates breakdown with phonepe_auto_verified source', () {
      final breakdown = PaymentQrHelper.calculateBreakdown(
        total: 500.0,
        paymentMode: 'online',
        onlineVerified: true,
        verificationSource: 'phonepe_auto_verified',
      );

      expect(breakdown.isFullyPaid, isTrue);
      expect(breakdown.onlineVerified, isTrue);
      expect(breakdown.verificationSource, 'phonepe_auto_verified');
      expect(breakdown.paid, 500.0);
      expect(breakdown.due, 0.0);
      expect(breakdown.paymentStatus, 'completed');
    });

    test('Split payment calculation isolates UPI payable from Cash portion', () {
      // Total ₹1000: ₹400 Cash + ₹600 UPI (unverified initially)
      final pendingBreakdown = PaymentQrHelper.calculateBreakdown(
        total: 1000.0,
        paymentMode: 'split',
        cashAmount: 400.0,
        upiAmount: 600.0,
        onlineVerified: false,
      );

      expect(pendingBreakdown.isFullyPaid, isFalse);
      expect(pendingBreakdown.cashPaid, 400.0);
      expect(pendingBreakdown.upiPaid, 0.0);
      expect(pendingBreakdown.upiPayable, 600.0);
      expect(pendingBreakdown.paid, 400.0);
      expect(pendingBreakdown.due, 600.0);
      expect(pendingBreakdown.paymentStatus, 'pending');

      // Once PhonePe verifies UPI portion:
      final verifiedBreakdown = PaymentQrHelper.calculateBreakdown(
        total: 1000.0,
        paymentMode: 'split',
        cashAmount: 400.0,
        upiAmount: 600.0,
        onlineVerified: true,
        verificationSource: 'phonepe_auto_verified',
      );

      expect(verifiedBreakdown.isFullyPaid, isTrue);
      expect(verifiedBreakdown.cashPaid, 400.0);
      expect(verifiedBreakdown.upiPaid, 600.0);
      expect(verifiedBreakdown.upiPayable, 0.0);
      expect(verifiedBreakdown.paid, 1000.0);
      expect(verifiedBreakdown.due, 0.0);
      expect(verifiedBreakdown.paymentStatus, 'completed');
    });

    test('PrinterSettingsService defaults to D-Mart style auto-print on payment and toggles cleanly', () async {
      SharedPreferences.setMockInitialValues({});
      final ps = PrinterSettingsService.instance;
      await ps.loadSettings();
      expect(ps.autoPrintOnPayment, isTrue);

      await ps.setAutoPrintOnPayment(false);
      expect(ps.autoPrintOnPayment, isFalse);

      await ps.setAutoPrintOnPayment(true);
      expect(ps.autoPrintOnPayment, isTrue);
    });
  });
}
