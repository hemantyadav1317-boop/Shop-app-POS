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
  final String? shareCode; // 6-digit unique shop sharing code (e.g. '749201')

  bool get isKiranaMode => storeType == 'kirana';
  bool get isVegetableMode => storeType == 'vegetable';
  bool get isOtherMode => storeType == 'other';

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
    this.shareCode,
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
      shareCode: (json['share_code'] ?? json['shareCode']) as String?,
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
      if (shareCode != null) 'share_code': shareCode,
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
    String? shareCode,
    bool clearShareCode = false,
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
      shareCode: clearShareCode ? null : (shareCode ?? this.shareCode),
    );
  }
}
