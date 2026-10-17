class CartItem {
  final String? productId; // Null for Quick Sell one-off items
  final String name;
  final String unit; // 'kg', 'pc', etc.
  final double price; // Rate per unit
  final double qty;
  final String? imageUrl;
  final String? icon;

  CartItem({
    this.productId,
    required this.name,
    required this.unit,
    required this.price,
    required this.qty,
    this.imageUrl,
    this.icon,
  });

  double get total => price * qty;

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId ?? '',
      'name': name,
      'unit': unit,
      'price': price,
      'qty': qty,
      'image_url': imageUrl,
      'icon': icon,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['product_id'] as String?,
      name: json['name'] as String,
      unit: json['unit'] as String? ?? 'pc',
      price: (json['price'] as num).toDouble(),
      qty: (json['qty'] as num).toDouble(),
      imageUrl: json['image_url'] as String?,
      icon: json['icon'] as String?,
    );
  }

  CartItem copyWith({
    String? productId,
    String? name,
    String? unit,
    double? price,
    double? qty,
    String? imageUrl,
    String? icon,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      imageUrl: imageUrl ?? this.imageUrl,
      icon: icon ?? this.icon,
    );
  }
}

