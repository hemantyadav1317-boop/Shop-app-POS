class Product {
  final String id;
  final String shopId;
  final String name;
  final String? nameEn;
  final String? nameHi;
  final String category;
  final String? categoryId;
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
  final String? tag; // Product badge/batch (e.g. 'ताजा', 'बेस्टसेलर', 'New Arrival')
  final bool isActive;

  Product({
    required this.id,
    required this.shopId,
    required this.name,
    this.nameEn,
    this.nameHi,
    required this.category,
    this.categoryId,
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
    this.tag,
    this.isActive = true,
  });

  bool get isLowStock => stock <= lowStockAt;

  /// Returns localized product name based on current locale ('hi' or 'en').
  /// Eliminates bilingual parenthetical strings (e.g. "स्ट्रॉबेरी (Strawberry)").
  String localizedName([String localeCode = 'hi']) {
    final isEn = localeCode == 'en';
    if (isEn && nameEn != null && nameEn!.trim().isNotEmpty) {
      return nameEn!.trim();
    }
    if (!isEn && nameHi != null && nameHi!.trim().isNotEmpty) {
      return nameHi!.trim();
    }

    // Parse potential bilingual parenthetical: e.g. "स्ट्रॉबेरी (Strawberry)" or "Potato (आलू)"
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

  /// Returns localized category name for display.
  String localizedCategory([String localeCode = 'hi']) => localizeCategory(category, localeCode);

  /// Helper to convert standard category keys to localized representations.
  static String localizeCategory(String cat, [String localeCode = 'hi']) {
    final upper = cat.trim().toUpperCase();
    if (localeCode == 'en') {
      switch (upper) {
        case 'ALL': return 'All';
        case 'FRUITS': return 'Fruits';
        case 'VEGETABLES': return 'Vegetables';
        case 'GREEN VEGGIES': return 'Green Veggies';
        case 'KIRANA': case 'GROCERY': return 'Grocery';
        case 'DAIRY': return 'Dairy';
        case 'BEVERAGES': return 'Beverages';
        case 'SNACKS': return 'Snacks';
        case 'SPICES': return 'Spices';
        case 'GRAINS': return 'Grains';
        case 'PERSONAL CARE': return 'Personal Care';
        case 'CLEANING': return 'Cleaning';
        case 'BAKERY': return 'Bakery';
        default: return cat;
      }
    } else {
      switch (upper) {
        case 'ALL': return 'सभी';
        case 'FRUITS': return 'फल';
        case 'VEGETABLES': return 'सब्जियां';
        case 'GREEN VEGGIES': return 'हरी सब्जियां';
        case 'KIRANA': case 'GROCERY': return 'किराना';
        case 'DAIRY': return 'डेयरी';
        case 'BEVERAGES': return 'पेय पदार्थ';
        case 'SNACKS': return 'स्नैक्स';
        case 'SPICES': return 'मसाले';
        case 'GRAINS': return 'अनाज व दालें';
        case 'PERSONAL CARE': return 'पर्सनल केयर';
        case 'CLEANING': return 'सफाई सामग्री';
        case 'BAKERY': return 'बेकरी';
        default: return cat;
      }
    }
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    String? rawTag = json['tag'] as String? ?? json['badge'] as String? ?? json['batch'] as String?;
    String? rawSku = json['sku'] as String?;
    if ((rawTag == null || rawTag.isEmpty) && rawSku != null && rawSku.contains('TAG:')) {
      final parts = rawSku.split('TAG:');
      rawTag = parts.last.trim();
      rawSku = parts.first.replaceAll('|', '').trim();
      if (rawSku.isEmpty) rawSku = null;
    }

    return Product(
      id: json['id'] as String,
      shopId: json['shop_id'] as String? ?? '',
      name: json['name'] as String,
      nameEn: json['name_en'] as String?,
      nameHi: json['name_hi'] as String?,
      category: json['category'] as String? ?? 'General',
      categoryId: json['category_id'] as String?,
      unit: json['unit'] as String? ?? 'pc',
      price: (json['price'] as num?)?.toDouble() ?? (json['selling_price'] as num?)?.toDouble() ?? 0.0,
      purchasePrice: (json['cost_price'] as num?)?.toDouble() ?? (json['purchase_price'] as num?)?.toDouble(),
      mrp: (json['mrp'] as num?)?.toDouble(),
      stock: (json['stock'] as num?)?.toDouble() ?? (json['stock_quantity'] as num?)?.toDouble() ?? 0.0,
      lowStockAt: (json['low_stock_at'] as num?)?.toDouble() ?? (json['low_stock_threshold'] as num?)?.toDouble() ?? 5.0,
      barcode: json['barcode'] as String?,
      sku: rawSku,
      imageUrl: json['image_url'] as String?,
      icon: json['icon'] as String?,
      tag: rawTag,
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
      if (categoryId != null && categoryId!.isNotEmpty) 'category_id': categoryId,
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
      'tag': tag,
      'is_active': isActive,
    };
  }

  Map<String, dynamic> toSupabaseJson() {
    final isValidUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(id);
    final combinedSku = (tag != null && tag!.trim().isNotEmpty)
        ? ((sku != null && sku!.trim().isNotEmpty) ? '${sku!.trim()}|TAG:${tag!.trim()}' : 'TAG:${tag!.trim()}')
        : sku;

    return {
      if (isValidUuid) 'id': id,
      'shop_id': shopId,
      'name': name,
      if (nameEn != null && nameEn!.isNotEmpty) 'name_en': nameEn,
      if (nameHi != null && nameHi!.isNotEmpty) 'name_hi': nameHi,
      'category': category,
      if (categoryId != null && categoryId!.isNotEmpty) 'category_id': categoryId,
      'unit': (unit == 'kg') ? 'kg' : 'pc',
      'price': price,
      if (purchasePrice != null) 'cost_price': purchasePrice,
      'stock': stock,
      'low_stock_at': lowStockAt,
      if (barcode != null && barcode!.isNotEmpty) 'barcode': barcode,
      if (combinedSku != null && combinedSku.isNotEmpty) 'sku': combinedSku,
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
    String? categoryId,
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
    String? tag,
    bool? isActive,
  }) {
    return Product(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      nameHi: nameHi ?? this.nameHi,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
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
      tag: tag ?? this.tag,
      isActive: isActive ?? this.isActive,
    );
  }
}
