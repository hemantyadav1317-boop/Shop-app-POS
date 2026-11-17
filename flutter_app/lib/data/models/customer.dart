class Customer {
  final String id;
  final String shopId;
  final String name;
  final String? phone;
  final String? address;
  final double balance; // Positive balance means customer owes money (Udhar)
  final double creditLimit; // 0.0 means no limit; >0 enforces max credit limit
  final DateTime createdAt;
  final String? email;
  final String? gstNo;
  final String? gender;
  final String? dob;

  Customer({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone,
    this.address,
    this.balance = 0.0,
    this.creditLimit = 0.0,
    required this.createdAt,
    this.email,
    this.gstNo,
    this.gender,
    this.dob,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      shopId: json['shop_id'] as String? ?? '',
      name: json['name'] as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      email: json['email'] as String?,
      gstNo: (json['gst_no'] ?? json['gstNo']) as String?,
      gender: json['gender'] as String?,
      dob: json['dob'] as String?,
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
      'credit_limit': creditLimit,
      'created_at': createdAt.toIso8601String(),
      if (email != null) 'email': email,
      if (gstNo != null) 'gst_no': gstNo,
      if (gender != null) 'gender': gender,
      if (dob != null) 'dob': dob,
    };
  }

  Map<String, dynamic> toSupabaseJson() {
    final isValidUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(id);
    return {
      if (isValidUuid) 'id': id,
      'shop_id': shopId,
      'name': name,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      if (address != null && address!.isNotEmpty) 'address': address,
      'balance': balance,
      'credit_limit': creditLimit,
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
    double? creditLimit,
    DateTime? createdAt,
    String? email,
    String? gstNo,
    String? gender,
    String? dob,
  }) {
    return Customer(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      balance: balance ?? this.balance,
      creditLimit: creditLimit ?? this.creditLimit,
      createdAt: createdAt ?? this.createdAt,
      email: email ?? this.email,
      gstNo: gstNo ?? this.gstNo,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
    );
  }
}
