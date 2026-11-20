class Shop {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? gstin;
  final String? upiId; // For Dynamic UPI QR
  final String? upiPayeeName;
  final bool allowNegativeStock;
  final String printPaperSize; // '58mm', '80mm'
  final String? receiptFooter;
  final String? qrImageUrl; // Custom Standee QR Image URL or path
  final String storeType; // 'vegetable', 'kirana', 'mix', 'other'
  final List<String> hybridModules; // Additional enabled modules, e.g. ['kirana', 'dairy']
  final String? shareCode; // 6-digit unique shop sharing code (e.g. '749201')
  final String? googleReviewUrl; // Real Google Maps Review URL for post-payment bill QR
  final bool phonePeEnabled;
  final String? phonePeMerchantId;
  final String? phonePeMobileNumber;
  final String? phonePeStoreName;
  final String phonePeEnvironment; // 'sandbox', 'production'
  final DateTime? phonePeConnectedAt;

  bool get isKiranaMode => storeType == 'kirana';
  bool get isVegetableMode => storeType == 'vegetable';
  bool get isOtherMode => storeType == 'other';

  /// Whether this business includes Grocery / FMCG (either primary or hybrid)
  bool get hasGroceryOrFmcg {
    if (storeType == 'kirana' || storeType == 'mix' || storeType.contains('kirana')) return true;
    return hybridModules.contains('kirana');
  }

  /// Whether this business includes Vegetables / Produce (either primary or hybrid)
  bool get hasVegetableOrProduce {
    if (storeType == 'vegetable' || storeType == 'mix' || storeType.contains('vegetable')) return true;
    return hybridModules.contains('vegetable');
  }

  /// Whether this business includes Dairy (either primary or hybrid)
  bool get hasDairy {
    if (storeType == 'dairy' || storeType.contains('dairy')) return true;
    return hybridModules.contains('dairy');
  }

  /// Barcode support is strictly active IF AND ONLY IF Grocery/FMCG is part of the business!
  bool get hasBarcodeSupport => hasGroceryOrFmcg;

  /// Electronic Weighing Scale is active if Vegetables/Produce is part of the business!
  bool get hasScaleSupport => hasVegetableOrProduce;

  /// Guaranteed 6-digit share code (either persisted or deterministic from shop ID)
  String get displayShareCode {
    if (shareCode != null && shareCode!.trim().length == 6) {
      return shareCode!.trim();
    }
    // Fallback: 6-digit numeric hash from shop ID
    final codeNum = (id.hashCode.abs() % 900000) + 100000;
    return codeNum.toString();
  }

  Shop({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.gstin,
    this.upiId,
    this.upiPayeeName,
    this.allowNegativeStock = false,
    this.printPaperSize = '58mm',
    this.receiptFooter = 'धन्यवाद! फिर पधारें 🙏',
    this.qrImageUrl,
    this.storeType = 'vegetable',
    this.hybridModules = const [],
    this.shareCode,
    this.googleReviewUrl,
    this.phonePeEnabled = false,
    this.phonePeMerchantId,
    this.phonePeMobileNumber,
    this.phonePeStoreName,
    this.phonePeEnvironment = 'sandbox',
    this.phonePeConnectedAt,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'] as String? ?? 'demo-shop-101',
      name: json['name'] as String? ?? 'Meri Dukan POS',
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      gstin: (json['gstin'] ?? json['gst_number']) as String?,
      upiId: json['upi_id'] as String?,
      upiPayeeName: json['upi_payee_name'] as String?,
      allowNegativeStock: json['allow_negative_stock'] as bool? ?? false,
      printPaperSize: json['print_paper_size'] as String? ?? '58mm',
      receiptFooter: json['receipt_footer'] as String? ?? 'धन्यवाद! फिर पधारें 🙏',
      qrImageUrl: json['qr_image_url'] as String?,
      storeType: json['store_type'] as String? ?? 'vegetable',
      hybridModules: json['hybrid_modules'] is List
          ? List<String>.from(json['hybrid_modules'] as List)
          : const [],
      shareCode: (json['share_code'] ?? json['shareCode']) as String?,
      googleReviewUrl: (json['google_review_url'] ?? json['googleReviewUrl']) as String?,
      phonePeEnabled: json['phonepe_enabled'] as bool? ?? json['phonePeEnabled'] as bool? ?? false,
      phonePeMerchantId: (json['phonepe_merchant_id'] ?? json['phonePeMerchantId']) as String?,
      phonePeMobileNumber: (json['phonepe_mobile_number'] ?? json['phonePeMobileNumber']) as String?,
      phonePeStoreName: (json['phonepe_store_name'] ?? json['phonePeStoreName']) as String?,
      phonePeEnvironment: (json['phonepe_environment'] ?? json['phonePeEnvironment']) as String? ?? 'sandbox',
      phonePeConnectedAt: json['phonepe_connected_at'] != null
          ? DateTime.tryParse(json['phonepe_connected_at'].toString())
          : (json['phonePeConnectedAt'] != null
              ? DateTime.tryParse(json['phonePeConnectedAt'].toString())
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'gstin': gstin,
      'gst_number': gstin,
      'upi_id': upiId,
      'upi_payee_name': upiPayeeName,
      'allow_negative_stock': allowNegativeStock,
      'print_paper_size': printPaperSize,
      'receipt_footer': receiptFooter,
      if (qrImageUrl != null) 'qr_image_url': qrImageUrl,
      'store_type': storeType,
      if (hybridModules.isNotEmpty) 'hybrid_modules': hybridModules,
      if (shareCode != null) 'share_code': shareCode,
      if (googleReviewUrl != null) 'google_review_url': googleReviewUrl,
      'phonepe_enabled': phonePeEnabled,
      if (phonePeMerchantId != null) 'phonepe_merchant_id': phonePeMerchantId,
      if (phonePeMobileNumber != null) 'phonepe_mobile_number': phonePeMobileNumber,
      if (phonePeStoreName != null) 'phonepe_store_name': phonePeStoreName,
      'phonepe_environment': phonePeEnvironment,
      if (phonePeConnectedAt != null) 'phonepe_connected_at': phonePeConnectedAt!.toUtc().toIso8601String(),
    };
  }

  Shop copyWith({
    String? id,
    String? name,
    String? phone,
    bool clearPhone = false,
    String? address,
    bool clearAddress = false,
    String? gstin,
    bool clearGstin = false,
    String? upiId,
    bool clearUpiId = false,
    String? upiPayeeName,
    bool clearUpiPayeeName = false,
    bool? allowNegativeStock,
    String? printPaperSize,
    String? receiptFooter,
    String? qrImageUrl,
    bool clearQrImageUrl = false,
    String? storeType,
    List<String>? hybridModules,
    String? shareCode,
    bool clearShareCode = false,
    String? googleReviewUrl,
    bool clearGoogleReviewUrl = false,
    bool? phonePeEnabled,
    String? phonePeMerchantId,
    bool clearPhonePeMerchantId = false,
    String? phonePeMobileNumber,
    bool clearPhonePeMobileNumber = false,
    String? phonePeStoreName,
    bool clearPhonePeStoreName = false,
    String? phonePeEnvironment,
    DateTime? phonePeConnectedAt,
    bool clearPhonePeConnectedAt = false,
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: clearPhone ? null : (phone ?? this.phone),
      address: clearAddress ? null : (address ?? this.address),
      gstin: clearGstin ? null : (gstin ?? this.gstin),
      upiId: clearUpiId ? null : (upiId ?? this.upiId),
      upiPayeeName: clearUpiPayeeName ? null : (upiPayeeName ?? this.upiPayeeName),
      allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
      printPaperSize: printPaperSize ?? this.printPaperSize,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      qrImageUrl: clearQrImageUrl ? null : (qrImageUrl ?? this.qrImageUrl),
      storeType: storeType ?? this.storeType,
      hybridModules: hybridModules ?? this.hybridModules,
      shareCode: clearShareCode ? null : (shareCode ?? this.shareCode),
      googleReviewUrl: clearGoogleReviewUrl ? null : (googleReviewUrl ?? this.googleReviewUrl),
      phonePeEnabled: phonePeEnabled ?? this.phonePeEnabled,
      phonePeMerchantId: clearPhonePeMerchantId ? null : (phonePeMerchantId ?? this.phonePeMerchantId),
      phonePeMobileNumber: clearPhonePeMobileNumber ? null : (phonePeMobileNumber ?? this.phonePeMobileNumber),
      phonePeStoreName: clearPhonePeStoreName ? null : (phonePeStoreName ?? this.phonePeStoreName),
      phonePeEnvironment: phonePeEnvironment ?? this.phonePeEnvironment,
      phonePeConnectedAt: clearPhonePeConnectedAt ? null : (phonePeConnectedAt ?? this.phonePeConnectedAt),
    );
  }
}
