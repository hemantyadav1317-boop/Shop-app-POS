import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/update_service.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/customer_provider.dart';
import '../main_shell.dart';
import 'business_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSubscription;
  bool _isGoogleLoading = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.showUpdateDialogIfNeeded(context);
    });

    // Listen to OAuth callbacks (e.g., when returning from Google login via deep link)
    final client = SupabaseService.instance.client;
    if (client != null) {
      _authSubscription = client.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        if (data.event == AuthChangeEvent.signedIn && session?.user != null) {
          if (mounted && !_isNavigating) {
            _isNavigating = true;
            await _navigateAfterAuth(context);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // If user returned from external browser without signing in, release the loading state
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_isNavigating) {
          final auth = context.read<AuthProvider>();
          if (auth.user == null) {
            setState(() => _isGoogleLoading = false);
          }
        }
      });
    }
  }

  Future<void> _navigateAfterAuth(BuildContext context) async {
    if (!context.mounted) return;
    final auth = context.read<AuthProvider>();
    final shopProvider = context.read<ShopProvider>();
    final productProvider = context.read<ProductProvider>();
    final customerProvider = context.read<CustomerProvider>();
    final prefs = await SharedPreferences.getInstance();

    final user = auth.user;
    if (user != null) {
      try {
        final syncedShop = await shopProvider.loadForUser(user.id, email: user.email);
        if (context.mounted) {
          await productProvider.loadProducts(syncedShop.id);
          await customerProvider.loadCustomers(syncedShop.id);
        }
      } catch (e) {
        debugPrint("Error syncing shop in _navigateAfterAuth: $e");
      }
    }

    final currentShop = shopProvider.shop;
    final userKey = user != null ? 'setup_done_${user.id}' : 'setup_done_guest';
    final isSetupDoneLocal = prefs.getBool(userKey) ?? false;
    final prods = productProvider.products;

    // Check if user already has an existing shop setup:
    // 1. Local preference flag was already completed.
    // 2. OR shop already has products loaded from cloud.
    // 3. OR shop has a non-default custom name or phone number.
    final bool isExistingShop = isSetupDoneLocal ||
        prods.isNotEmpty ||
        (currentShop.id != 'demo-shop-101' &&
            currentShop.name.trim().isNotEmpty &&
            currentShop.name != 'मेरी दुकान (My Store)' &&
            currentShop.name != 'Fresh Veggie Store' &&
            !currentShop.name.startsWith('मेरी दुकान (')) ||
        (currentShop.phone != null && currentShop.phone!.trim().isNotEmpty);

    if (isExistingShop) {
      // Permanently remember setup is done so user goes directly to POS
      await prefs.setBool(userKey, true);
      if (prefs.getString('selected_store_type') == null) {
        await prefs.setString('selected_store_type', currentShop.storeType);
      }
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } else {
      // Brand new user: guide them through store & mode configuration
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BusinessSetupScreen()),
        );
      }
    }
  }

  void _showEmailLoginDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isSignUp = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isSignUp ? 'Create New Account' : 'Sign In with Email',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setDialogState(() => isSignUp = !isSignUp),
                  child: Text(isSignUp ? 'Already have an account? Sign In' : 'New here? Create an Account (Sign Up)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2038),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final email = emailCtrl.text.trim();
                final pass = passCtrl.text;
                final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                if (email.isEmpty || !emailRegex.hasMatch(email)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid email address (e.g. name@gmail.com)')),
                  );
                  return;
                }
                if (pass.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 6 characters long.')),
                  );
                  return;
                }
                final auth = context.read<AuthProvider>();
                final ok = isSignUp
                    ? await auth.signUpWithEmailPassword(email, pass)
                    : await auth.signInWithEmailPassword(email, pass);

                if (ok && context.mounted) {
                  Navigator.pop(ctx);
                  if (auth.user != null) {
                    try {
                      final shopProvider = context.read<ShopProvider>();
                      final syncedShop = await shopProvider.loadForUser(auth.user!.id, email: auth.user!.email);
                      if (context.mounted) {
                        await context.read<ProductProvider>().loadProducts(syncedShop.id);
                        await context.read<CustomerProvider>().loadCustomers(syncedShop.id);
                      }
                    } catch (_) {}
                    if (context.mounted) {
                      await _navigateAfterAuth(context);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF00875A),
                        content: Text('Account created! Please check your email for the verification link.'),
                      ),
                    );
                  }
                } else if (auth.lastError != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red,
                      content: Text(auth.lastError!),
                    ),
                  );
                }
              },
              child: Text(isSignUp ? 'Sign Up' : 'Login'),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinShopDialog(BuildContext context) {
    final phoneCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final pasteCtrl = TextEditingController();
    bool isLoading = false;
    String? errorMsg;
    int activeTab = 0; // 0 = Phone + PIN, 1 = Quick Paste

    showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00875A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.badge_outlined, color: Color(0xFF00875A), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'स्टाफ लॉगिन (Staff Login)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '5-Layer सुरक्षित दुकान एक्सेस',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tab Switcher
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() {
                              activeTab = 0;
                              errorMsg = null;
                            }),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: activeTab == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: activeTab == 0
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '📱 मोबाइल व पिन',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: activeTab == 0 ? FontWeight.bold : FontWeight.normal,
                                    color: activeTab == 0 ? const Color(0xFF00875A) : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() {
                              activeTab = 1;
                              errorMsg = null;
                            }),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: activeTab == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: activeTab == 1
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '📋 लिंक/कोड पेस्ट',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: activeTab == 1 ? FontWeight.bold : FontWeight.normal,
                                    color: activeTab == 1 ? const Color(0xFF00875A) : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (errorMsg != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMsg!,
                              style: const TextStyle(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (activeTab == 0) ...[
                    // Shop Mobile Number
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'दुकानदार का मोबाइल नंबर *',
                        hintText: 'उदा. 9529419047',
                        prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF00875A)),
                        prefixText: '+91 ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF00875A), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 6-digit Staff PIN
                    TextField(
                      controller: pinCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 3),
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: '6-अंकीय स्टाफ पिन (Staff PIN) *',
                        hintText: 'उदा. 666091',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF00875A)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF00875A), width: 2),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Paste Payload / WhatsApp Link
                    TextField(
                      controller: pasteCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'WhatsApp शेयर मैसेज या कोड पेस्ट करें',
                        hintText: 'दुकानदार द्वारा भेजा गया WhatsApp मैसेज या कोड यहाँ पेस्ट करें...',
                        prefixIcon: const Icon(Icons.paste_rounded, color: Color(0xFF00875A)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF00875A), width: 2),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00875A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: isLoading
                        ? null
                        : () async {
                            String phone = phoneCtrl.text.trim();
                            String pin = pinCtrl.text.trim();
                            String? qr;

                            if (activeTab == 1) {
                              final pasted = pasteCtrl.text.trim();
                              if (pasted.isEmpty) {
                                setDialogState(() => errorMsg = 'कृपया शेयर किया गया मैसेज या कोड पेस्ट करें।');
                                return;
                              }
                              qr = pasted;
                              // Auto-extract phone and pin if possible
                              final phoneMatch = RegExp(r'(?:91)?([6-9]\d{9})').firstMatch(pasted);
                              if (phoneMatch != null) phone = phoneMatch.group(1)!;
                              final pinMatch = RegExp(r'\b(\d{6})\b').firstMatch(pasted);
                              if (pinMatch != null) pin = pinMatch.group(1)!;
                            }

                            if (phone.isEmpty && pin.isEmpty && qr == null) {
                              setDialogState(() => errorMsg = 'कृपया मोबाइल नंबर और पिन दर्ज करें।');
                              return;
                            }

                            setDialogState(() {
                              isLoading = true;
                              errorMsg = null;
                            });

                            try {
                              final auth = context.read<AuthProvider>();
                              await auth.continueOffline();

                              final shopProv = context.read<ShopProvider>();
                              final joined = await shopProv.joinShopAsStaff(
                                phone: phone,
                                pin: pin,
                                qrPayload: qr,
                              );

                              if (context.mounted) {
                                await context.read<ProductProvider>().loadProducts(joined.id);
                                if (context.mounted) {
                                  await context.read<CustomerProvider>().loadCustomers(joined.id);
                                  await SupabaseService.instance.getSales(joined.id);

                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setBool('setup_done_guest', true);
                                  await prefs.setString('selected_store_type', joined.storeType);

                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: const Color(0xFF00875A),
                                      content: Text('दुकान "${joined.name}" से कैशियर के रूप में सफलतापूर्वक जुड़ गए!'),
                                    ),
                                  );

                                  // Direct jump to POS Shell (NEVER BusinessSetupScreen)
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => const MainShell()),
                                  );
                                }
                              }
                            } catch (e) {
                              setDialogState(() {
                                isLoading = false;
                                errorMsg = e.toString().replaceFirst('Exception: ', '');
                              });
                            }
                          },
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login_rounded, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'दुकान खोलें (Login as Staff)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: isLoading ? null : () => Navigator.pop(ctx),
                    child: const Text('रद्द करें (Cancel)', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
              ),
            ],
          ),
          child: RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'shop',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                TextSpan(
                  text: 'pos',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Smart POS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroTitle() {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          height: 1.15,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        children: [
          TextSpan(text: 'Smart billing for\nevery '),
          TextSpan(
            text: 'modern shop',
            style: TextStyle(color: Color(0xFFF59E0B)),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFeatureCard({
    required String icon,
    required String title,
    required String description,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131F3B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E3A5F).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthButtons(BuildContext context, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Continue with Google Button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF131F3B),
            foregroundColor: Colors.white,
            elevation: 0,
            side: const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: (auth.isLoading || _isGoogleLoading || _isNavigating)
              ? null
              : () async {
                  setState(() => _isGoogleLoading = true);
                  final success = await auth.signInWithGoogle();
                  if (success && context.mounted) {
                    if (auth.user != null) {
                      _isNavigating = true;
                      await _navigateAfterAuth(context);
                    }
                    // Note: On mobile platforms, signInWithGoogle opens the external browser.
                    // auth.user is null until the browser completes and redirects back via deep link.
                    // _authSubscription in initState will receive AuthChangeEvent.signedIn and call _navigateAfterAuth.
                  } else {
                    if (mounted) setState(() => _isGoogleLoading = false);
                    if (auth.lastError != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.red,
                          content: Text(auth.lastError!),
                        ),
                      );
                    }
                  }
                },
          child: (auth.isLoading || _isGoogleLoading || _isNavigating)
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                      width: 20,
                      height: 20,
                      errorBuilder: (ctx, err, stack) => const Text(
                        'G',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 14),

        // OR Divider
        Row(
          children: const [
            Expanded(child: Divider(color: Color(0xFF1E293B))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(child: Divider(color: Color(0xFF1E293B))),
          ],
        ),
        const SizedBox(height: 14),

        // 2. Email / Password Login Button
        OutlinedButton.icon(
          icon: const Icon(Icons.email_outlined, color: Color(0xFFFBBF24), size: 18),
          label: const Text(
            'Sign In with Email & Password',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFFBBF24)),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(vertical: 15),
            side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => _showEmailLoginDialog(context),
        ),
        const SizedBox(height: 12),

        // 3. Staff Login / Demo Mode Link
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => _showJoinShopDialog(context),
              child: const Text(
                'Staff login →',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () async {
                await auth.continueOffline();
                if (context.mounted) {
                  await _navigateAfterAuth(context);
                }
              },
              child: const Text(
                'Demo Mode (Try Free) ⚡',
                style: TextStyle(color: Color(0xFFFBBF24), fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Footer: Terms & Version
        const Text(
          'By proceeding you agree to our Terms, Privacy Policy & Refund Policy',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
        ),
        const SizedBox(height: 6),
        const Text(
          'V 1.3.5',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  Widget _buildLoginForm(BuildContext context, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBrandHeader(),
        const SizedBox(height: 28),
        _buildHeroTitle(),
        const SizedBox(height: 10),
        const Text(
          'Sign in or create your free account to begin managing your shop.',
          style: TextStyle(
            fontSize: 14.5,
            color: Color(0xFF94A3B8),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 32),
        _buildAuthButtons(context, auth),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 960;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1124), // Deep Midnight Navy
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  // Left Hero Panel for Laptops / Desktops
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0F1A34),
                            Color(0xFF0A1124),
                          ],
                        ),
                        border: Border(right: BorderSide(color: Color(0xFF1E293B))),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBrandHeader(),
                          const Spacer(),
                          _buildHeroTitle(),
                          const SizedBox(height: 16),
                          const Text(
                            'The modern, high-speed point of sale designed for Indian retailers. Easily switch between Vegetable Mandi and Kirana Store modes with full offline billing.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF94A3B8),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 32),
                          // 3 Feature Showcase Cards
                          _buildDesktopFeatureCard(
                            icon: '🥬',
                            title: 'Vegetable & Fruit Mandi Mode',
                            description: 'Weight-based billing (Kg/g), quick touch pad, and live produce stock.',
                            accentColor: const Color(0xFF10B981),
                          ),
                          const SizedBox(height: 12),
                          _buildDesktopFeatureCard(
                            icon: '🏪',
                            title: 'Kirana & FMCG Store Mode',
                            description: 'Barcode gun scanning, 2026 FMCG database, MRP & profit margin tracking.',
                            accentColor: const Color(0xFF2563EB),
                          ),
                          const SizedBox(height: 12),
                          _buildDesktopFeatureCard(
                            icon: '📊',
                            title: 'Digital Khata & Thermal Invoices',
                            description: 'Instant Bluetooth receipts, WhatsApp invoices, and customer udhar ledger.',
                            accentColor: const Color(0xFFF59E0B),
                          ),
                          const Spacer(),
                          // Trust Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  '⚡ 100% Offline-First • Safe & Secure Cloud Sync',
                                  style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right Login Form for Laptops / Desktops
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: _buildLoginForm(context, auth),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBrandHeader(),
                        const SizedBox(height: 40),
                        _buildHeroTitle(),
                        const SizedBox(height: 12),
                        const Text(
                          'Sign in or create your free account to begin managing your shop.',
                          style: TextStyle(
                            fontSize: 14.5,
                            color: Color(0xFF94A3B8),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 40),
                        _buildAuthButtons(context, auth),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
