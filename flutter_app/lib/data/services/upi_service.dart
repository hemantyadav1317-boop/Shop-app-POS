import '../../core/utils/payment_qr_helper.dart';

class UpiService {
  /// Validates a UPI VPA string (e.g., name@bank)
  static bool isValidUpiId(String? upiId) =>
      PaymentQrHelper.isValidUpiId(upiId);

  /// Generates a valid, 100% NPCI & Google Pay compliant UPI intent URI for Indian payment apps
  ///
  /// Google Pay / NPCI Compatibility Requirements:
  /// - [tr]: Strictly alphanumeric [a-zA-Z0-9], max 35 characters, NO underscores, hyphens, or symbols.
  ///         Must be unique per transaction attempt to prevent "Duplicate transaction reference" errors.
  /// - [pa]: Valid, trimmed UPI ID.
  /// - [pn]: URL-encoded payee name (fallback to 'ShopPOS' if empty).
  /// - [am]: Formatted with exactly 2 decimal places.
  /// - [cu]: Strictly 'INR'.
  /// - [tn]: URL-encoded note.
  /// - Never include fake 'mc' or 'tid' for standard/personal VPAs to prevent Google Pay security blocks.
  static String generateUpiUri({
    required String upiId,
    required String payeeName,
    required double amount,
    String? note,
    String? billNo,
    String? tr,
  }) {
    if (!PaymentQrHelper.isValidUpiId(upiId)) return '';
    final safeAmount = PaymentQrHelper.round2(amount);
    if (safeAmount <= 0) return '';

    final cleanUpi = upiId.trim();
    final cleanName = Uri.encodeComponent(
      payeeName.trim().isEmpty ? 'ShopPOS' : payeeName.trim(),
    );
    final formattedAmount = safeAmount.toStringAsFixed(2);
    final cleanNote = Uri.encodeComponent(
      (note != null && note.trim().isNotEmpty)
          ? note.trim()
          : (billNo != null && billNo.trim().isNotEmpty
              ? 'Bill ${billNo.trim()}'
              : 'POS Bill Payment'),
    );

    // Strictly alphanumeric TR for Google Pay & NPCI compatibility
    String? validTr;
    if (tr != null && tr.trim().isNotEmpty) {
      final sanitized = tr.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      if (sanitized.isNotEmpty) {
        validTr = sanitized.length > 35 ? sanitized.substring(0, 35) : sanitized;
      }
    } else if (billNo != null && billNo.trim().isNotEmpty) {
      final sanitized = billNo.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      if (sanitized.isNotEmpty) {
        validTr = sanitized.length > 35 ? sanitized.substring(0, 35) : sanitized;
      }
    }

    final buffer = StringBuffer(
      'upi://pay?pa=$cleanUpi&pn=$cleanName&am=$formattedAmount&cu=INR&tn=$cleanNote',
    );
    if (validTr != null && validTr.isNotEmpty) {
      buffer.write('&tr=$validTr');
    }
    return buffer.toString();
  }
}
