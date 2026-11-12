import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_pos/core/services/printer_settings_service.dart';
import 'package:shop_pos/core/services/receipt_print_service.dart';
import 'package:shop_pos/core/utils/payment_qr_helper.dart';
import 'package:shop_pos/data/models/cart_item.dart';
import 'package:shop_pos/data/models/sale.dart';
import 'package:shop_pos/data/models/shop.dart';
import 'package:shop_pos/data/services/upi_service.dart';
import 'package:shop_pos/screens/pos/widgets/bill_receipt_card.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await PrinterSettingsService.instance.loadSettings();

  final sampleShop = Shop(
    id: 'shop-123',
    name: 'Yadav Kirana & Veg Store',
    phone: '9876543210',
    address: 'Main Market, Lucknow',
    upiId: 'yadavstore@okicici',
    upiPayeeName: 'Yadav Store',
    googleReviewUrl: 'https://g.page/r/CyadavStoreReview123/review',
    receiptFooter: 'धन्यवाद! फिर पधारें 🙏',
  );

  final sampleItems = [
    CartItem(productId: 'p1', name: 'आलू (Potato)', unit: 'kg', price: 40, qty: 5),
    CartItem(productId: 'p2', name: 'टमाटर (Tomato)', unit: 'kg', price: 60, qty: 5),
  ];

  group('PaymentQrHelper & Security Validation Tests', () {
    test('Test 1: Dynamic Online UPI QR generates exact amount & bill ref', () {
      final uri = UpiService.generateUpiUri(
        upiId: sampleShop.upiId!,
        payeeName: sampleShop.upiPayeeName!,
        amount: 500.0,
        billNo: '1042',
      );
      expect(uri, contains('upi://pay?pa=yadavstore@okicici'));
      expect(uri, contains('am=500.00'));
      expect(uri, contains('cu=INR'));
      expect(uri, contains('tr=1042'));
    });

    test('Test 2: Payment Received Ticked (Online Verified) -> Google Review QR only', () {
      final breakdown = PaymentQrHelper.calculateBreakdown(
        total: 500.0,
        paymentMode: 'online',
        onlineVerified: true,
      );

      expect(breakdown.paid, 500.0);
      expect(breakdown.due, 0.0);
      expect(breakdown.upiPayable, 0.0);
      expect(breakdown.paymentStatus, 'completed');
      expect(breakdown.isFullyPaid, isTrue);

      final qr = PaymentQrHelper.resolveBillQr(
        total: 500.0,
        paid: breakdown.paid,
        due: breakdown.due,
        paymentMode: 'online',
        paymentStatus: breakdown.paymentStatus,
        onlineVerified: breakdown.onlineVerified,
        upiPayableAmount: breakdown.upiPayable,
        upiId: sampleShop.upiId,
        shopName: sampleShop.name,
        googleReviewUrl: sampleShop.googleReviewUrl,
        billNo: '1042',
      );

      expect(qr.type, BillQrType.googleReview);
      expect(qr.qrData, sampleShop.googleReviewUrl);
      expect(qr.instructionText, PaymentQrHelper.googleReviewInstructionHindi);
      expect(qr.qrData!.startsWith('upi://'), isFalse);
    });

    test('Test 3: Payment Received Unticked (Online Pending) -> UPI Payment QR for full bill', () {
      final breakdown = PaymentQrHelper.calculateBreakdown(
        total: 500.0,
        paymentMode: 'online',
        onlineVerified: false,
      );

      // Security check: unverified online MUST NOT be recorded as paid or completed
      expect(breakdown.paid, 0.0);
      expect(breakdown.due, 500.0);
      expect(breakdown.upiPayable, 500.0);
      expect(breakdown.paymentStatus, 'pending');
      expect(breakdown.onlineVerified, isFalse);

      final qr = PaymentQrHelper.resolveBillQr(
        total: 500.0,
        paid: breakdown.paid,
        due: breakdown.due,
        paymentMode: 'online',
        paymentStatus: breakdown.paymentStatus,
        onlineVerified: breakdown.onlineVerified,
        upiPayableAmount: breakdown.upiPayable,
        upiId: sampleShop.upiId,
        shopName: sampleShop.name,
        googleReviewUrl: sampleShop.googleReviewUrl,
        billNo: '1043',
      );

      expect(qr.type, BillQrType.upiPayment);
      expect(qr.amountToPay, 500.0);
      expect(qr.qrData, contains('am=500.00'));
      expect(qr.instructionText, PaymentQrHelper.upiPaymentInstructionHindi);
    });

    test('Test 4: Split Partial Payment (Cash + Pending UPI + Credit) -> QR encodes ONLY remaining UPI', () {
      // Total ₹500 = Cash ₹200 + Unverified UPI ₹150 + Credit ₹150
      final breakdown = PaymentQrHelper.calculateBreakdown(
        total: 500.0,
        paymentMode: 'split',
        cashAmount: 200.0,
        upiAmount: 150.0,
        onlineVerified: false,
      );

      expect(breakdown.cashPaid, 200.0);
      expect(breakdown.upiDeclared, 150.0);
      expect(breakdown.upiPaid, 0.0);
      expect(breakdown.upiPayable, 150.0);
      expect(breakdown.creditAmount, 150.0);
      expect(breakdown.paid, 200.0);
      expect(breakdown.due, 300.0);
      expect(breakdown.paymentStatus, 'pending');

      final qr = PaymentQrHelper.resolveBillQr(
        total: 500.0,
        paid: breakdown.paid,
        due: breakdown.due,
        paymentMode: 'split',
        paymentStatus: breakdown.paymentStatus,
        onlineVerified: breakdown.onlineVerified,
        upiPayableAmount: breakdown.upiPayable,
        upiId: sampleShop.upiId,
        shopName: sampleShop.name,
        googleReviewUrl: sampleShop.googleReviewUrl,
        billNo: '1044',
      );

      // Must encode ONLY 150.00 (never 500.00, 300.00, or 350.00)
      expect(qr.type, BillQrType.upiPayment);
      expect(qr.amountToPay, 150.0);
      expect(qr.qrData, contains('am=150.00'));
      expect(qr.qrData, isNot(contains('am=300.00')));
      expect(qr.qrData, isNot(contains('am=500.00')));
    });

    test('Test 5: Split Fully Paid (Cash + Verified UPI, Credit = 0) -> Google Review QR', () {
      final breakdown = PaymentQrHelper.calculateBreakdown(
        total: 500.0,
        paymentMode: 'split',
        cashAmount: 200.0,
        upiAmount: 300.0,
        onlineVerified: true,
      );

      expect(breakdown.paid, 500.0);
      expect(breakdown.due, 0.0);
      expect(breakdown.upiPaid, 300.0);
      expect(breakdown.upiPayable, 0.0);
      expect(breakdown.creditAmount, 0.0);
      expect(breakdown.paymentStatus, 'completed');

      final qr = PaymentQrHelper.resolveBillQr(
        total: 500.0,
        paid: breakdown.paid,
        due: breakdown.due,
        paymentMode: 'split',
        paymentStatus: breakdown.paymentStatus,
        onlineVerified: breakdown.onlineVerified,
        upiPayableAmount: breakdown.upiPayable,
        upiId: sampleShop.upiId,
        shopName: sampleShop.name,
        googleReviewUrl: sampleShop.googleReviewUrl,
        billNo: '1045',
      );

      expect(qr.type, BillQrType.googleReview);
      expect(qr.qrData, sampleShop.googleReviewUrl);
    });

    test('Test 6: Split validation rejects Cash+UPI exceeding Total and blank Google Review URL never generates fake URL', () {
      final err = PaymentQrHelper.validateSplitAmounts(
        total: 500.0,
        cashAmount: 300.0,
        upiAmount: 250.0,
      );
      expect(err, isNotNull);

      final qrNoReview = PaymentQrHelper.resolveBillQr(
        total: 500.0,
        paid: 500.0,
        due: 0.0,
        paymentMode: 'cash',
        paymentStatus: 'completed',
        onlineVerified: true,
        upiPayableAmount: 0.0,
        upiId: sampleShop.upiId,
        shopName: sampleShop.name,
        googleReviewUrl: '',
        billNo: '1046',
      );
      expect(qrNoReview.type, BillQrType.none);
      expect(qrNoReview.hasQr, isFalse);
      expect(qrNoReview.missingGoogleReviewConfig, isTrue);
    });

    test('Test 7: Sale note metadata round-trip & Share caption matches Payment Status', () {
      final pendingSale = Sale(
        id: 'sale-1',
        shopId: sampleShop.id,
        billNo: 201,
        items: sampleItems,
        subtotal: 500,
        total: 500,
        paid: 200,
        due: 300,
        paymentMode: 'split',
        paymentStatus: 'pending',
        cashPaid: 200,
        upiPaid: 0,
        upiPayable: 150,
        creditAmount: 150,
        onlineVerified: false,
        verificationSource: 'unverified',
        createdAt: DateTime(2026, 11, 12, 18, 30),
        clientRef: 'ref-201',
      );

      // Simulate Supabase row coming back with note metadata
      final cloudRow = <String, dynamic>{
        'id': pendingSale.id,
        'shop_id': pendingSale.shopId,
        'bill_no': pendingSale.billNo,
        'items': sampleItems.map((e) => e.toJson()).toList(),
        'sub_total': pendingSale.subtotal,
        'discount': pendingSale.discount,
        'total': pendingSale.total,
        'paid': pendingSale.paid,
        'due': pendingSale.due,
        'payment_mode': pendingSale.paymentMode,
        'note': pendingSale.encodedNote,
        'created_at': pendingSale.createdAt.toIso8601String(),
      };

      final restored = Sale.fromJson(cloudRow);
      expect(restored.paymentStatus, 'pending');
      expect(restored.cashPaid, 200.0);
      expect(restored.upiPayable, 150.0);
      expect(restored.creditAmount, 150.0);
      expect(restored.onlineVerified, isFalse);
      expect(restored.effectiveUpiPayable, 150.0);

      final pendingCaption = ReceiptPrintService.buildShareCaption(
        sale: restored,
        shop: sampleShop,
      );
      expect(pendingCaption, contains('150.00'));
      expect(pendingCaption, contains(PaymentQrHelper.upiPaymentInstructionHindi));

      final paidSale = restored.copyWith(
        paid: 500,
        due: 0,
        upiPaid: 300,
        upiPayable: 0,
        creditAmount: 0,
        onlineVerified: true,
        paymentStatus: 'completed',
      );
      final paidCaption = ReceiptPrintService.buildShareCaption(
        sale: paidSale,
        shop: sampleShop,
      );
      expect(paidCaption, contains(PaymentQrHelper.googleReviewInstructionHindi));
    });

    test('Test 8: PDF Generation succeeds for both UPI Pending and Google Review Paid bills', () async {
      final pendingSale = Sale(
        id: 'sale-pdf-1',
        shopId: sampleShop.id,
        billNo: 301,
        items: sampleItems,
        subtotal: 500,
        total: 500,
        paid: 0,
        due: 500,
        paymentMode: 'online',
        paymentStatus: 'pending',
        upiPayable: 500,
        onlineVerified: false,
        createdAt: DateTime.now(),
      );

      final paidSale = Sale(
        id: 'sale-pdf-2',
        shopId: sampleShop.id,
        billNo: 302,
        items: sampleItems,
        subtotal: 500,
        total: 500,
        paid: 500,
        due: 0,
        paymentMode: 'online',
        paymentStatus: 'completed',
        upiPaid: 500,
        onlineVerified: true,
        createdAt: DateTime.now(),
      );

      final pendingPdf = await ReceiptPrintService.generateReceiptDocument(
        sale: pendingSale,
        shop: sampleShop,
      );
      final paidPdf = await ReceiptPrintService.generateReceiptDocument(
        sale: paidSale,
        shop: sampleShop,
      );

      expect((await pendingPdf.save()).isNotEmpty, isTrue);
      expect((await paidPdf.save()).isNotEmpty, isTrue);
    });
  });

  group('BillReceiptCard Widget Responsive & Dynamic QR Tests', () {
    testWidgets('Unticked Online Bill renders UPI Payment QR & prompt on narrow mobile screen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BillReceiptCard(
                shopName: sampleShop.name,
                billNo: '501',
                dateString: '12-11-2026 09:00 PM',
                items: sampleItems,
                subtotal: 500,
                total: 500,
                paid: 0,
                due: 500,
                paymentMode: 'online',
                paymentStatus: 'pending',
                upiPayableAmount: 500,
                onlineVerified: false,
                upiId: sampleShop.upiId,
                upiPayeeName: sampleShop.upiPayeeName,
                googleReviewUrl: sampleShop.googleReviewUrl,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text(PaymentQrHelper.upiPaymentInstructionHindi), findsOneWidget);
      expect(find.textContaining('500.00'), findsWidgets);
      expect(find.text(PaymentQrHelper.googleReviewInstructionHindi), findsNothing);
    });

    testWidgets('Verified Paid Bill switches to Google Review QR & exact Hindi text on tablet screen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BillReceiptCard(
                shopName: sampleShop.name,
                billNo: '502',
                dateString: '12-11-2026 09:05 PM',
                items: sampleItems,
                subtotal: 500,
                total: 500,
                paid: 500,
                due: 0,
                paymentMode: 'online',
                paymentStatus: 'completed',
                upiPayableAmount: 0,
                onlineVerified: true,
                upiId: sampleShop.upiId,
                upiPayeeName: sampleShop.upiPayeeName,
                googleReviewUrl: sampleShop.googleReviewUrl,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text(PaymentQrHelper.googleReviewInstructionHindi), findsOneWidget);
      expect(find.text(PaymentQrHelper.upiPaymentInstructionHindi), findsNothing);
      expect(find.text('Scan & Pay (UPI)'), findsNothing);
    });
  });
}
