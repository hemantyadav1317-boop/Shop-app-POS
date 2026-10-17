import 'cart_item.dart';

class Sale {
  final String id;
  final String shopId;
  final int billNo;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final List<CartItem> items;
  final double subtotal;
  final double discount;
  final double total;
  final double paid;
  final double due;
  final String paymentMode; // 'cash', 'online', 'credit', 'split'
  final String paymentStatus; // 'completed', 'pending'
  final DateTime createdAt;
  final String? clientRef;

  Sale({
    required this.id,
    required this.shopId,
    required this.billNo,
    this.customerId,
    this.customerName,
    this.customerPhone,
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    required this.total,
    required this.paid,
    this.due = 0.0,
    required this.paymentMode,
    this.paymentStatus = 'completed',
    required this.createdAt,
    this.clientRef,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    List<CartItem> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((item) => CartItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    return Sale(
      id: json['id'] as String,
      shopId: json['shop_id'] as String? ?? '',
      billNo: (json['bill_no'] as num?)?.toInt() ?? 0,
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      items: parsedItems,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      paid: (json['paid'] as num?)?.toDouble() ?? 0.0,
      due: (json['due'] as num?)?.toDouble() ?? 0.0,
      paymentMode: json['payment_mode'] as String? ?? 'cash',
      paymentStatus: json['payment_status'] as String? ?? 'completed',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      clientRef: json['client_ref'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'bill_no': billNo,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'items': items.map((e) => e.toJson()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'paid': paid,
      'due': due,
      'payment_mode': paymentMode,
      'payment_status': paymentStatus,
      'created_at': createdAt.toIso8601String(),
      'client_ref': clientRef,
    };
  }
}
