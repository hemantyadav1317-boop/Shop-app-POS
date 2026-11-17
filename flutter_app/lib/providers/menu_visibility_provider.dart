import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  Future<void> _applySystemUI() async {
    if (!kIsWeb) {
      try {
        if (_isMenuHidden) {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      } catch (e) {
        debugPrint('[MenuVisibilityProvider] SystemUI error: $e');
      }
    }
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKey);
      if (saved != null && saved != _isMenuHidden) {
        _isMenuHidden = saved;
        _applySystemUI();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MenuVisibilityProvider] Error loading menu preference: $e');
    }
  }

  Future<void> toggleMenu() async {
    _isMenuHidden = !_isMenuHidden;
    _applySystemUI();
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
    _applySystemUI();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, _isMenuHidden);
    } catch (e) {
      debugPrint('[MenuVisibilityProvider] Error saving menu preference: $e');
    }
  }
}
