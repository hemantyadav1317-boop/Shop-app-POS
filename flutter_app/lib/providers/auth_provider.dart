import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isGuestMode = false;
  bool _isLoading = true;

  User? get user => _user;
  bool get isGuestMode => _isGuestMode;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null || _isGuestMode;

  String get displayName {
    if (_user != null) {
      final meta = _user!.userMetadata;
      if (meta != null && meta['full_name'] != null) {
        return meta['full_name'] as String;
      }
      return _user!.email ?? 'User';
    }
    return 'दुकानदार (Offline Mode)';
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
    notifyListeners();

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kIsWeb ? null : 'io.supabase.shoppos://login-callback/',
        );
        _isGuestMode = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_guest_mode', false);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Google Sign in error: $e");
    }

    _isLoading = false;
    notifyListeners();
    return false;
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

    _isLoading = false;
    notifyListeners();
  }
}
