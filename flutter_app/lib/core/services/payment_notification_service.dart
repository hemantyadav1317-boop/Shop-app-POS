import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/supabase_service.dart';

/// Represents a validated incoming payment captured via Android Notification or Cloud Relay
class DetectedPayment {
  final double amount;
  final String appName; // PhonePe, Paytm, Google Pay, BharatPe, Bank SMS
  final String packageName;
  final String title;
  final String text;
  final String utr;
  final DateTime timestamp;
  bool isConsumed;

  DetectedPayment({
    required this.amount,
    required this.appName,
    required this.packageName,
    required this.title,
    required this.text,
    required this.utr,
    required this.timestamp,
    this.isConsumed = false,
  });

  factory DetectedPayment.fromMap(Map<dynamic, dynamic> map) {
    final rawAmount = map['amount'];
    final double parsedAmount = (rawAmount is num) ? rawAmount.toDouble() : 0.0;

    final rawTs = map['timestamp'];
    final DateTime parsedTime = (rawTs is int)
        ? DateTime.fromMillisecondsSinceEpoch(rawTs)
        : (rawTs is String ? DateTime.tryParse(rawTs) ?? DateTime.now() : DateTime.now());

    return DetectedPayment(
      amount: parsedAmount,
      appName: map['appName']?.toString() ?? 'UPI',
      packageName: map['packageName']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      utr: map['utr']?.toString() ?? '',
      timestamp: parsedTime,
    );
  }

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'appName': appName,
        'packageName': packageName,
        'title': title,
        'text': text,
        'utr': utr,
        'timestamp': timestamp.toIso8601String(),
        'isConsumed': isConsumed,
      };
}

/// D-Mart Style Automatic Payment Verification & Cloud Bridge Service.
/// Captures PhonePe, Paytm, Google Pay, BharatPe and Bank SMS notifications
/// instantly (100ms) on Android, and syncs across Counter Tablets & Laptops via Supabase Realtime.
class PaymentNotificationService {
  PaymentNotificationService._internal();
  static final PaymentNotificationService instance = PaymentNotificationService._internal();

  static const MethodChannel _methodChannel =
      MethodChannel('com.shop.pos/payment_notification_channel');
  static const EventChannel _eventChannel =
      EventChannel('com.shop.pos/payment_notification_events');

  static const String _prefAutoVerifyEnabled = 'payment_auto_verify_enabled';
  static const String _prefCloudRelayEnabled = 'payment_cloud_relay_enabled';

  final StreamController<DetectedPayment> _paymentController =
      StreamController<DetectedPayment>.broadcast();
  Stream<DetectedPayment> get paymentStream => _paymentController.stream;

  final List<DetectedPayment> _recentPayments = [];
  List<DetectedPayment> get recentPayments => List.unmodifiable(_recentPayments);

  bool _isAutoVerifyEnabled = true;
  bool get isAutoVerifyEnabled => _isAutoVerifyEnabled;

  bool _isCloudRelayEnabled = false;
  bool get isCloudRelayEnabled => _isCloudRelayEnabled;

  bool _isInitialized = false;
  StreamSubscription? _eventSubscription;
  StreamSubscription? _cloudSubscription;

  bool get isAndroidSupported => !kIsWeb && Platform.isAndroid;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isAutoVerifyEnabled = prefs.getBool(_prefAutoVerifyEnabled) ?? true;
      _isCloudRelayEnabled = prefs.getBool(_prefCloudRelayEnabled) ?? false;
    } catch (_) {}

    // 1. Listen to Local Android System Notifications
    if (isAndroidSupported) {
      _startNativeListener();
    }

    // 2. Start Cloud Relay Listener (For Laptop / Tablet Multi-device sync)
    _startCloudRelayListener();
  }

  void _startNativeListener() {
    try {
      _eventSubscription?.cancel();
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            final payment = DetectedPayment.fromMap(event);
            _handleIncomingPayment(payment, isFromCloud: false);
          }
        },
        onError: (err) {
          debugPrint('[PaymentNotificationService] Native event stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('[PaymentNotificationService] Listener start error: $e');
    }
  }

  void _startCloudRelayListener() {
    try {
      _cloudSubscription?.cancel();
      final client = SupabaseService.instance.client;
      final currentShop = SupabaseService.instance.currentShop;
      if (client != null && currentShop.id != 'demo-shop-101') {
        _cloudSubscription = client
            .from('payment_transactions')
            .stream(primaryKey: ['id'])
            .eq('shop_id', currentShop.id)
            .listen((List<Map<String, dynamic>> records) {
              for (final row in records) {
                if (row['status'] == 'SUCCESS') {
                  final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
                  final verifiedAtStr = row['verified_at'] as String?;
                  final verifiedAt = verifiedAtStr != null
                      ? DateTime.tryParse(verifiedAtStr) ?? DateTime.now()
                      : DateTime.now();

                  // Only consider events from the last 2 minutes
                  if (DateTime.now().difference(verifiedAt).inSeconds < 120) {
                    final utr = row['merchant_transaction_id']?.toString() ?? '';
                    final alreadyPresent = _recentPayments.any((p) => p.utr == utr && p.utr.isNotEmpty);
                    if (!alreadyPresent) {
                      final cloudPayment = DetectedPayment(
                        amount: amount,
                        appName: 'Cloud Bridge',
                        packageName: 'supabase.realtime',
                        title: 'Cloud Verified Payment',
                        text: '₹$amount received via Owner Phone',
                        utr: utr,
                        timestamp: verifiedAt,
                      );
                      _handleIncomingPayment(cloudPayment, isFromCloud: true);
                    }
                  }
                }
              }
            });
      }
    } catch (e) {
      debugPrint('[PaymentNotificationService] Cloud listener error: $e');
    }
  }

  void _handleIncomingPayment(DetectedPayment payment, {required bool isFromCloud}) {
    if (!_isAutoVerifyEnabled) return;

    // Prune old entries (> 3 minutes)
    final now = DateTime.now();
    _recentPayments.removeWhere((p) => now.difference(p.timestamp).inSeconds > 180);

    // Prevent duplicate entries
    if (payment.utr.isNotEmpty && _recentPayments.any((p) => p.utr == payment.utr)) {
      return;
    }

    _recentPayments.add(payment);
    _paymentController.add(payment);

    debugPrint(
        '⚡ [PaymentNotificationService] Incoming Payment: ₹${payment.amount} (${payment.appName}) UTR: ${payment.utr}');

    // If this is the Owner Phone and Cloud Relay is enabled, push to Supabase Realtime so Counter Tablet/Laptop gets it!
    if (!isFromCloud && _isCloudRelayEnabled) {
      _relayPaymentToCloud(payment);
    }
  }

  Future<void> _relayPaymentToCloud(DetectedPayment payment) async {
    try {
      final client = SupabaseService.instance.client;
      final currentShop = SupabaseService.instance.currentShop;
      if (client != null && currentShop.id != 'demo-shop-101') {
        final txId = payment.utr.isNotEmpty ? payment.utr : 'NOTIF_${DateTime.now().millisecondsSinceEpoch}';
        await client.from('payment_transactions').upsert({
          'shop_id': currentShop.id,
          'bill_no': 0,
          'client_ref': 'relay_${payment.amount}',
          'merchant_transaction_id': txId,
          'phonepe_transaction_id': txId,
          'amount': payment.amount,
          'status': 'SUCCESS',
          'payment_mode': 'online',
          'verified_at': DateTime.now().toUtc().toIso8601String(),
        });
        debugPrint('📡 [PaymentNotificationService] Successfully relayed payment ₹${payment.amount} to Cloud');
      }
    } catch (e) {
      debugPrint('[PaymentNotificationService] Cloud relay failed: $e');
    }
  }

  /// Checks if a recent payment matches [targetAmount] (tolerance +/- 0.05) within last 90s.
  /// If found, marks it consumed and returns it!
  DetectedPayment? consumeMatchingPayment(double targetAmount) {
    if (!_isAutoVerifyEnabled) return null;
    final now = DateTime.now();

    for (var i = _recentPayments.length - 1; i >= 0; i--) {
      final p = _recentPayments[i];
      if (!p.isConsumed && (p.amount - targetAmount).abs() <= 0.05) {
        if (now.difference(p.timestamp).inSeconds <= 90) {
          p.isConsumed = true;
          return p;
        }
      }
    }
    return null;
  }

  /// Checks if Android Notification Access permission is granted
  Future<bool> checkPermission() async {
    if (!isAndroidSupported) return false;
    try {
      final isGranted = await _methodChannel.invokeMethod<bool>('isPermissionGranted');
      return isGranted ?? false;
    } catch (e) {
      debugPrint('[PaymentNotificationService] checkPermission error: $e');
      return false;
    }
  }

  /// Opens Android Notification Listener Settings page
  Future<bool> openSettings() async {
    if (!isAndroidSupported) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>('openSettings');
      return res ?? false;
    } catch (e) {
      debugPrint('[PaymentNotificationService] openSettings error: $e');
      return false;
    }
  }

  /// Simulates a payment notification (for testing, live demo, and unit tests)
  Future<void> simulatePayment({
    double amount = 1.0,
    String appName = 'PhonePe',
    String? utr,
  }) async {
    final generatedUtr = utr ?? 'SIM_${DateTime.now().millisecondsSinceEpoch}';
    final payment = DetectedPayment(
      amount: amount,
      appName: appName,
      packageName: 'com.phonepe.app',
      title: '$appName Business',
      text: 'Received ₹$amount from Rahul Kumar via UPI',
      utr: generatedUtr,
      timestamp: DateTime.now(),
    );
    _handleIncomingPayment(payment, isFromCloud: false);
  }

  Future<void> setAutoVerifyEnabled(bool enabled) async {
    _isAutoVerifyEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefAutoVerifyEnabled, enabled);
    } catch (_) {}
  }

  Future<void> setCloudRelayEnabled(bool enabled) async {
    _isCloudRelayEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefCloudRelayEnabled, enabled);
    } catch (_) {}
  }

  void dispose() {
    _eventSubscription?.cancel();
    _cloudSubscription?.cancel();
    _paymentController.close();
  }
}
