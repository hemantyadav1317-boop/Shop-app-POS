class Expense {
  final String id;
  final String shopId;
  final String category;
  final double amount;
  final String? note;
  final DateTime spentOn;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.shopId,
    required this.category,
    required this.amount,
    this.note,
    required this.spentOn,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      shopId: json['shop_id'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      note: json['note'] as String?,
      spentOn: json['spent_on'] != null 
          ? DateTime.parse(json['spent_on'] as String) 
          : DateTime.now(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'category': category,
      'amount': amount,
      'note': note,
      'spent_on': spentOn.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
