class StockAdjustment {
  final String id;
  final String shopId;
  final String productId;
  final String productName;
  final double previousStock;
  final double newStock;
  final double changeQuantity; // e.g. -2.0 or +5.0
  final String adjustmentType; // 'audit', 'damage', 'waste', 'restock', 'correction'
  final String? reason;
  final DateTime createdAt;

  StockAdjustment({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.productName,
    required this.previousStock,
    required this.newStock,
    required this.changeQuantity,
    required this.adjustmentType,
    this.reason,
    required this.createdAt,
  });

  factory StockAdjustment.fromJson(Map<String, dynamic> json) {
    return StockAdjustment(
      id: json['id'] as String,
      shopId: json['shop_id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      previousStock: (json['previous_stock'] as num?)?.toDouble() ?? 0.0,
      newStock: (json['new_stock'] as num?)?.toDouble() ?? 0.0,
      changeQuantity: (json['change_quantity'] as num?)?.toDouble() ?? 0.0,
      adjustmentType: json['adjustment_type'] as String? ?? 'audit',
      reason: json['reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'product_id': productId,
      'product_name': productName,
      'previous_stock': previousStock,
      'new_stock': newStock,
      'change_quantity': changeQuantity,
      'adjustment_type': adjustmentType,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get typeLabelHindi {
    switch (adjustmentType.toLowerCase()) {
      case 'damage':
        return 'टूटा / खराब माल';
      case 'waste':
        return 'खराब / एक्सपायर';
      case 'restock':
        return 'नया माल आया (Restock)';
      case 'correction':
        return 'मैन्युअल सुधार';
      case 'audit':
      default:
        return 'भौतिक ऑडिट (Audit)';
    }
  }
}

