class CartItem {
  final String? productId; // Null for Quick Sell one-off items
  final String name;
  final String? nameEn;
  final String? nameHi;
  final String unit; // 'kg', 'pc', etc.
  final double price; // Rate per unit
  final double qty;
  final String? imageUrl;
  final String? icon;

  CartItem({
    this.productId,
    required this.name,
    this.nameEn,
    this.nameHi,
    required this.unit,
    required this.price,
    required this.qty,
    this.imageUrl,
    this.icon,
  });

  double get total => price * qty;

  /// Returns localized item name based on current locale ('hi' or 'en').
  /// Eliminates bilingual parenthetical strings (e.g. "स्ट्रॉबेरी (Strawberry)").
  String localizedName([String localeCode = 'hi']) {
    final isEn = localeCode == 'en';
    if (isEn && nameEn != null && nameEn!.trim().isNotEmpty) {
      return nameEn!.trim();
    }
    if (!isEn && nameHi != null && nameHi!.trim().isNotEmpty) {
      return nameHi!.trim();
    }

    final parenMatch = RegExp(r'^(.*?)\s*\((.*?)\)\s*$').firstMatch(name);
    if (parenMatch != null) {
      final part1 = parenMatch.group(1)?.trim() ?? '';
      final part2 = parenMatch.group(2)?.trim() ?? '';

      final part1HasHindi = RegExp(r'[\u0900-\u097F]').hasMatch(part1);
      final part2HasHindi = RegExp(r'[\u0900-\u097F]').hasMatch(part2);

      if (isEn) {
        if (!part2HasHindi && part2.isNotEmpty) return part2;
        if (!part1HasHindi && part1.isNotEmpty) return part1;
      } else {
        if (part1HasHindi && part1.isNotEmpty) return part1;
        if (part2HasHindi && part2.isNotEmpty) return part2;
      }
    }

    return name;
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId ?? '',
      'name': name,
      if (nameEn != null && nameEn!.isNotEmpty) 'name_en': nameEn,
      if (nameHi != null && nameHi!.isNotEmpty) 'name_hi': nameHi,
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
      nameEn: json['name_en'] as String?,
      nameHi: json['name_hi'] as String?,
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
    String? nameEn,
    String? nameHi,
    String? unit,
    double? price,
    double? qty,
    String? imageUrl,
    String? icon,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      nameHi: nameHi ?? this.nameHi,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      imageUrl: imageUrl ?? this.imageUrl,
      icon: icon ?? this.icon,
    );
  }
}

