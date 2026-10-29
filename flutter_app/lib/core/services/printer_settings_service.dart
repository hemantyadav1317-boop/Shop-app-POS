import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterSettingsService extends ChangeNotifier {
  static final PrinterSettingsService instance = PrinterSettingsService._internal();

  PrinterSettingsService._internal() {
    loadSettings();
  }

  // Preferences Keys
  static const String _keyPaperSize = 'printer_paper_size';
  static const String _keyFontScale = 'printer_font_scale';
  static const String _keyShowShopName = 'printer_show_shop_name';
  static const String _keyShowAddress = 'printer_show_address';
  static const String _keyShowPhone = 'printer_show_phone';
  static const String _keyShowEmail = 'printer_show_email';
  static const String _keyShowGstin = 'printer_show_gstin';
  static const String _keyShowInvoiceNo = 'printer_show_invoice_no';
  static const String _keyShowCustomer = 'printer_show_customer';
  static const String _keyShowQuote = 'printer_show_quote';
  static const String _keyShowFooter = 'printer_show_footer';
  static const String _keyShowQr = 'printer_show_qr';

  // Config State with sensible Indian POS defaults
  String _paperSize = '58mm'; // '58mm' or '80mm'
  double _fontScale = 1.25; // 1.0 (Normal), 1.25 (Large - recommended), 1.45 (Extra Large)
  bool _showShopName = true;
  bool _showAddress = true;
  bool _showPhone = true;
  bool _showEmail = false;
  bool _showGstin = true;
  bool _showInvoiceNo = true;
  bool _showCustomer = true;
  bool _showQuote = true;
  bool _showFooter = true;
  bool _showQr = true;

  // Getters
  String get paperSize => _paperSize;
  double get fontScale => _fontScale;
  String get fontScaleName {
    if (_fontScale >= 1.4) return 'Extra Large';
    if (_fontScale >= 1.2) return 'Large';
    return 'Normal';
  }

  bool get showShopName => _showShopName;
  bool get showAddress => _showAddress;
  bool get showPhone => _showPhone;
  bool get showEmail => _showEmail;
  bool get showGstin => _showGstin;
  bool get showInvoiceNo => _showInvoiceNo;
  bool get showCustomer => _showCustomer;
  bool get showQuote => _showQuote;
  bool get showFooter => _showFooter;
  bool get showQr => _showQr;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _paperSize = prefs.getString(_keyPaperSize) ?? '58mm';
    _fontScale = prefs.getDouble(_keyFontScale) ?? 1.25; // Default Large for clear 58mm reading
    _showShopName = prefs.getBool(_keyShowShopName) ?? true;
    _showAddress = prefs.getBool(_keyShowAddress) ?? true;
    _showPhone = prefs.getBool(_keyShowPhone) ?? true;
    _showEmail = prefs.getBool(_keyShowEmail) ?? false;
    _showGstin = prefs.getBool(_keyShowGstin) ?? true;
    _showInvoiceNo = prefs.getBool(_keyShowInvoiceNo) ?? true;
    _showCustomer = prefs.getBool(_keyShowCustomer) ?? true;
    _showQuote = prefs.getBool(_keyShowQuote) ?? true;
    _showFooter = prefs.getBool(_keyShowFooter) ?? true;
    _showQr = prefs.getBool(_keyShowQr) ?? true;
    notifyListeners();
  }

  Future<void> setPaperSize(String size) async {
    _paperSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPaperSize, size);
  }

  Future<void> setFontScale(double scale) async {
    _fontScale = scale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontScale, scale);
  }

  Future<void> toggleSetting(String key, bool value) async {
    switch (key) {
      case 'shopName':
        _showShopName = value;
        break;
      case 'address':
        _showAddress = value;
        break;
      case 'phone':
        _showPhone = value;
        break;
      case 'email':
        _showEmail = value;
        break;
      case 'gstin':
        _showGstin = value;
        break;
      case 'invoiceNo':
        _showInvoiceNo = value;
        break;
      case 'customer':
        _showCustomer = value;
        break;
      case 'quote':
        _showQuote = value;
        break;
      case 'footer':
        _showFooter = value;
        break;
      case 'qr':
        _showQr = value;
        break;
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final map = {
      'shopName': _keyShowShopName,
      'address': _keyShowAddress,
      'phone': _keyShowPhone,
      'email': _keyShowEmail,
      'gstin': _keyShowGstin,
      'invoiceNo': _keyShowInvoiceNo,
      'customer': _keyShowCustomer,
      'quote': _keyShowQuote,
      'footer': _keyShowFooter,
      'qr': _keyShowQr,
    };
    if (map.containsKey(key)) {
      await prefs.setBool(map[key]!, value);
    }
  }

  Future<void> saveAll({
    required String paperSize,
    required double fontScale,
    required bool showShopName,
    required bool showAddress,
    required bool showPhone,
    required bool showEmail,
    required bool showGstin,
    required bool showInvoiceNo,
    required bool showCustomer,
    required bool showQuote,
    required bool showFooter,
    required bool showQr,
  }) async {
    _paperSize = paperSize;
    _fontScale = fontScale;
    _showShopName = showShopName;
    _showAddress = showAddress;
    _showPhone = showPhone;
    _showEmail = showEmail;
    _showGstin = showGstin;
    _showInvoiceNo = showInvoiceNo;
    _showCustomer = showCustomer;
    _showQuote = showQuote;
    _showFooter = showFooter;
    _showQr = showQr;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPaperSize, paperSize);
    await prefs.setDouble(_keyFontScale, fontScale);
    await prefs.setBool(_keyShowShopName, showShopName);
    await prefs.setBool(_keyShowAddress, showAddress);
    await prefs.setBool(_keyShowPhone, showPhone);
    await prefs.setBool(_keyShowEmail, showEmail);
    await prefs.setBool(_keyShowGstin, showGstin);
    await prefs.setBool(_keyShowInvoiceNo, showInvoiceNo);
    await prefs.setBool(_keyShowCustomer, showCustomer);
    await prefs.setBool(_keyShowQuote, showQuote);
    await prefs.setBool(_keyShowFooter, showFooter);
    await prefs.setBool(_keyShowQr, showQr);
  }
}

