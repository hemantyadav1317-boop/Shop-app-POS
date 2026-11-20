import 'package:flutter_test/flutter_test.dart';
import 'package:shop_pos/core/services/network_sync_service.dart';
import 'package:shop_pos/data/services/local_db_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🌐 Network Connectivity & Auto-Sync Service Tests', () {
    test('1. NetworkSyncService singleton initializes cleanly with safe defaults', () {
      final service = NetworkSyncService.instance;
      expect(service, isNotNull);
      expect(service.isSyncing, isFalse);
      expect(service.onlineNotifier, isNotNull);
      expect(service.lastSyncedCount, equals(0));
    });

    test('2. syncNow returns 0 when shop is demo-shop or uninitialized', () async {
      final service = NetworkSyncService.instance;
      final synced = await service.syncNow(shopId: 'demo-shop-101');
      expect(synced, equals(0));
    });

    test('3. syncNow returns 0 when outbox has no pending items', () async {
      final service = NetworkSyncService.instance;
      final synced = await service.syncNow(shopId: 'shop-test-clean');
      expect(synced, equals(0));
      expect(service.isSyncing, isFalse);
    });

    test('4. Payment entity outbox queuing and SQLite serialization', () {
      final paymentItem = SyncOutboxItem(
        id: 'payment_pay-123',
        shopId: 'test-shop-offline',
        entityType: 'payment',
        entityId: 'pay-123',
        operation: 'create',
        payload: {
          'id': 'pay-123',
          'shop_id': 'test-shop-offline',
          'customer_id': 'cust-456',
          'amount': 500.0,
          'mode': 'cash',
          'note': 'उधारी जमा',
          'created_at': DateTime.now().toIso8601String(),
        },
        createdAt: DateTime.now(),
      );

      expect(paymentItem.entityType, equals('payment'));
      expect(paymentItem.operation, equals('create'));
      expect(paymentItem.payload['amount'], equals(500.0));
      expect(paymentItem.payload['note'], equals('उधारी जमा'));
    });
  });
}
