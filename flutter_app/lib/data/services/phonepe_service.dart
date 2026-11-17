import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/payment_qr_helper.dart';
import '../models/payment_transaction.dart';
import '../models/shop.dart';
import 'supabase_service.dart';

class PhonePeService {
  PhonePeService._internal();
  static final PhonePeService instance = PhonePeService._internal();

  /// Connects shop to PhonePe Merchant business account
  Future<Map<String, dynamic>> connectMerchant({
    required Shop shop,
    required String mobileNumber,
    String? merchantId,
    String? storeName,
    String environment = 'sandbox',
  }) async {
    final client = SupabaseService.instance.client;
    final cleanPhone = mobileNumber.trim();
    final mid = (merchantId != null && merchantId.trim().isNotEmpty)
        ? merchantId.trim()
        : 'M$cleanPhone';
    final sname = (storeName != null && storeName.trim().isNotEmpty)
        ? storeName.trim()
        : shop.name;

    if (client != null && shop.id != 'demo-shop-101') {
      try {
        final res = await client.rpc('connect_phonepe_merchant', params: {
          '_shop_id': shop.id,
          '_mobile_number': cleanPhone,
          '_merchant_id': mid,
          '_store_name': sname,
          '_environment': environment,
        });
        if (res is Map<String, dynamic>) {
          return res;
        }
      } catch (e) {
        debugPrint('[PhonePeService] RPC connect_phonepe_merchant failed: $e. Falling back to direct update.');
        try {
          await client.from('shops').update({
            'phonepe_enabled': true,
            'phonepe_merchant_id': mid,
            'phonepe_mobile_number': cleanPhone,
            'phonepe_store_name': sname,
            'phonepe_environment': environment,
            'phonepe_connected_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', shop.id);
        } catch (updateErr) {
          debugPrint('[PhonePeService] Direct update error: $updateErr');
        }
      }
    }

    return {
      'success': true,
      'phonepe_enabled': true,
      'phonepe_merchant_id': mid,
      'phonepe_mobile_number': cleanPhone,
      'phonepe_store_name': sname,
      'phonepe_environment': environment,
      'phonepe_connected_at': DateTime.now().toIso8601String(),
    };
  }

  /// Disconnects PhonePe merchant integration
  Future<bool> disconnectMerchant(String shopId) async {
    final client = SupabaseService.instance.client;
    if (client != null && shopId != 'demo-shop-101') {
      try {
        await client.rpc('disconnect_phonepe_merchant', params: {'_shop_id': shopId});
        return true;
      } catch (e) {
        debugPrint('[PhonePeService] RPC disconnect failed: $e. Trying direct update.');
        try {
          await client.from('shops').update({'phonepe_enabled': false}).eq('id', shopId);
          return true;
        } catch (_) {}
      }
    }
    return true;
  }

  /// Builds an instant fallback transaction and QR with 0ms latency
  PaymentTransaction buildFallbackTransaction({
    required Shop shop,
    required int billNo,
    required double amount,
    required String clientRef,
    String paymentMode = 'online',
  }) {
    final safeAmount = PaymentQrHelper.round2(amount);
    final rawClean = shop.id.replaceAll('-', '');
    final cleanRef = rawClean.length >= 6 ? rawClean.substring(0, 6) : rawClean;
    final fallbackTxId = 'BILLZO_${cleanRef}_${billNo}_${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    final payeeVpa = (shop.upiId != null && shop.upiId!.trim().isNotEmpty)
        ? shop.upiId!.trim()
        : 'phonepe@merchant';
    final payeeName = (shop.phonePeStoreName != null && shop.phonePeStoreName!.trim().isNotEmpty)
        ? shop.phonePeStoreName!.trim()
        : shop.name;

    final fallbackQr = 'upi://pay?pa=$payeeVpa'
        '&pn=${Uri.encodeComponent(payeeName)}'
        '&am=${safeAmount.toStringAsFixed(2)}'
        '&cu=INR'
        '&tr=${Uri.encodeComponent(fallbackTxId)}'
        '&tn=${Uri.encodeComponent("Bill #$billNo")}';

    return PaymentTransaction(
      id: fallbackTxId,
      shopId: shop.id,
      billNo: billNo,
      clientRef: clientRef,
      merchantTransactionId: fallbackTxId,
      amount: safeAmount,
      status: 'PENDING',
      paymentMode: paymentMode,
      qrData: fallbackQr,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Creates a Dynamic In-Store Payment Request
  Future<PaymentTransaction> createPaymentOrder({
    required Shop shop,
    required int billNo,
    required double amount,
    required String clientRef,
    String paymentMode = 'online',
  }) async {
    final fallbackTx = buildFallbackTransaction(
      shop: shop,
      billNo: billNo,
      amount: amount,
      clientRef: clientRef,
      paymentMode: paymentMode,
    );

    final client = SupabaseService.instance.client;
    if (client != null && shop.id != 'demo-shop-101') {
      try {
        final res = await client.rpc('create_phonepe_payment_order', params: {
          '_shop_id': shop.id,
          '_bill_no': billNo,
          '_amount': fallbackTx.amount,
          '_client_ref': clientRef,
          '_payment_mode': paymentMode,
        }).timeout(const Duration(milliseconds: 1500));

        if (res is Map<String, dynamic> && res['success'] == true) {
          return PaymentTransaction(
            id: res['transaction_id']?.toString() ?? fallbackTx.id,
            shopId: shop.id,
            billNo: billNo,
            clientRef: clientRef,
            merchantTransactionId: res['merchant_transaction_id']?.toString() ?? fallbackTx.merchantTransactionId,
            amount: fallbackTx.amount,
            status: res['status']?.toString() ?? 'PENDING',
            paymentMode: paymentMode,
            qrData: res['qr_data']?.toString() ?? fallbackTx.qrData,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      } catch (e) {
        debugPrint('[PhonePeService] create_phonepe_payment_order RPC error/timeout: $e');
      }
    }

    // Return instant fallback transaction
    return fallbackTx;
  }

  /// Checks status of a payment transaction from database
  Future<PaymentTransaction?> checkPaymentStatus(String merchantTxId) async {
    final client = SupabaseService.instance.client;
    if (client == null) return null;

    try {
      final row = await client
          .from('payment_transactions')
          .select('*')
          .eq('merchant_transaction_id', merchantTxId)
          .maybeSingle()
          .timeout(const Duration(milliseconds: 2000));

      if (row != null) {
        return PaymentTransaction.fromJson(Map<String, dynamic>.from(row));
      }
    } catch (e) {
      debugPrint('[PhonePeService] checkPaymentStatus error: $e');
    }
    return null;
  }

  /// Simulates payment success for UAT Sandbox testing
  Future<PaymentTransaction?> simulatePaymentSuccess(String merchantTxId) async {
    final client = SupabaseService.instance.client;
    final now = DateTime.now();

    if (client != null) {
      try {
        final res = await client.rpc('verify_phonepe_payment', params: {
          '_merchant_transaction_id': merchantTxId,
          '_phonepe_transaction_id': 'T${now.millisecondsSinceEpoch}',
          '_status': 'SUCCESS',
          '_raw_response': {'simulation': true, 'timestamp': now.toIso8601String()},
        });

        if (res is Map<String, dynamic> && res['success'] == true) {
          return PaymentTransaction.fromJson(res);
        }
      } catch (e) {
        debugPrint('[PhonePeService] simulatePaymentSuccess RPC error: $e. Falling back to direct update.');
        try {
          final res = await client
              .from('payment_transactions')
              .update({
                'status': 'SUCCESS',
                'phonepe_transaction_id': 'T${now.millisecondsSinceEpoch}',
                'response_code': 'PAYMENT_SUCCESS',
                'verified_at': now.toUtc().toIso8601String(),
                'updated_at': now.toUtc().toIso8601String(),
              })
              .eq('merchant_transaction_id', merchantTxId)
              .select('*')
              .maybeSingle();

          if (res != null) {
            return PaymentTransaction.fromJson(Map<String, dynamic>.from(res));
          }
        } catch (_) {}
      }
    }

    // Local / Offline simulation
    return PaymentTransaction(
      id: merchantTxId,
      shopId: 'local',
      billNo: 0,
      clientRef: merchantTxId,
      merchantTransactionId: merchantTxId,
      phonepeTransactionId: 'T${now.millisecondsSinceEpoch}',
      amount: 0.0,
      status: 'SUCCESS',
      verifiedAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Listens to transaction status changes in Realtime with Polling fallback
  StreamSubscription<PaymentTransaction> listenToTransactionStatus({
    required String merchantTxId,
    required void Function(PaymentTransaction tx) onStatusUpdated,
  }) {
    final controller = StreamController<PaymentTransaction>();
    final client = SupabaseService.instance.client;
    RealtimeChannel? channel;
    Timer? pollingTimer;

    // 1. Setup Supabase Realtime WebSocket listener
    if (client != null) {
      try {
        channel = client
            .channel('tx_$merchantTxId')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'payment_transactions',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'merchant_transaction_id',
                value: merchantTxId,
              ),
              callback: (payload) {
                final newRecord = payload.newRecord;
                if (newRecord.isNotEmpty) {
                  final tx = PaymentTransaction.fromJson(Map<String, dynamic>.from(newRecord));
                  controller.add(tx);
                }
              },
            )
            .subscribe();
      } catch (e) {
        debugPrint('[PhonePeService] Realtime subscription error: $e');
      }
    }

    // 2. Setup periodic polling fallback (every 3 seconds) for network resilience
    pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final tx = await checkPaymentStatus(merchantTxId);
      if (tx != null) {
        controller.add(tx);
        if (tx.isSuccess || tx.isFailed || tx.isExpired) {
          timer.cancel();
        }
      }
    });

    final sub = controller.stream.listen((tx) {
      onStatusUpdated(tx);
    });

    // Handle cleanup when subscription is cancelled
    sub.onDone(() {
      pollingTimer?.cancel();
      channel?.unsubscribe();
      controller.close();
    });

    return sub;
  }
}
