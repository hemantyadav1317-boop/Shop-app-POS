import '../../core/utils/payment_qr_helper.dart';

class UpiService {
  /// Validates a UPI VPA string (e.g., name@bank)
  static bool isValidUpiId(String? upiId) =>
      PaymentQrHelper.isValidUpiId(upiId);

  /// Generates a valid NPCI UPI intent URI for Indian payment apps
  static String generateUpiUri({
    required String upiId,
    required String payeeName,
    required double amount,
    String? note,
    String? billNo,
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

    final buffer = StringBuffer(
      'upi://pay?pa=$cleanUpi&pn=$cleanName&am=$formattedAmount&cu=INR&tn=$cleanNote',
    );
    if (billNo != null && billNo.trim().isNotEmpty) {
      buffer.write('&tr=${Uri.encodeComponent(billNo.trim())}');
    }
    return buffer.toString();
  }
}
