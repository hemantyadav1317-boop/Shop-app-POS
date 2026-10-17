class UpiService {
  /// Generates a valid NPCI UPI intent URI for Indian payment apps
  static String generateUpiUri({
    required String upiId,
    required String payeeName,
    required double amount,
    String? note,
  }) {
    final cleanUpi = upiId.trim();
    final cleanName = Uri.encodeComponent(payeeName.trim());
    final formattedAmount = amount.toStringAsFixed(2);
    final cleanNote = Uri.encodeComponent(note ?? 'POS Bill Payment');

    return 'upi://pay?pa=$cleanUpi&pn=$cleanName&am=$formattedAmount&cu=INR&tn=$cleanNote';
  }
}
