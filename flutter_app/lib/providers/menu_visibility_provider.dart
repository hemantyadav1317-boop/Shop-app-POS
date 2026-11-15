import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages and persists Fullscreen POS & Menu Bar visibility (Hide/Show)
/// across Laptop/Desktop sidebar and Mobile bottom navigation bar.
class MenuVisibilityProvider extends ChangeNotifier {
  static const String _prefKey = 'pos_menu_hidden';

  bool _isMenuHidden = false;
  bool get isMenuHidden => _isMenuHidden;

  MenuVisibilityProvider() {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKey);
      if (saved != null && saved != _isMenuHidden) {
        _isMenuHidden = saved;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MenuVisibilityProvider] Error loading menu preference: $e');
    }
  }

  Future<void> toggleMenu() async {
    _isMenuHidden = !_isMenuHidden;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, _isMenuHidden);
    } catch (e) {
      debugPrint('[MenuVisibilityProvider] Error saving menu preference: $e');
    }
  }

  Future<void> setMenuHidden(bool hidden) async {
    if (_isMenuHidden == hidden) return;
    _isMenuHidden = hidden;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, _isMenuHidden);
    } catch (e) {
      debugPrint('[MenuVisibilityProvider] Error saving menu preference: $e');
    }
  }
}
