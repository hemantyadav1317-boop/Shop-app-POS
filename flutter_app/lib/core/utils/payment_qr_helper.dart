import 'dart:math' as math;

enum BillQrType {
  upiPayment,
  googleReview,
  none,
}

class PaymentBreakdown {
  final double total;
  final String paymentMode;
  final double cashPaid;
  final double upiDeclared;
  final double upiPaid;
  final double upiPayable;
  final double creditAmount;
  final double paid;
  final double due;
  final bool onlineVerified;
  final String paymentStatus; // 'completed' | 'pending'
  final String verificationSource;

  const PaymentBreakdown({
    required this.total,
    required this.paymentMode,
    required this.cashPaid,
    required this.upiDeclared,
    required this.upiPaid,
    required this.upiPayable,
    required this.creditAmount,
    required this.paid,
    required this.due,
    required this.onlineVerified,
    required this.paymentStatus,
    required this.verificationSource,
  });

  bool get isFullyPaid =>
      due <= 0.009 &&
      upiPayable <= 0.009 &&
      paymentStatus == 'completed';
}

class BillQrDecision {
  final BillQrType type;
  final String? qrData;
  final String headline;
  final String instructionText;
  final double amountToPay;
  final String? upiId;
  final bool missingUpiConfig;
  final bool missingGoogleReviewConfig;

  const BillQrDecision({
    required this.type,
    required this.qrData,
    required this.headline,
    required this.instructionText,
    required this.amountToPay,
    this.upiId,
    this.missingUpiConfig = false,
    this.missingGoogleReviewConfig = false,
  });

  bool get hasQr =>
      type != BillQrType.none && qrData != null && qrData!.trim().isNotEmpty;
}

class PaymentQrHelper {
  static const String googleReviewInstructionHindi =
      'हमारी सेवा पसंद आई? हमें Google पर अपना Review दें। धन्यवाद!';
  static const String upiPaymentInstructionHindi =
      'कृपया QR Code स्कैन करके भुगतान करें।';

  static double round2(double value) {
    if (!value.isFinite) return 0.0;
    return (value * 100).roundToDouble() / 100.0;
  }

  static bool isValidUpiId(String? upiId) {
    if (upiId == null) return false;
    final clean = upiId.trim();
    if (clean.length < 5 || clean.contains(' ')) return false;
    final atIdx = clean.indexOf('@');
    if (atIdx <= 0 || atIdx >= clean.length - 1) return false;
    return true;
  }

  static bool isValidGoogleReviewUrl(String? url) {
    if (url == null) return false;
    final clean = url.trim();
    if (clean.isEmpty) return false;
    final uri = Uri.tryParse(clean);
    if (uri == null) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    if (uri.host.trim().isEmpty || !uri.host.contains('.')) return false;
    return true;
  }

  static String? buildUpiUri({
    required String? upiId,
    required String payeeName,
    required double amount,
    String? billNo,
  }) {
    if (!isValidUpiId(upiId)) return null;
    final safeAmount = round2(amount);
    if (safeAmount <= 0) return null;

    final cleanUpi = upiId!.trim();
    final cleanName = Uri.encodeComponent(
      payeeName.trim().isEmpty ? 'ShopPOS' : payeeName.trim(),
    );
    final formattedAmount = safeAmount.toStringAsFixed(2);
    final cleanRef = (billNo != null && billNo.trim().isNotEmpty)
        ? Uri.encodeComponent(billNo.trim())
        : null;
    final cleanNote = Uri.encodeComponent(
      cleanRef != null ? 'Bill ${billNo!.trim()}' : 'POS Bill Payment',
    );

    final buffer = StringBuffer(
      'upi://pay?pa=$cleanUpi&pn=$cleanName&am=$formattedAmount&cu=INR&tn=$cleanNote',
    );
    if (cleanRef != null) {
      buffer.write('&tr=$cleanRef');
    }
    return buffer.toString();
  }

  /// Validates split amounts and returns an error string if invalid, else null.
  static String? validateSplitAmounts({
    required double total,
    required double cashAmount,
    required double upiAmount,
    double creditAmount = 0,
  }) {
    final safeTotal = round2(math.max(0, total));
    if (cashAmount < -0.001 || upiAmount < -0.001 || creditAmount < -0.001) {
      return 'राशि शून्य से कम नहीं हो सकती।';
    }
    final combined = round2(cashAmount + upiAmount + creditAmount);
    if (combined - safeTotal > 0.01) {
      return 'Cash + UPI + Credit का योग कुल बिल राशि (₹${safeTotal.toStringAsFixed(2)}) से अधिक नहीं हो सकता।';
    }
    return null;
  }

  /// Computes authoritative payment breakdown ensuring:
  /// - Unverified Online payment is NEVER marked paid/completed
  /// - Split UPI payable NEVER includes Cash or Credit portions
  static PaymentBreakdown calculateBreakdown({
    required double total,
    required String paymentMode,
    double cashAmount = 0,
    double upiAmount = 0,
    double? creditAmount,
    required bool onlineVerified,
    String? verificationSource,
  }) {
    final safeTotal = round2(math.max(0, total));
    final normalizedMode = paymentMode.trim().toLowerCase();

    if (safeTotal <= 0) {
      return PaymentBreakdown(
        total: 0,
        paymentMode: normalizedMode,
        cashPaid: 0,
        upiDeclared: 0,
        upiPaid: 0,
        upiPayable: 0,
        creditAmount: 0,
        paid: 0,
        due: 0,
        onlineVerified: true,
        paymentStatus: 'completed',
        verificationSource: verificationSource ?? 'zero_bill',
      );
    }

    switch (normalizedMode) {
      case 'cash':
        return PaymentBreakdown(
          total: safeTotal,
          paymentMode: 'cash',
          cashPaid: safeTotal,
          upiDeclared: 0,
          upiPaid: 0,
          upiPayable: 0,
          creditAmount: 0,
          paid: safeTotal,
          due: 0,
          onlineVerified: false,
          paymentStatus: 'completed',
          verificationSource: verificationSource ?? 'cash_drawer',
        );

      case 'credit':
        return PaymentBreakdown(
          total: safeTotal,
          paymentMode: 'credit',
          cashPaid: 0,
          upiDeclared: 0,
          upiPaid: 0,
          upiPayable: 0,
          creditAmount: safeTotal,
          paid: 0,
          due: safeTotal,
          onlineVerified: false,
          paymentStatus: 'pending',
          verificationSource: verificationSource ?? 'khata_credit',
        );

      case 'online':
        final upiPaid = onlineVerified ? safeTotal : 0.0;
        final upiPayable = onlineVerified ? 0.0 : safeTotal;
        final paid = upiPaid;
        final due = round2(safeTotal - paid);
        return PaymentBreakdown(
          total: safeTotal,
          paymentMode: 'online',
          cashPaid: 0,
          upiDeclared: safeTotal,
          upiPaid: upiPaid,
          upiPayable: upiPayable,
          creditAmount: 0,
          paid: paid,
          due: due,
          onlineVerified: onlineVerified,
          paymentStatus: onlineVerified && due <= 0.009 ? 'completed' : 'pending',
          verificationSource: onlineVerified
              ? (verificationSource ?? 'cashier_verified')
              : 'unverified',
        );

      case 'split':
        final safeCash = round2(cashAmount.clamp(0.0, safeTotal));
        final remAfterCash = round2(math.max(0.0, safeTotal - safeCash));
        final safeUpi = round2(upiAmount.clamp(0.0, remAfterCash));
        final remAfterUpi = round2(math.max(0.0, remAfterCash - safeUpi));
        final safeCredit = creditAmount != null
            ? round2(creditAmount.clamp(0.0, remAfterUpi))
            : remAfterUpi;

        final upiPaid = onlineVerified ? safeUpi : 0.0;
        final upiPayable = onlineVerified ? 0.0 : safeUpi;
        final paid = round2(safeCash + upiPaid);
        final due = round2(math.max(0.0, safeTotal - paid));
        final fullyPaid =
            due <= 0.009 && upiPayable <= 0.009 && safeCredit <= 0.009;

        return PaymentBreakdown(
          total: safeTotal,
          paymentMode: 'split',
          cashPaid: safeCash,
          upiDeclared: safeUpi,
          upiPaid: upiPaid,
          upiPayable: upiPayable,
          creditAmount: safeCredit,
          paid: paid,
          due: due,
          onlineVerified: onlineVerified || safeUpi <= 0.009,
          paymentStatus: fullyPaid ? 'completed' : 'pending',
          verificationSource: safeUpi <= 0.009
              ? (verificationSource ?? 'cash_split')
              : (onlineVerified
                  ? (verificationSource ?? 'cashier_verified')
                  : 'unverified'),
        );

      default:
        // Fallback treats unknown non-cash mode safely without assuming UPI verified.
        return PaymentBreakdown(
          total: safeTotal,
          paymentMode: normalizedMode,
          cashPaid: 0,
          upiDeclared: 0,
          upiPaid: 0,
          upiPayable: 0,
          creditAmount: safeTotal,
          paid: 0,
          due: safeTotal,
          onlineVerified: false,
          paymentStatus: 'pending',
          verificationSource: verificationSource ?? 'unverified',
        );
    }
  }

  /// Resolves which QR (UPI Payment vs Google Review vs None) must appear across
  /// Bill Preview, WhatsApp Share, Download Bill, Print Bill, and Image Share.
  static BillQrDecision resolveBillQr({
    required double total,
    required double paid,
    required double due,
    required String paymentMode,
    required String paymentStatus,
    required bool onlineVerified,
    required double upiPayableAmount,
    required String? upiId,
    required String shopName,
    required String? googleReviewUrl,
    String? billNo,
  }) {
    final safeTotal = round2(math.max(0, total));
    final safeDue = round2(math.max(0, due));
    final safeUpiPayable = round2(math.max(0, upiPayableAmount));
    final normalizedMode = paymentMode.trim().toLowerCase();
    final normalizedStatus = paymentStatus.trim().toLowerCase();

    // Determine effective remaining UPI payable:
    // - Never include Cash or Credit amounts.
    // - If Online & unverified (or pending with explicit upiPayable == 0 on legacy pending online),
    //   remaining UPI payable is `safeDue > 0 ? safeDue : safeTotal`.
    double effectiveUpiDue = 0.0;
    if (normalizedMode == 'online') {
      if (!onlineVerified || normalizedStatus != 'completed' || safeDue > 0.009) {
        effectiveUpiDue = safeUpiPayable > 0.009
            ? safeUpiPayable
            : (safeDue > 0.009 ? safeDue : safeTotal);
      }
    } else if (normalizedMode == 'split') {
      if (!onlineVerified && safeUpiPayable > 0.009) {
        effectiveUpiDue = math.min(safeUpiPayable, safeDue > 0.009 ? safeDue : safeUpiPayable);
      }
    }

    // Rule: Case B — Unpaid / Pending UPI amount exists -> Show Payment QR ONLY for effectiveUpiDue
    if (effectiveUpiDue > 0.009) {
      final upiUri = buildUpiUri(
        upiId: upiId,
        payeeName: shopName,
        amount: effectiveUpiDue,
        billNo: billNo,
      );
      if (upiUri == null) {
        return BillQrDecision(
          type: BillQrType.none,
          qrData: null,
          headline: 'UPI Payment Pending',
          instructionText: upiPaymentInstructionHindi,
          amountToPay: effectiveUpiDue,
          upiId: upiId?.trim(),
          missingUpiConfig: true,
        );
      }
      return BillQrDecision(
        type: BillQrType.upiPayment,
        qrData: upiUri,
        headline: 'Scan & Pay (UPI)',
        instructionText: upiPaymentInstructionHindi,
        amountToPay: effectiveUpiDue,
        upiId: upiId!.trim(),
      );
    }

    // Rule: Case A — Fully paid & verified -> NEVER show Payment QR; show Google Review QR
    final isFullyPaid =
        normalizedStatus == 'completed' &&
        safeDue <= 0.009 &&
        (normalizedMode != 'online' || onlineVerified) &&
        (paid >= safeTotal - 0.01 || safeTotal <= 0);

    if (isFullyPaid) {
      if (isValidGoogleReviewUrl(googleReviewUrl)) {
        return BillQrDecision(
          type: BillQrType.googleReview,
          qrData: googleReviewUrl!.trim(),
          headline: 'Rate Us on Google',
          instructionText: googleReviewInstructionHindi,
          amountToPay: 0,
        );
      }
      return const BillQrDecision(
        type: BillQrType.none,
        qrData: null,
        headline: 'Payment Received (Paid)',
        instructionText: googleReviewInstructionHindi,
        amountToPay: 0,
        missingGoogleReviewConfig: true,
      );
    }

    // Pending Credit / Khata bill with no UPI payable: never mark as paid / never invent UPI QR
    return BillQrDecision(
      type: BillQrType.none,
      qrData: null,
      headline: 'Payment Pending',
      instructionText: 'शेष उधार राशि: ₹${safeDue.toStringAsFixed(2)}',
      amountToPay: safeDue,
    );
  }
}

