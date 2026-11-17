import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_pos/core/services/payment_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('⚡ PaymentNotificationService Tests (D-Mart Style Auto-Verify)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PaymentNotificationService.instance.init();
    });

    test('DetectedPayment parses payload correctly', () {
      final map = {
        'amount': 350.50,
        'appName': 'PhonePe',
        'packageName': 'com.phonepe.app',
        'title': 'PhonePe Business',
        'text': 'Received ₹350.50 from Rahul via UPI',
        'utr': 'UTR1234567890',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final payment = DetectedPayment.fromMap(map);
      expect(payment.amount, 350.50);
      expect(payment.appName, 'PhonePe');
      expect(payment.utr, 'UTR1234567890');
      expect(payment.isConsumed, isFalse);
    });

    test('Simulate payment streams event and adds to recent payments', () async {
      final service = PaymentNotificationService.instance;
      DetectedPayment? received;
      final sub = service.paymentStream.listen((p) {
        received = p;
      });

      await service.simulatePayment(
        amount: 250.0,
        appName: 'Paytm',
        utr: 'TEST_PAYTM_999',
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(received, isNotNull);
      expect(received!.amount, 250.0);
      expect(received!.appName, 'Paytm');
      expect(received!.utr, 'TEST_PAYTM_999');

      await sub.cancel();
    });

    test('consumeMatchingPayment matches exact amount and consumes only once', () async {
      final service = PaymentNotificationService.instance;

      await service.simulatePayment(
        amount: 540.0,
        appName: 'Google Pay',
        utr: 'GPAY_540_ABC',
      );

      // 1. Should match 540.0
      final match = service.consumeMatchingPayment(540.0);
      expect(match, isNotNull);
      expect(match!.amount, 540.0);
      expect(match.appName, 'Google Pay');
      expect(match.isConsumed, isTrue);

      // 2. Second attempt must return null (already consumed)
      final secondTry = service.consumeMatchingPayment(540.0);
      expect(secondTry, isNull);
    });

    test('Toggle auto-verify and cloud relay persists preferences', () async {
      final service = PaymentNotificationService.instance;

      await service.setAutoVerifyEnabled(false);
      expect(service.isAutoVerifyEnabled, isFalse);

      await service.setCloudRelayEnabled(true);
      expect(service.isCloudRelayEnabled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('payment_auto_verify_enabled'), isFalse);
      expect(prefs.getBool('payment_cloud_relay_enabled'), isTrue);

      // Restore
      await service.setAutoVerifyEnabled(true);
      await service.setCloudRelayEnabled(false);
    });
  });
}
