import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/update_service.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/customer_provider.dart';
import '../main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.showUpdateDialogIfNeeded(context);
    });
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
          title: Text(isSignUp ? 'नया अकाउंट बनाएं / Register' : 'ईमेल से लॉगिन करें / Login', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'ईमेल / Email', prefixIcon: Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'पासवर्ड / Password', prefixIcon: Icon(Icons.lock_outline)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setDialogState(() => isSignUp = !isSignUp),
                child: Text(isSignUp ? 'पहले से अकाउंट है? लॉगिन करें' : 'नया अकाउंट बनाएं (Sign Up)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                final pass = passCtrl.text;
                final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                if (email.isEmpty || !emailRegex.hasMatch(email)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('कृपया सही ईमेल/Gmail एड्रेस डालें (जैसे: yourname@gmail.com)')),
                  );
                  return;
                }
                if (pass.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('पासवर्ड कम से कम 6 अक्षरों का होना चाहिए।')),
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
                      await shopProvider.loadForUser(auth.user!.id);
                      final syncedShop = await SupabaseService.instance.syncUserShop(
                        userId: auth.user!.id,
                        userEmail: auth.user!.email ?? '',
                        fallback: shopProvider.shop,
                      );
                      await shopProvider.setShop(syncedShop);
                      if (context.mounted) {
                        await context.read<ProductProvider>().loadProducts(syncedShop.id);
                        await context.read<CustomerProvider>().loadCustomers(syncedShop.id);
                      }
                    } catch (_) {}
                    if (context.mounted) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.primary,
                        content: Text('अकाउंट बन गया! अगर ईमेल पर लिंक आया है तो वेरिफाई करें, फिर लॉगिन करें।'),
                      ),
                    );
                  }
                } else if (auth.lastError != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.error,
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
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.store, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'दुकान से जुड़ें / Join Shop',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'यदि आपके भाई या पिता ने अपनी दुकान बनाई हुई है, तो उनसे उनकी दुकान का कोड मांगें और यहाँ डालें:',
              style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'दुकान कोड (Shop ID) *',
                hintText: 'उदा. demo-shop-101 या शॉप UUID',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final code = codeCtrl.text.trim();
              if (code.isEmpty) return;

              final auth = context.read<AuthProvider>();
              await auth.continueOffline();

              if (context.mounted) {
                final shopProv = context.read<ShopProvider>();
                final joined = await shopProv.joinShop(code);
                if (context.mounted) {
                  await context.read<ProductProvider>().loadProducts(joined.id);
                  if (context.mounted) {
                    await context.read<CustomerProvider>().loadCustomers(joined.id);
                    await SupabaseService.instance.getSales(joined.id);
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MainShell()),
                    );
                  }
                }
              }
            },
            child: const Text('दुकान से जुड़ें (Join)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Stack(
        children: [
          // Background Indian Store Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/pos_header_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // Lush Green Ambient Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF042415).withValues(alpha: 0.82),
                    const Color(0xFF02160C).withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),
          ),

          // Content Box
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // App Icon / Logo
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00875A), Color(0xFF005A3C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00875A).withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 42),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Brand Title & Tagline
                      const Text(
                        'Shop POS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          letterSpacing: -0.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'आपकी अपनी डिजिटल दुकान',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF00875A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'फास्ट बिलिंग • स्टॉक • ग्राहक खाता',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                      ),
                      const SizedBox(height: 16),

                      // Dynamic Compact Feature Pills
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFeatureChip(Icons.bolt_rounded, 'तेज बिलिंग'),
                          const SizedBox(width: 8),
                          _buildFeatureChip(Icons.qr_code_2_rounded, 'UPI QR'),
                          const SizedBox(width: 8),
                          _buildFeatureChip(Icons.menu_book_rounded, 'बहीखाता'),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Google Login Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F172A),
                          elevation: 1.5,
                          shadowColor: Colors.black.withValues(alpha: 0.08),
                          side: BorderSide(color: Colors.grey.shade300, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: auth.isLoading
                            ? null
                            : () async {
                                final success = await auth.signInWithGoogle();
                                if (success && context.mounted) {
                                  if (auth.user != null) {
                                    try {
                                      final shopProvider = context.read<ShopProvider>();
                                      await shopProvider.loadForUser(auth.user!.id);
                                      final syncedShop = await SupabaseService.instance.syncUserShop(
                                        userId: auth.user!.id,
                                        userEmail: auth.user!.email ?? '',
                                        fallback: shopProvider.shop,
                                      );
                                      await shopProvider.setShop(syncedShop);
                                      if (context.mounted) {
                                        await context.read<ProductProvider>().loadProducts(syncedShop.id);
                                        await context.read<CustomerProvider>().loadCustomers(syncedShop.id);
                                      }
                                    } catch (_) {}
                                  }
                                  if (context.mounted) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (_) => const MainShell()),
                                    );
                                  }
                                } else if (auth.lastError != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppColors.error,
                                      content: Text(auth.lastError!),
                                    ),
                                  );
                                }
                              },
                        child: auth.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
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
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Continue with Google',
                                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),

                      // Divider "या (OR)"
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'या / OR',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Gmail / Password Login Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.email_outlined, size: 17),
                        label: const Text(
                          'Gmail और पासवर्ड से लॉगिन करें',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showEmailLoginDialog(context),
                      ),
                      const SizedBox(height: 8),

                      // Join Existing Shop Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.group_add, color: Color(0xFF00875A), size: 18),
                        label: const Text(
                          '🔗 पार्टनर दुकान से जुड़ें (Join Code)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00875A)),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          side: const BorderSide(color: Color(0xFF00875A), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showJoinShopDialog(context),
                      ),
                      const SizedBox(height: 10),

                      // Direct Offline Demo Mode Button
                      TextButton.icon(
                        icon: const Icon(Icons.flash_on, color: Colors.orange, size: 16),
                        label: const Text(
                          'डायरेक्ट ऑफलाइन डेमो मोड (Try Free)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF475569)),
                        ),
                        onPressed: () async {
                          await auth.continueOffline();
                          if (context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const MainShell()),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 6),

                      const Text(
                        '🔒 100% सुरक्षित • आपका डेटा केवल आपकी दुकान का है',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10.5, color: AppColors.lightTextSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF00875A)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF005A3C),
            ),
          ),
        ],
      ),
    );
  }
}
