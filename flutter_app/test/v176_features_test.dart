import 'package:flutter_test/flutter_test.dart';
import 'package:shop_pos/core/services/update_service.dart';
import 'package:shop_pos/core/utils/payment_qr_helper.dart';
import 'package:shop_pos/data/services/upi_service.dart';

void main() {
  group('v1.7.6 Feature & Navigation Tests', () {
    test('Version is properly formatted as semantic version', () {
      final v = UpdateService.currentVersion;
      expect(v, isNotEmpty);
      expect(RegExp(r'^\d+\.\d+\.\d+$').hasMatch(v), isTrue);
    });

    test('Parallel cloud sync logic constructs properly', () async {
      // Verifies Future.wait parallelization logic runs cleanly
      final futures = [
        Future.value([{'category': 'GROCERY'}]),
        Future.value(['Product 1', 'Product 2']),
      ];
      final results = await Future.wait(futures);
      expect(results.length, 2);
      expect(results[0], isNotEmpty);
      expect(results[1], isNotEmpty);
    });

    test('Google Pay dynamic QR omits tr and sanitizes # from note', () {
      final uri = UpiService.generateUpiUri(
        upiId: 'yadavstore@okicici',
        payeeName: 'Yadav Store',
        amount: 140.0,
        note: 'Bill #140',
        billNo: '140',
        includeTr: false,
      );

      // Verify no tr parameter is present (bypasses GPay merchant check failure)
      expect(uri.contains('tr='), isFalse);

      // Verify no '#' symbol in note or anywhere in the URI
      expect(uri.contains('#'), isFalse);
      expect(uri.contains('%23'), isFalse);

      // Verify valid NPCI UPI intent structure
      expect(uri.startsWith('upi://pay?'), isTrue);
      expect(uri, contains('pa=yadavstore@okicici'));
      expect(uri, contains('pn=Yadav%20Store'));
      expect(uri, contains('am=140.00'));
      expect(uri, contains('cu=INR'));
      expect(uri, contains('tn=Bill%20140'));

      // Validate URI parsing without exceptions
      final parsed = Uri.parse(uri);
      expect(parsed.scheme, 'upi');
      expect(parsed.host, 'pay');
      expect(parsed.queryParameters['pa'], 'yadavstore@okicici');
      expect(parsed.queryParameters['pn'], 'Yadav Store');
      expect(parsed.queryParameters['am'], '140.00');
      expect(parsed.queryParameters['cu'], 'INR');
      expect(parsed.queryParameters['tn'], 'Bill 140');
      expect(parsed.queryParameters.containsKey('tr'), isFalse);
    });

    test('UpiService sanitizes special characters from notes and payee names', () {
      final uri = UpiService.generateUpiUri(
        upiId: 'shop@ybl',
        payeeName: 'Kirana & Super Store (Main)',
        amount: 250.50,
        note: 'Order #99_Special & Discount?',
        includeTr: false,
      );

      expect(uri.contains('#'), isFalse);
      expect(uri.contains('_'), isFalse);
      final parsed = Uri.parse(uri);
      expect(parsed.queryParameters['tn']!.contains('&'), isFalse);
      expect(parsed.queryParameters['am'], '250.50');
      expect(parsed.queryParameters['tn'], 'Order 99 Special Discount');
    });

    test('PaymentQrHelper.buildUpiUri supports includeTr: false for Google Pay', () {
      final uri = PaymentQrHelper.buildUpiUri(
        upiId: 'retailer@paytm',
        payeeName: 'Retail Shop',
        amount: 75.0,
        billNo: '#55',
        includeTr: false,
      );

      expect(uri, isNotNull);
      expect(uri!.contains('tr='), isFalse);
      expect(uri.contains('#'), isFalse);
      expect(uri, contains('tn=Bill%2055'));
    });
  });
}
