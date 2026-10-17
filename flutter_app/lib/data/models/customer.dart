class Customer {
  final String id;
  final String shopId;
  final String name;
  final String? phone;
  final String? address;
  final double balance; // Positive balance means customer owes money (Udhar)
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone,
    this.address,
    this.balance = 0.0,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      shopId: json['shop_id'] as String? ?? '',
      name: json['name'] as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'name': name,
      'phone': phone,
      'address': address,
      'balance': balance,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Customer copyWith({
    String? id,
    String? shopId,
    String? name,
    String? phone,
    String? address,
    double? balance,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
