import 'dart:convert';
import 'dart:math' as math;
import 'cart_item.dart';
import '../../core/utils/payment_qr_helper.dart';

class Sale {
  static const String _metaPrefix = '__POS_META__';

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
  final double cashPaid;
  final double upiPaid;
  final double upiPayable;
  final double creditAmount;
  final bool onlineVerified;
  final String? verificationSource;
  final String? note;
  final DateTime createdAt;
  final String? clientRef;
  final int editCount;
  final DateTime? lastEditedAt;

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
    double? cashPaid,
    this.upiPaid = 0.0,
    this.upiPayable = 0.0,
    this.creditAmount = 0.0,
    this.onlineVerified = false,
    this.verificationSource,
    this.note,
    required this.createdAt,
    this.clientRef,
    this.editCount = 0,
    this.lastEditedAt,
  }) : cashPaid = cashPaid ??
            (paymentMode == 'cash' ? paid : 0.0);

  bool get isEdited => editCount > 0;
  String get editedTagText => editCount > 0 ? 'Edited ($editCount)' : '';

  /// Remaining UPI-only payable amount (strictly excludes Cash & Credit).
  double get effectiveUpiPayable {
    final mode = paymentMode.trim().toLowerCase();
    if (mode == 'online') {
      if (!onlineVerified || paymentStatus != 'completed' || due > 0.009) {
        if (upiPayable > 0.009) return upiPayable;
        return due > 0.009 ? due : total;
      }
      return 0.0;
    }
    if (mode == 'split') {
      if (!onlineVerified && upiPayable > 0.009) {
        return math.min(upiPayable, due > 0.009 ? due : upiPayable);
      }
      return 0.0;
    }
    return 0.0;
  }

  bool get isFullyPaidAndVerified =>
      paymentStatus == 'completed' &&
      due <= 0.009 &&
      effectiveUpiPayable <= 0.009 &&
      (paymentMode.trim().toLowerCase() != 'online' || onlineVerified);

  BillQrDecision resolveQr({
    required String? upiId,
    required String shopName,
    required String? googleReviewUrl,
  }) {
    return PaymentQrHelper.resolveBillQr(
      total: total,
      paid: paid,
      due: due,
      paymentMode: paymentMode,
      paymentStatus: paymentStatus,
      onlineVerified: onlineVerified,
      upiPayableAmount: effectiveUpiPayable,
      upiId: upiId,
      shopName: shopName,
      googleReviewUrl: googleReviewUrl,
      billNo: billNo > 0 ? '$billNo' : id,
    );
  }

  /// Structured payment metadata encoded into public.sales.note so existing
  /// Supabase RPCs persist breakdown, verification & remaining UPI state cleanly.
  String get encodedNote {
    final meta = <String, dynamic>{
      'ps': paymentStatus,
      'cp': PaymentQrHelper.round2(cashPaid),
      'up': PaymentQrHelper.round2(upiPaid),
      'upb': PaymentQrHelper.round2(upiPayable),
      'cr': PaymentQrHelper.round2(creditAmount),
      'ov': onlineVerified,
      if (verificationSource != null && verificationSource!.isNotEmpty)
        'vs': verificationSource,
      if (clientRef != null && clientRef!.isNotEmpty) 'cref': clientRef,
      if (editCount > 0) 'ec': editCount,
      if (lastEditedAt != null) 'lea': lastEditedAt!.toIso8601String(),
    };
    final metaJson = '$_metaPrefix${jsonEncode(meta)}';
    final cleanNote = _stripMetaFromNote(note);
    if (cleanNote != null && cleanNote.isNotEmpty) {
      return '$cleanNote\n$metaJson';
    }
    return metaJson;
  }

  static String? _stripMetaFromNote(String? rawNote) {
    if (rawNote == null) return null;
    final idx = rawNote.indexOf(_metaPrefix);
    if (idx == -1) return rawNote.trim();
    final before = rawNote.substring(0, idx).trim();
    return before.isEmpty ? null : before;
  }

  static Map<String, dynamic>? _parseMetaFromNote(String? rawNote) {
    if (rawNote == null) return null;
    final idx = rawNote.indexOf(_metaPrefix);
    if (idx == -1) return null;
    final jsonPart = rawNote.substring(idx + _metaPrefix.length).trim();
    try {
      final decoded = jsonDecode(jsonPart);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  factory Sale.fromJson(Map<String, dynamic> json) {
    List<CartItem> parsedItems = [];
    final rawItems = json['items'] ?? json['sale_items'];
    if (rawItems is List) {
      parsedItems = rawItems
          .map((item) => CartItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    final totalVal = (json['total'] as num?)?.toDouble() ?? 0.0;
    final paidVal = (json['paid'] as num?)?.toDouble() ?? 0.0;
    final dueVal = (json['due'] as num?)?.toDouble() ?? math.max(0.0, totalVal - paidVal);
    final mode = (json['payment_mode'] as String? ?? 'cash').trim().toLowerCase();
    final rawNote = json['note'] as String?;
    final meta = _parseMetaFromNote(rawNote);
    final cleanUserNote = _stripMetaFromNote(rawNote);

    final String status = (json['payment_status'] as String?) ??
        (meta?['ps'] as String?) ??
        (dueVal <= 0.009 ? 'completed' : 'pending');

    final bool hasExplicitBreak =
        meta != null || json.containsKey('online_verified') || json.containsKey('upi_payable');

    late final double cashPaid;
    late final double upiPaid;
    late final double upiPayable;
    late final double creditAmount;
    late final bool onlineVerified;
    late final String? verificationSource;

    if (hasExplicitBreak) {
      cashPaid = ((json['cash_paid'] ?? meta?['cp']) as num?)?.toDouble() ??
          (mode == 'cash' ? paidVal : 0.0);
      upiPaid = ((json['upi_paid'] ?? meta?['up']) as num?)?.toDouble() ?? 0.0;
      upiPayable = ((json['upi_payable'] ?? meta?['upb']) as num?)?.toDouble() ?? 0.0;
      creditAmount = ((json['credit_amount'] ?? meta?['cr']) as num?)?.toDouble() ??
          (mode == 'credit' ? dueVal : 0.0);
      onlineVerified = (json['online_verified'] as bool?) ??
          (meta?['ov'] as bool?) ??
          (mode == 'online' && status == 'completed' && dueVal <= 0.009);
      verificationSource = (json['verification_source'] ?? meta?['vs']) as String?;
    } else {
      // Legacy record compatibility (pre-v1.4.8 rows without __POS_META__)
      if (mode == 'cash') {
        cashPaid = paidVal;
        upiPaid = 0.0;
        upiPayable = 0.0;
        creditAmount = dueVal;
        onlineVerified = false;
        verificationSource = 'cash_drawer';
      } else if (mode == 'online') {
        final legacyPaidFull = status == 'completed' && dueVal <= 0.009;
        cashPaid = 0.0;
        upiPaid = legacyPaidFull ? paidVal : 0.0;
        upiPayable = legacyPaidFull ? 0.0 : (dueVal > 0.009 ? dueVal : totalVal);
        creditAmount = 0.0;
        onlineVerified = legacyPaidFull;
        verificationSource = legacyPaidFull ? 'legacy_completed' : 'unverified';
      } else if (mode == 'credit') {
        cashPaid = paidVal;
        upiPaid = 0.0;
        upiPayable = 0.0;
        creditAmount = dueVal > 0.009 ? dueVal : math.max(0.0, totalVal - paidVal);
        onlineVerified = false;
        verificationSource = 'khata_credit';
      } else {
        cashPaid = paidVal;
        upiPaid = 0.0;
        upiPayable = 0.0;
        creditAmount = dueVal;
        onlineVerified = dueVal <= 0.009;
        verificationSource = 'legacy_split';
      }
    }

    final rawEditedAt = (json['last_edited_at'] ?? meta?['lea']) as String?;
    DateTime parsedDate;
    if (json['created_at'] != null) {
      try {
        final rawStr = json['created_at'] as String;
        final parsed = DateTime.parse(rawStr).toLocal();
        final now = DateTime.now();
        // Auto-heal timezone bug: if a timestamp was saved with UTC shift causing it
        // to appear in the future (>5 mins ahead), correct the 5.5-hour IST offset!
        if (parsed.isAfter(now.add(const Duration(minutes: 5)))) {
          parsedDate = parsed.subtract(const Duration(hours: 5, minutes: 30));
        } else {
          parsedDate = parsed;
        }
      } catch (_) {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    return Sale(
      id: json['id'] as String,
      shopId: json['shop_id'] as String? ?? '',
      billNo: (json['bill_no'] as num?)?.toInt() ?? 0,
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      items: parsedItems,
      subtotal: ((json['subtotal'] ?? json['sub_total']) as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      total: totalVal,
      paid: paidVal,
      due: dueVal,
      paymentMode: mode,
      paymentStatus: status,
      cashPaid: cashPaid,
      upiPaid: upiPaid,
      upiPayable: upiPayable,
      creditAmount: creditAmount,
      onlineVerified: onlineVerified,
      verificationSource: verificationSource,
      note: cleanUserNote,
      createdAt: parsedDate,
      clientRef: (json['client_ref'] ?? meta?['cref']) as String?,
      editCount: (json['edit_count'] as num?)?.toInt() ??
          (meta?['ec'] as num?)?.toInt() ??
          0,
      lastEditedAt:
          rawEditedAt != null ? DateTime.tryParse(rawEditedAt)?.toLocal() : null,
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
      'cash_paid': cashPaid,
      'upi_paid': upiPaid,
      'upi_payable': upiPayable,
      'credit_amount': creditAmount,
      'online_verified': onlineVerified,
      if (verificationSource != null) 'verification_source': verificationSource,
      'note': encodedNote,
      'created_at': createdAt.toUtc().toIso8601String(),
      'client_ref': clientRef,
      'edit_count': editCount,
      if (lastEditedAt != null)
        'last_edited_at': lastEditedAt!.toUtc().toIso8601String(),
    };
  }

  Sale copyWith({
    String? id,
    String? shopId,
    int? billNo,
    String? customerId,
    String? customerName,
    String? customerPhone,
    List<CartItem>? items,
    double? subtotal,
    double? discount,
    double? total,
    double? paid,
    double? due,
    String? paymentMode,
    String? paymentStatus,
    double? cashPaid,
    double? upiPaid,
    double? upiPayable,
    double? creditAmount,
    bool? onlineVerified,
    String? verificationSource,
    String? note,
    DateTime? createdAt,
    String? clientRef,
    int? editCount,
    DateTime? lastEditedAt,
  }) {
    return Sale(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      billNo: billNo ?? this.billNo,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      paid: paid ?? this.paid,
      due: due ?? this.due,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      cashPaid: cashPaid ?? this.cashPaid,
      upiPaid: upiPaid ?? this.upiPaid,
      upiPayable: upiPayable ?? this.upiPayable,
      creditAmount: creditAmount ?? this.creditAmount,
      onlineVerified: onlineVerified ?? this.onlineVerified,
      verificationSource: verificationSource ?? this.verificationSource,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      clientRef: clientRef ?? this.clientRef,
      editCount: editCount ?? this.editCount,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
    );
  }
}
