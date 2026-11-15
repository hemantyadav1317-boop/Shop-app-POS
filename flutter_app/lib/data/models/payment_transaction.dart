class PaymentTransaction {
  final String id;
  final String shopId;
  final int billNo;
  final String clientRef;
  final String merchantTransactionId;
  final String? phonepeTransactionId;
  final double amount;
  final String currency;
  final String status; // 'PENDING', 'SUCCESS', 'FAILED', 'EXPIRED'
  final String paymentMode; // 'online', 'split'
  final String? qrData;
  final String? responseCode;
  final Map<String, dynamic>? rawResponse;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentTransaction({
    required this.id,
    required this.shopId,
    required this.billNo,
    required this.clientRef,
    required this.merchantTransactionId,
    this.phonepeTransactionId,
    required this.amount,
    this.currency = 'INR',
    this.status = 'PENDING',
    this.paymentMode = 'online',
    this.qrData,
    this.responseCode,
    this.rawResponse,
    this.verifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isSuccess => status.toUpperCase() == 'SUCCESS';
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isFailed => status.toUpperCase() == 'FAILED';
  bool get isExpired => status.toUpperCase() == 'EXPIRED';

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'] as String? ?? json['transaction_id'] as String? ?? '',
      shopId: json['shop_id'] as String? ?? '',
      billNo: (json['bill_no'] as num?)?.toInt() ?? 0,
      clientRef: json['client_ref'] as String? ?? '',
      merchantTransactionId: json['merchant_transaction_id'] as String? ?? '',
      phonepeTransactionId: json['phonepe_transaction_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'INR',
      status: json['status'] as String? ?? 'PENDING',
      paymentMode: json['payment_mode'] as String? ?? 'online',
      qrData: json['qr_data'] as String?,
      responseCode: json['response_code'] as String?,
      rawResponse: json['raw_response'] is Map<String, dynamic>
          ? json['raw_response'] as Map<String, dynamic>
          : null,
      verifiedAt: json['verified_at'] != null
          ? DateTime.tryParse(json['verified_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'bill_no': billNo,
      'client_ref': clientRef,
      'merchant_transaction_id': merchantTransactionId,
      'phonepe_transaction_id': phonepeTransactionId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'payment_mode': paymentMode,
      'qr_data': qrData,
      'response_code': responseCode,
      'raw_response': rawResponse,
      'verified_at': verifiedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
