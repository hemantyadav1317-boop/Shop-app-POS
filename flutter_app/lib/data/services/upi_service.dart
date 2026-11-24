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
  ///         When [includeTr] is false, [tr] is omitted, ensuring Google Pay treats the QR as a direct
  ///         retail payment and never throws merchant gateway / reference errors.
  /// - [pa]: Valid, trimmed UPI ID.
  /// - [pn]: URL-encoded payee name (fallback to 'ShopPOS' if empty).
  /// - [am]: Formatted with exactly 2 decimal places.
  /// - [cu]: Strictly 'INR'.
  /// - [tn]: URL-encoded note (sanitized to remove fragment '#' and reserved characters).
  /// - Never include fake 'mc' or 'tid' for standard/personal VPAs to prevent Google Pay security blocks.
  static String generateUpiUri({
    required String upiId,
    required String payeeName,
    required double amount,
    String? note,
    String? billNo,
    String? tr,
    bool? includeTr,
  }) {
    if (!PaymentQrHelper.isValidUpiId(upiId)) return '';
    final safeAmount = PaymentQrHelper.round2(amount);
    if (safeAmount <= 0) return '';

    final cleanUpi = upiId.trim();
    // Sanitize payee name
    final sanitizedPayee = payeeName.trim().replaceAll(RegExp(r'[^\w\s\.-]'), '');
    final cleanName = Uri.encodeComponent(
      sanitizedPayee.isEmpty ? 'ShopPOS' : sanitizedPayee,
    );
    final formattedAmount = safeAmount.toStringAsFixed(2);

    // Sanitize note: NEVER include #, @, &, ?, =, _, or control characters
    // GPay and several UPI apps fail or treat # as a URL fragment delimiter
    final rawNote = (note != null && note.trim().isNotEmpty)
        ? note.trim()
        : (billNo != null && billNo.trim().isNotEmpty
            ? 'Bill ${billNo.trim()}'
            : 'POS Bill Payment');
    final sanitizedNote = rawNote
        .replaceAll(RegExp(r'[#@&?=_]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final cleanNote = Uri.encodeComponent(
      sanitizedNote.isEmpty ? 'Bill' : sanitizedNote,
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
    final shouldIncludeTr = includeTr ?? (tr != null || billNo != null);
    if (shouldIncludeTr && validTr != null && validTr.isNotEmpty) {
      buffer.write('&tr=$validTr');
    }
    return buffer.toString();
  }
}
