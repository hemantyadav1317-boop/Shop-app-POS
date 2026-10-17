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
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Meri Dukan POS',
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      gstin: json['gstin'] as String?,
      upiId: json['upi_id'] as String?,
      upiPayeeName: json['upi_payee_name'] as String?,
      allowNegativeStock: json['allow_negative_stock'] as bool? ?? false,
      printPaperSize: json['print_paper_size'] as String? ?? '58mm',
      receiptFooter: json['receipt_footer'] as String? ?? 'धन्यवाद! फिर पधारें 🙏',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'gstin': gstin,
      'upi_id': upiId,
      'upi_payee_name': upiPayeeName,
      'allow_negative_stock': allowNegativeStock,
      'print_paper_size': printPaperSize,
      'receipt_footer': receiptFooter,
    };
  }

  Shop copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? gstin,
    String? upiId,
    String? upiPayeeName,
    bool? allowNegativeStock,
    String? printPaperSize,
    String? receiptFooter,
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      upiId: upiId ?? this.upiId,
      upiPayeeName: upiPayeeName ?? this.upiPayeeName,
      allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
      printPaperSize: printPaperSize ?? this.printPaperSize,
      receiptFooter: receiptFooter ?? this.receiptFooter,
    );
  }
}
