import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stock_adjustment.dart';

class StockAdjustmentService {
  StockAdjustmentService._();
  static final StockAdjustmentService instance = StockAdjustmentService._();

  static const String _prefix = 'stock_adjustments_';

  /// Records a new stock adjustment both locally and into Supabase
  Future<void> recordAdjustment(StockAdjustment adjustment) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix${adjustment.shopId}';
      final existingJson = prefs.getStringList(key) ?? [];

      // Prepend so latest is first
      existingJson.insert(0, jsonEncode(adjustment.toJson()));

      // Keep up to 200 logs locally
      if (existingJson.length > 200) {
        existingJson.removeRange(200, existingJson.length);
      }
      await prefs.setStringList(key, existingJson);

      // Best effort sync to Supabase table if online
      try {
        final client = Supabase.instance.client;
        if (client.auth.currentSession != null) {
          await client.from('stock_adjustments').insert(adjustment.toJson());
        }
      } catch (cloudErr) {
        debugPrint('[StockAdjustmentService] Cloud sync note (safe fallback to local): $cloudErr');
      }
    } catch (e) {
      debugPrint('[StockAdjustmentService] Error recording adjustment: $e');
    }
  }

  /// Retrieves recorded adjustments for a shop
  Future<List<StockAdjustment>> getAdjustments(String shopId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$shopId';
      final list = prefs.getStringList(key) ?? [];
      return list
          .map((item) {
            try {
              return StockAdjustment.fromJson(jsonDecode(item) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<StockAdjustment>()
          .toList();
    } catch (e) {
      debugPrint('[StockAdjustmentService] Error fetching adjustments: $e');
      return [];
    }
  }
}

