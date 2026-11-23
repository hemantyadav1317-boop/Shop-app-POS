import 'package:flutter_test/flutter_test.dart';
import 'package:shop_pos/data/models/shop.dart';
import 'package:shop_pos/data/services/upi_service.dart';
import 'package:shop_pos/core/utils/payment_qr_helper.dart';

void main() {
  group('Critical Fixes Verification Tests (Cart, Khata Sync & GPay UPI QR)', () {
    test('Fix 3: Google Pay UPI QR strictly complies with NPCI & GPay requirements', () {
      const upiId = 'shreeshyam@okaxis';
      const payeeName = 'Shree Shyam Kirana';
      const amount = 249.50;
      const billNo = '1048';
      final sessionRef = 'BZ1048T92837461';

      final uri = UpiService.generateUpiUri(
        upiId: upiId,
        payeeName: payeeName,
        amount: amount,
        billNo: billNo,
        tr: sessionRef,
      );

      // Verify scheme and required parameters
      expect(uri.startsWith('upi://pay?'), isTrue);
      expect(uri, contains('pa=shreeshyam@okaxis'));
      expect(uri, contains('pn=Shree%20Shyam%20Kirana'));
      expect(uri, contains('am=249.50'));
      expect(uri, contains('cu=INR'));
      expect(uri, contains('tn=Bill%201048'));
      expect(uri, contains('tr=BZ1048T92837461'));

      // Strict Google Pay checks:
      // 1. tr must be strictly alphanumeric (no underscores, hyphens, or symbols)
      final trMatch = RegExp(r'[?&]tr=([^&]+)').firstMatch(uri);
      expect(trMatch, isNotNull);
      final trValue = trMatch!.group(1)!;
      expect(RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trValue), isTrue);
      expect(trValue.length, lessThanOrEqualTo(35));

      // 2. No fake or dummy merchant category codes (mc) or terminal ids (tid) for standard VPAs
      expect(uri.contains('mc='), isFalse);
      expect(uri.contains('tid='), isFalse);
    });

    test('Fix 3: UpiService strips illegal characters like underscores and hyphens from tr', () {
      final uri = UpiService.generateUpiUri(
        upiId: 'test@upi',
        payeeName: 'Test Store',
        amount: 100.0,
        tr: 'BILLZO_SHOP-101_#99_12345',
      );

      final trMatch = RegExp(r'[?&]tr=([^&]+)').firstMatch(uri);
      expect(trMatch, isNotNull);
      final trValue = trMatch!.group(1)!;
      // All symbols and underscores must be removed
      expect(trValue, equals('BILLZOSHOP1019912345'));
      expect(RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trValue), isTrue);
    });

    test('Fix 3: PaymentQrHelper.buildUpiUri produces sanitized alphanumeric TR', () {
      final uri = PaymentQrHelper.buildUpiUri(
        upiId: 'test@upi',
        payeeName: 'Test Store',
        amount: 150.0,
        billNo: 'INV_2026-001',
      );

      expect(uri, isNotNull);
      expect(uri!, contains('am=150.00'));
      expect(uri, contains('cu=INR'));
      expect(uri, contains('tr=INV2026001'));
      final trMatch = RegExp(r'[?&]tr=([^&]+)').firstMatch(uri);
      expect(trMatch, isNotNull);
      final tr = trMatch!.group(1)!;
      expect(tr, equals('INV2026001'));
      expect(tr.contains('_'), isFalse);
      expect(tr.contains('-'), isFalse);
    });
  });
}
