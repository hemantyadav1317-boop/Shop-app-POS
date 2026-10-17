import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isGuestMode = false;
  bool _isLoading = true;
  String? _lastError;
  String _customOwnerName = 'दुकानदार';

  User? get user => _user;
  bool get isGuestMode => _isGuestMode;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get isAuthenticated => _user != null || _isGuestMode;

  String get displayName {
    if (_user != null) {
      final meta = _user!.userMetadata;
      if (meta != null && meta['full_name'] != null) {
        return meta['full_name'] as String;
      }
      return _user!.email ?? 'User';
    }
    return _customOwnerName;
  }

  String? get email => _user?.email;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _isGuestMode = prefs.getBool('is_guest_mode') ?? false;
      _customOwnerName = prefs.getString('custom_owner_name') ?? 'दुकानदार';

      final client = SupabaseService.instance.client;
      if (client != null) {
        _user = client.auth.currentUser;

        // Listen to auth state changes
        client.auth.onAuthStateChange.listen((data) {
          _user = data.session?.user;
          notifyListeners();
        });
      }
    } catch (e) {
      debugPrint("Auth init error: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kIsWeb ? null : 'io.supabase.shoppos://login-callback',
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
        _isGuestMode = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_guest_mode', false);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _lastError = 'क्लाउड सर्वर से संपर्क नहीं हो सका।';
      }
    } catch (e) {
      debugPrint("Google Sign in error: $e");
      _lastError = 'Google Login एरर: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        final res = await client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        _user = res.user;
        _isGuestMode = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_guest_mode', false);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _lastError = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> continueAsShopOwner({required String shopName, required String phone}) async {
    _isGuestMode = true;
    _customOwnerName = shopName.trim().isNotEmpty ? shopName.trim() : 'दुकानदार';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest_mode', true);
    await prefs.setString('custom_owner_name', _customOwnerName);

    // Update local shop
    final currentShop = SupabaseService.instance.currentShop;
    final updated = currentShop.copyWith(
      name: shopName.trim().isNotEmpty ? shopName.trim() : currentShop.name,
      phone: phone.trim().isNotEmpty ? phone.trim() : currentShop.phone,
    );
    await SupabaseService.instance.updateShop(updated);

    notifyListeners();
  }

  Future<void> continueOffline() async {
    _isGuestMode = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest_mode', true);
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.auth.signOut();
      }
    } catch (e) {
      debugPrint("Sign out error: $e");
    }

    _user = null;
    _isGuestMode = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_guest_mode');
    await prefs.remove('custom_owner_name');

    _isLoading = false;
    notifyListeners();
  }
}
