class CustomerLedgerEntry {
  final String id;
  final String shopId;
  final String customerId;
  final String entryType; // 'opening_balance', 'credit_sale', 'payment', 'return', 'adjustment'
  final double amount;
  final double balanceAfter;
  final String? saleId;
  final String? paymentId;
  final String? note;
  final String? createdBy;
  final DateTime createdAt;

  const CustomerLedgerEntry({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.entryType,
    required this.amount,
    required this.balanceAfter,
    this.saleId,
    this.paymentId,
    this.note,
    this.createdBy,
    required this.createdAt,
  });

  factory CustomerLedgerEntry.fromJson(Map<String, dynamic> json) {
    return CustomerLedgerEntry(
      id: json['id'] as String? ?? '',
      shopId: json['shop_id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      entryType: json['entry_type'] as String? ?? 'payment',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balance_after'] as num?)?.toDouble() ?? 0.0,
      saleId: json['sale_id'] as String?,
      paymentId: json['payment_id'] as String?,
      note: json['note'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'customer_id': customerId,
      'entry_type': entryType,
      'amount': amount,
      'balance_after': balanceAfter,
      'sale_id': saleId,
      'payment_id': paymentId,
      'note': note,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabaseJson() {
    final isValidUuid = RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(id);
    return {
      if (isValidUuid) 'id': id,
      'shop_id': shopId,
      'customer_id': customerId,
      'entry_type': entryType,
      'amount': amount,
      'balance_after': balanceAfter,
      if (saleId != null && saleId!.isNotEmpty) 'sale_id': saleId,
      if (paymentId != null && paymentId!.isNotEmpty) 'payment_id': paymentId,
      if (note != null && note!.isNotEmpty) 'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
