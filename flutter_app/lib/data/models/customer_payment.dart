class CustomerPayment {
  final String id;
  final String shopId;
  final String? saleId;
  final String customerId;
  final double amount;
  final String mode; // 'cash', 'upi', 'card'
  final String? note;
  final DateTime createdAt;

  CustomerPayment({
    required this.id,
    required this.shopId,
    this.saleId,
    required this.customerId,
    required this.amount,
    this.mode = 'cash',
    this.note,
    required this.createdAt,
  });

  factory CustomerPayment.fromJson(Map<String, dynamic> json) {
    return CustomerPayment(
      id: json['id'] as String,
      shopId: json['shop_id'] as String? ?? '',
      saleId: json['sale_id'] as String?,
      customerId: json['customer_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      mode: json['mode'] as String? ?? 'cash',
      note: json['note'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      if (saleId != null) 'sale_id': saleId,
      'customer_id': customerId,
      'amount': amount,
      'mode': mode,
      if (note != null) 'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'shop_id': shopId,
      if (saleId != null) 'sale_id': saleId,
      'customer_id': customerId,
      'amount': amount,
      'mode': mode,
      if (note != null) 'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

