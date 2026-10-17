class Product {
  final String id;
  final String shopId;
  final String name;
  final String? nameEn;
  final String? nameHi;
  final String category;
  final String unit; // 'kg', 'pc', 'g', 'litre', 'packet'
  final double price; // Selling price
  final double? purchasePrice;
  final double? mrp;
  final double stock;
  final double lowStockAt;
  final String? barcode;
  final String? sku;
  final String? imageUrl;
  final String? icon; // Emoji icon (e.g. 🍎, 🥔)
  final bool isActive;

  Product({
    required this.id,
    required this.shopId,
    required this.name,
    this.nameEn,
    this.nameHi,
    required this.category,
    required this.unit,
    required this.price,
    this.purchasePrice,
    this.mrp,
    this.stock = 0.0,
    this.lowStockAt = 5.0,
    this.barcode,
    this.sku,
    this.imageUrl,
    this.icon,
    this.isActive = true,
  });

  bool get isLowStock => stock <= lowStockAt;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      shopId: json['shop_id'] as String? ?? '',
      name: json['name'] as String,
      nameEn: json['name_en'] as String?,
      nameHi: json['name_hi'] as String?,
      category: json['category'] as String? ?? 'General',
      unit: json['unit'] as String? ?? 'pc',
      price: (json['price'] as num?)?.toDouble() ?? (json['selling_price'] as num?)?.toDouble() ?? 0.0,
      purchasePrice: (json['cost_price'] as num?)?.toDouble() ?? (json['purchase_price'] as num?)?.toDouble(),
      mrp: (json['mrp'] as num?)?.toDouble(),
      stock: (json['stock'] as num?)?.toDouble() ?? (json['stock_quantity'] as num?)?.toDouble() ?? 0.0,
      lowStockAt: (json['low_stock_at'] as num?)?.toDouble() ?? (json['low_stock_threshold'] as num?)?.toDouble() ?? 5.0,
      barcode: json['barcode'] as String?,
      sku: json['sku'] as String?,
      imageUrl: json['image_url'] as String?,
      icon: json['icon'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'name': name,
      'name_en': nameEn,
      'name_hi': nameHi,
      'category': category,
      'unit': unit,
      'price': price,
      'cost_price': purchasePrice,
      'purchase_price': purchasePrice,
      'mrp': mrp,
      'stock': stock,
      'stock_quantity': stock,
      'low_stock_at': lowStockAt,
      'low_stock_threshold': lowStockAt,
      'barcode': barcode,
      'sku': sku,
      'image_url': imageUrl,
      'icon': icon,
      'is_active': isActive,
    };
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'name': name,
      if (nameEn != null && nameEn!.isNotEmpty) 'name_en': nameEn,
      if (nameHi != null && nameHi!.isNotEmpty) 'name_hi': nameHi,
      'category': category,
      'unit': (unit == 'kg') ? 'kg' : 'pc',
      'price': price,
      if (purchasePrice != null) 'cost_price': purchasePrice,
      'stock': stock,
      'low_stock_at': lowStockAt,
      if (barcode != null && barcode!.isNotEmpty) 'barcode': barcode,
      if (sku != null && sku!.isNotEmpty) 'sku': sku,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
      'is_active': isActive,
    };
  }

  Product copyWith({
    String? id,
    String? shopId,
    String? name,
    String? nameEn,
    String? nameHi,
    String? category,
    String? unit,
    double? price,
    double? purchasePrice,
    double? mrp,
    double? stock,
    double? lowStockAt,
    String? barcode,
    String? sku,
    String? imageUrl,
    String? icon,
    bool? isActive,
  }) {
    return Product(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      nameHi: nameHi ?? this.nameHi,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      mrp: mrp ?? this.mrp,
      stock: stock ?? this.stock,
      lowStockAt: lowStockAt ?? this.lowStockAt,
      barcode: barcode ?? this.barcode,
      sku: sku ?? this.sku,
      imageUrl: imageUrl ?? this.imageUrl,
      icon: icon ?? this.icon,
      isActive: isActive ?? this.isActive,
    );
  }
}
