import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import '../../data/services/local_db_service.dart';
import '../../data/services/supabase_service.dart';

/// Enterprise-grade Network Connectivity Listener & Automatic Background Sync Service.
/// Mirrors the robust offline-first synchronization models of Vyapar and Billiez.
/// Automatically detects when 4G/WiFi network returns, flushes the SQLite sync outbox,
/// listens to app lifecycle (app resumed from background), and maintains a periodic fallback ticker.
class NetworkSyncService with WidgetsBindingObserver {
  NetworkSyncService._internal();
  static final NetworkSyncService instance = NetworkSyncService._internal();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicTimer;
  Timer? _debounceTimer;

  bool _isInitialized = false;
  bool _isSyncing = false;
  bool _isOnline = true;
  DateTime? _lastSyncTime;
  int _lastSyncedCount = 0;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get lastSyncedCount => _lastSyncedCount;

  final ValueNotifier<bool> onlineNotifier = ValueNotifier<bool>(true);

  /// Initializes connectivity listeners, lifecycle watcher, and background ticker.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    WidgetsBinding.instance.addObserver(this);

    // Initial check
    try {
      final results = await Connectivity().checkConnectivity();
      _updateOnlineState(results);
    } catch (e) {
      debugPrint('[NetworkSyncService] Initial check error: $e');
    }

    // Listen for live network changes (WiFi, Mobile data, Ethernet, None)
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _updateOnlineState(results);

      // If reconnected to internet from offline, trigger immediate rapid sync!
      if (!wasOnline && _isOnline) {
        debugPrint('[NetworkSyncService] 🌐 Internet reconnected! Triggering auto-sync...');
        _scheduleSync(delayMs: 600);
      } else if (_isOnline) {
        // Debounced sync check on network switch (e.g. 4G to WiFi)
        _scheduleSync(delayMs: 1500);
      }
    });

    // Fallback ticker: Check outbox every 45s if online, ensuring zero stranded bills
    _periodicTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_isOnline && !_isSyncing) {
        syncNow(isQuiet: true);
      }
    });

    // Run first sync shortly after startup
    _scheduleSync(delayMs: 2000);
  }

  void _updateOnlineState(List<ConnectivityResult> results) {
    final hasNet = results.any((r) => r != ConnectivityResult.none);
    if (_isOnline != hasNet) {
      _isOnline = hasNet;
      onlineNotifier.value = hasNet;
      debugPrint('[NetworkSyncService] Network status changed: ${hasNet ? "ONLINE 🟢" : "OFFLINE 🔴"}');
    }
  }

  /// App lifecycle listener: When shopkeeper opens or switches back to the app, sync immediately!
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isOnline && !_isSyncing) {
      debugPrint('[NetworkSyncService] App resumed to foreground. Triggering sync...');
      _scheduleSync(delayMs: 500);
    }
  }

  /// Debounces rapid network switches so we don't bombard Supabase simultaneously
  void _scheduleSync({int delayMs = 1000}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: delayMs), () {
      syncNow();
    });
  }

  /// Manually or automatically flushes all pending bills, payments, and product edits.
  Future<int> syncNow({String? shopId, bool isQuiet = false}) async {
    if (_isSyncing) {
      if (!isQuiet) debugPrint('[NetworkSyncService] Sync already in progress, skipping duplicate.');
      return 0;
    }

    final targetShopId = shopId ?? SupabaseService.instance.currentShop.id;
    if (targetShopId.isEmpty || targetShopId == 'demo-shop-101') {
      return 0;
    }

    // Check if there is anything pending in SQLite outbox
    final pendingCount = await LocalDbService.instance.getPendingOutboxCount(targetShopId);
    if (pendingCount == 0) {
      return 0;
    }

    _isSyncing = true;
    if (!isQuiet) {
      debugPrint('[NetworkSyncService] 🚀 Auto-sync started for $pendingCount pending items in shop: $targetShopId');
    }

    int synced = 0;
    try {
      synced = await SupabaseService.instance.flushSyncOutbox(targetShopId);
      _lastSyncTime = DateTime.now();
      _lastSyncedCount = synced;

      if (synced > 0) {
        debugPrint('[NetworkSyncService] ✅ Auto-sync completed successfully! Synced $synced items to cloud.');
      }
    } catch (e) {
      debugPrint('[NetworkSyncService] ⚠️ Auto-sync encountered error: $e');
    } finally {
      _isSyncing = false;
    }

    return synced;
  }

  /// Clean teardown (e.g. during testing or app exit)
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _periodicTimer?.cancel();
    _debounceTimer?.cancel();
    _isInitialized = false;
  }
}
