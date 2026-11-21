import '../../core/localization/multilingual_catalog.dart';

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

  /// Returns localized product name based on current locale.
  /// Eliminates bilingual parenthetical strings (e.g. "स्ट्रॉबेरी (Strawberry)").
  /// Supports all 9 native Indian languages via MultilingualCatalog.
  String localizedName([String localeCode = 'hi']) {
    // 1. Check MultilingualCatalog for native regional produce name (en, hi, mr, gu, bn, pa, ta, te, kn)
    final regional = MultilingualCatalog.lookup(name, localeCode, nameEn: nameEn, nameHi: nameHi);
    if (regional != null && regional.isNotEmpty) {
      return regional;
    }

    final isEn = localeCode == 'en';
    if (isEn && nameEn != null && nameEn!.trim().isNotEmpty) {
      return nameEn!.trim();
    }
    if ((localeCode == 'hi' || localeCode == 'mr') && nameHi != null && nameHi!.trim().isNotEmpty) {
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
      } else if (localeCode == 'hi' || localeCode == 'mr') {
        if (part1HasHindi && part1.isNotEmpty) return part1;
        if (part2HasHindi && part2.isNotEmpty) return part2;
      } else {
        // For other regional languages, prefer clean English or clean script name
        if (!part2HasHindi && part2.isNotEmpty) return part2;
        if (!part1HasHindi && part1.isNotEmpty) return part1;
        if (part1HasHindi && part1.isNotEmpty) return part1;
      }
    }

    if (localeCode != 'hi' && localeCode != 'mr' && nameEn != null && nameEn!.isNotEmpty) {
      return nameEn!;
    }

    return name;
  }

  /// Returns localized category name for display.
  String localizedCategory([String localeCode = 'hi']) => localizeCategory(category, localeCode);

  /// Helper to convert standard category keys to localized representations across 9 Indian languages.
  static String localizeCategory(String cat, [String localeCode = 'hi']) {
    final upper = cat.trim().toUpperCase();
    switch (localeCode) {
      case 'en':
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
      case 'mr':
        switch (upper) {
          case 'ALL': return 'सर्व';
          case 'FRUITS': return 'फळे';
          case 'VEGETABLES': return 'भाज्या';
          case 'GREEN VEGGIES': return 'हिरव्या भाज्या';
          case 'KIRANA': case 'GROCERY': return 'किराणा';
          case 'DAIRY': return 'दुग्ध व्यवसाय';
          case 'BEVERAGES': return 'पेये';
          case 'SNACKS': return 'नाश्ता';
          case 'SPICES': return 'मसाले';
          case 'GRAINS': return 'धान्य व डाळी';
          case 'PERSONAL CARE': return 'वैयक्तिक काळजी';
          case 'CLEANING': return 'स्वच्छता साहित्य';
          case 'BAKERY': return 'बेकरी';
          default: return cat;
        }
      case 'gu':
        switch (upper) {
          case 'ALL': return 'બધા';
          case 'FRUITS': return 'ફળો';
          case 'VEGETABLES': return 'શાકભાજી';
          case 'GREEN VEGGIES': return 'લીલા શાકભાજી';
          case 'KIRANA': case 'GROCERY': return 'કરિયાણું';
          case 'DAIRY': return 'ડેરી';
          case 'BEVERAGES': return 'પીણાં';
          case 'SNACKS': return 'નાસ્તો';
          case 'SPICES': return 'મસાલા';
          case 'GRAINS': return 'અનાજ અને કઠોળ';
          case 'PERSONAL CARE': return 'પર્સનલ કેર';
          case 'CLEANING': return 'સફાઈ સામગ્રી';
          case 'BAKERY': return 'બેકરી';
          default: return cat;
        }
      case 'bn':
        switch (upper) {
          case 'ALL': return 'সব';
          case 'FRUITS': return 'ফলমূল';
          case 'VEGETABLES': return 'শাকসবজি';
          case 'GREEN VEGGIES': return 'সবুজ শাকসবজি';
          case 'KIRANA': case 'GROCERY': return 'মুদিখানা';
          case 'DAIRY': return 'দুগ্ধজাত';
          case 'BEVERAGES': return 'পানীয়';
          case 'SNACKS': return 'জলখাবার';
          case 'SPICES': return 'মশলা';
          case 'GRAINS': return 'দানাশস্য ও ডাল';
          case 'PERSONAL CARE': return 'ব্যক্তিগত যত্ন';
          case 'CLEANING': return 'পরিষ্কারের সামগ্রী';
          case 'BAKERY': return 'বেকারি';
          default: return cat;
        }
      case 'pa':
        switch (upper) {
          case 'ALL': return 'ਸਾਰੇ';
          case 'FRUITS': return 'ਫਲ';
          case 'VEGETABLES': return 'ਸਬਜ਼ੀਆਂ';
          case 'GREEN VEGGIES': return 'ਹਰੀਆਂ ਸਬਜ਼ੀਆਂ';
          case 'KIRANA': case 'GROCERY': return 'ਕਰਿਆਨਾ';
          case 'DAIRY': return 'ਡੇਅਰੀ';
          case 'BEVERAGES': return 'ਪੀਣ ਵਾਲੇ ਪਦਾਰਥ';
          case 'SNACKS': return 'ਨਾਸ਼ਤਾ';
          case 'SPICES': return 'ਮਸਾਲੇ';
          case 'GRAINS': return 'ਅਨਾਜ ਅਤੇ ਦਾਲਾਂ';
          case 'PERSONAL CARE': return 'ਨਿੱਜੀ ਦੇਖਭਾਲ';
          case 'CLEANING': return 'ਸਫਾਈ ਸਮੱਗਰੀ';
          case 'BAKERY': return 'ਬੇਕਰੀ';
          default: return cat;
        }
      case 'ta':
        switch (upper) {
          case 'ALL': return 'அனைத்தும்';
          case 'FRUITS': return 'பழங்கள்';
          case 'VEGETABLES': return 'காய்கறிகள்';
          case 'GREEN VEGGIES': return 'பச்சை காய்கறிகள்';
          case 'KIRANA': case 'GROCERY': return 'மளிகை';
          case 'DAIRY': return 'பால் பொருட்கள்';
          case 'BEVERAGES': return 'பானங்கள்';
          case 'SNACKS': return 'சிற்றுண்டி';
          case 'SPICES': return 'மசாலா';
          case 'GRAINS': return 'தானியங்கள் மற்றும் பருப்பு';
          case 'PERSONAL CARE': return 'தனிநபர் பராமரிப்பு';
          case 'CLEANING': return 'சுத்தம் செய்யும் பொருட்கள்';
          case 'BAKERY': return 'பேக்கரி';
          default: return cat;
        }
      case 'te':
        switch (upper) {
          case 'ALL': return 'అన్నీ';
          case 'FRUITS': return 'పండ్లు';
          case 'VEGETABLES': return 'కూరగాయలు';
          case 'GREEN VEGGIES': return 'ఆకుకూరలు';
          case 'KIRANA': case 'GROCERY': return 'కిరాణా';
          case 'DAIRY': return 'డైరీ';
          case 'BEVERAGES': return 'పానీయాలు';
          case 'SNACKS': return 'స్నాక్స్';
          case 'SPICES': return 'మసాలాలు';
          case 'GRAINS': return 'ధాన్యాలు మరియు పప్పులు';
          case 'PERSONAL CARE': return 'వ్యక్తిగత సంరక్షణ';
          case 'CLEANING': return 'శుభ్రపరిచే వస్తువులు';
          case 'BAKERY': return 'బేకరీ';
          default: return cat;
        }
      case 'kn':
        switch (upper) {
          case 'ALL': return 'ಎಲ್ಲಾ';
          case 'FRUITS': return 'ಹಣ್ಣುಗಳು';
          case 'VEGETABLES': return 'ತರಕಾರಿಗಳು';
          case 'GREEN VEGGIES': return 'ಹಸಿರು ತರಕಾರಿಗಳು';
          case 'KIRANA': case 'GROCERY': return 'ಕಿರಾಣಿ';
          case 'DAIRY': return 'ಡೈರಿ';
          case 'BEVERAGES': return 'ಪಾನೀಯಗಳು';
          case 'SNACKS': return 'ತಿಂಡಿಗಳು';
          case 'SPICES': return 'ಮಸಾಲೆಗಳು';
          case 'GRAINS': return 'ಧಾನ್ಯಗಳು ಮತ್ತು ಬೇಳೆಕಾಳುಗಳು';
          case 'PERSONAL CARE': return 'ವೈಯಕ್ತಿಕ ಆರೈಕೆ';
          case 'CLEANING': return 'ಸ್ವಚ್ಛತೆ ಸಾಮಗ್ರಿಗಳು';
          case 'BAKERY': return 'ಬೇಕರಿ';
          default: return cat;
        }
      case 'hi':
      default:
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
