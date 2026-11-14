import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/customer.dart';
import '../../data/models/product.dart';
import '../../data/models/sale.dart';
import '../../data/models/shop.dart';
import '../../data/services/local_db_service.dart';
import '../../data/services/supabase_service.dart';

class BackupSnapshot {
  final String appVersion;
  final DateTime exportedAt;
  final Shop? shop;
  final Map<String, dynamic> categoriesConfig;
  final List<Product> products;
  final List<Customer> customers;
  final List<Sale> sales;

  const BackupSnapshot({
    required this.appVersion,
    required this.exportedAt,
    this.shop,
    required this.categoriesConfig,
    required this.products,
    required this.customers,
    required this.sales,
  });
}

class BackupExportResult {
  final File file;
  final String path;
  final bool savedInDownloads;
  final int productsCount;
  final int customersCount;
  final int salesCount;

  const BackupExportResult({
    required this.file,
    required this.path,
    required this.savedInDownloads,
    required this.productsCount,
    required this.customersCount,
    required this.salesCount,
  });
}

class BackupService {
  static const String _autoBackupEnabledKey = 'auto_backup_enabled';
  static const String _lastAutoBackupAtKey = 'last_auto_backup_at';
  static const String _lastBackupPathKey = 'last_backup_file_path';

  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupEnabledKey) ?? true;
  }

  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupEnabledKey, enabled);
  }

  static Future<Map<String, String?>> getLastBackupInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'lastAt': prefs.getString(_lastAutoBackupAtKey),
      'lastPath': prefs.getString(_lastBackupPathKey),
    };
  }

  /// Builds a complete JSON snapshot containing Shop, Categories, Stock, Khata, and All Bills.
  static String buildBackupJsonString({
    required Shop shop,
    required List<Product> products,
    required List<Customer> customers,
    required List<Sale> sales,
    Map<String, dynamic>? categoriesConfig,
  }) {
    final payload = {
      'app': 'BillZo POS',
      'schema_version': 1,
      'app_version': '1.5.3',
      'exported_at': DateTime.now().toIso8601String(),
      'shop': shop.toJson(),
      'categories': categoriesConfig ?? {},
      'products': products.map((p) => p.toJson()).toList(),
      'customers': customers.map((c) => c.toJson()).toList(),
      'sales': sales.map((s) => s.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Parses & validates a JSON backup string into structured store data.
  static BackupSnapshot parseBackupJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('अमान्य बैकअप फ़ाइल: JSON ऑब्जेक्ट नहीं मिला।');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (!map.containsKey('products') && !map.containsKey('sales') && !map.containsKey('shop')) {
      throw const FormatException('यह BillZo POS की मान्य बैकअप फ़ाइल नहीं है।');
    }

    Shop? shop;
    if (map['shop'] is Map) {
      shop = Shop.fromJson(Map<String, dynamic>.from(map['shop'] as Map));
    }

    final categories = map['categories'] is Map
        ? Map<String, dynamic>.from(map['categories'] as Map)
        : <String, dynamic>{};

    final products = <Product>[];
    if (map['products'] is List) {
      for (final item in map['products'] as List) {
        if (item is Map) {
          products.add(Product.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final customers = <Customer>[];
    if (map['customers'] is List) {
      for (final item in map['customers'] as List) {
        if (item is Map) {
          customers.add(Customer.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final sales = <Sale>[];
    if (map['sales'] is List) {
      for (final item in map['sales'] as List) {
        if (item is Map) {
          sales.add(Sale.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return BackupSnapshot(
      appVersion: map['app_version']?.toString() ?? '1.4.9',
      exportedAt: DateTime.tryParse(map['exported_at']?.toString() ?? '') ??
          DateTime.now(),
      shop: shop,
      categoriesConfig: categories,
      products: products,
      customers: customers,
      sales: sales,
    );
  }

  static Future<Directory> _resolveBackupDirectory({
    String? directoryOverride,
  }) async {
    if (directoryOverride != null && directoryOverride.isNotEmpty) {
      final dir = Directory(directoryOverride);
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }

    if (Platform.isAndroid) {
      // Try accessible phone Downloads folder first so user can see/copy it in Files app
      try {
        final downloadsBackup =
            Directory('/storage/emulated/0/Download/ShopPOS_Backups');
        if (!await downloadsBackup.exists()) {
          await downloadsBackup.create(recursive: true);
        }
        final probe = File(p.join(downloadsBackup.path, '.probe'));
        await probe.writeAsString('ok');
        await probe.delete();
        return downloadsBackup;
      } catch (_) {}

      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final extBackup = Directory(p.join(extDir.path, 'ShopPOS_Backups'));
          if (!await extBackup.exists()) await extBackup.create(recursive: true);
          return extBackup;
        }
      } catch (_) {}
    }

    final appDocs = await getApplicationDocumentsDirectory();
    final fallbackDir = Directory(p.join(appDocs.path, 'ShopPOS_Backups'));
    if (!await fallbackDir.exists()) {
      await fallbackDir.create(recursive: true);
    }
    return fallbackDir;
  }

  /// Writes a timestamped JSON backup file to phone storage.
  static Future<BackupExportResult> exportBackupToPhone({
    required Shop shop,
    required List<Product> products,
    required List<Customer> customers,
    required List<Sale> sales,
    Map<String, dynamic>? categoriesConfig,
    String? directoryOverride,
    String? fixedFileName,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web browser par local file export upalabdh nahi hai.');
    }

    final dir = await _resolveBackupDirectory(directoryOverride: directoryOverride);
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = fixedFileName ?? 'ShopPOS_Backup_$stamp.json';
    final file = File(p.join(dir.path, fileName));

    final jsonStr = buildBackupJsonString(
      shop: shop,
      products: products,
      customers: customers,
      sales: sales,
      categoriesConfig: categoriesConfig,
    );
    await file.writeAsString(jsonStr, flush: true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAutoBackupAtKey, DateTime.now().toIso8601String());
    await prefs.setString(_lastBackupPathKey, file.path);

    return BackupExportResult(
      file: file,
      path: file.path,
      savedInDownloads: dir.path.contains('/Download/'),
      productsCount: products.length,
      customersCount: customers.length,
      salesCount: sales.length,
    );
  }

  /// Quietly updates rolling phone auto-backup after bills/stock changes when enabled.
  static Future<void> runAutoBackupIfEnabled({
    required Shop shop,
    Map<String, dynamic>? categoriesConfig,
  }) async {
    if (kIsWeb) return;
    try {
      if (!await isAutoBackupEnabled()) return;
      final products = await LocalDbService.instance.getProducts(shop.id);
      final customers = await LocalDbService.instance.getCustomers(shop.id);
      final sales = await LocalDbService.instance.getSales(shop.id);
      final cats = categoriesConfig ??
          await LocalDbService.instance.getCategoriesConfig(shop.id);

      await exportBackupToPhone(
        shop: shop,
        products: products,
        customers: customers,
        sales: sales,
        categoriesConfig: cats,
        fixedFileName: 'ShopPOS_AutoBackup.json',
      );
    } catch (e) {
      debugPrint('[AutoBackup] Skipped silently: $e');
    }
  }

  /// Opens OS share sheet for any exported backup file (Drive, WhatsApp, Email, etc.)
  static Future<void> shareBackupFile(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'BillZo POS Store Backup',
        text: 'BillZo POS Data Backup (${p.basename(file.path)})',
      ),
    );
  }

  /// Lets the user select a `.json` backup file from phone storage & parses it.
  static Future<BackupSnapshot?> pickBackupFile() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final rawJson = utf8.decode(bytes);
    return parseBackupJson(rawJson);
  }

  /// Restores parsed backup snapshot into Local SQLite & Cloud Sync Outbox.
  static Future<void> applyBackupSnapshot(BackupSnapshot snapshot) async {
    await SupabaseService.instance.restoreFromBackup(
      shop: snapshot.shop,
      products: snapshot.products,
      customers: snapshot.customers,
      sales: snapshot.sales,
      categoriesConfig: snapshot.categoriesConfig,
    );
  }
}
