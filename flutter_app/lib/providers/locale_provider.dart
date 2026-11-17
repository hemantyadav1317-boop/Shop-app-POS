import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/localization/app_translations.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _prefKey = 'app_locale_code';

  String _localeCode = 'hi';

  String get localeCode => _localeCode;
  Locale get locale => Locale(_localeCode);

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'hi', 'name': 'हिन्दी', 'sub': 'Hindi', 'flag': '🇮🇳'},
    {'code': 'en', 'name': 'English', 'sub': 'English', 'flag': '🇬🇧'},
    {'code': 'bn', 'name': 'বাংলা', 'sub': 'Bengali', 'flag': '🇮🇳'},
    {'code': 'mr', 'name': 'मराठी', 'sub': 'Marathi', 'flag': '🇮🇳'},
    {'code': 'gu', 'name': 'ગુજરાતી', 'sub': 'Gujarati', 'flag': '🇮🇳'},
    {'code': 'ta', 'name': 'தமிழ்', 'sub': 'Tamil', 'flag': '🇮🇳'},
    {'code': 'te', 'name': 'తెలుగు', 'sub': 'Telugu', 'flag': '🇮🇳'},
    {'code': 'kn', 'name': 'ಕನ್ನಡ', 'sub': 'Kannada', 'flag': '🇮🇳'},
    {'code': 'pa', 'name': 'ਪੰਜਾਬੀ', 'sub': 'Punjabi', 'flag': '🇮🇳'},
  ];

  LocaleProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && saved.isNotEmpty) {
        _localeCode = saved;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading locale: $e');
    }
  }

  Future<void> setLocale(String code) async {
    if (_localeCode == code) return;
    _localeCode = code;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, code);
    } catch (e) {
      debugPrint('Error saving locale: $e');
    }
  }

  String tr(String key) {
    return AppTranslations.get(key, _localeCode);
  }

  String get currentLanguageName {
    final match = supportedLanguages.firstWhere(
      (l) => l['code'] == _localeCode,
      orElse: () => supportedLanguages[0],
    );
    return '${match['name']} (${match['sub']})';
  }
}

extension AppLocaleExtension on BuildContext {
  String tr(String key) {
    return Provider.of<LocaleProvider>(this, listen: true).tr(key);
  }
}
