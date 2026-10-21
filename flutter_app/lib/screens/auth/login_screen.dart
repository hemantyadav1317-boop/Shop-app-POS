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
                await shopProv.joinShop(code);
                if (context.mounted) {
                  await context.read<ProductProvider>().loadProducts(code);
                  if (context.mounted) {
                    await context.read<CustomerProvider>().loadCustomers(code);
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
                  constraints: const BoxConstraints(maxWidth: 440),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 30,
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(80),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.storefront, color: Colors.white, size: 48),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Brand Title
                  const Text(
                    'Shop POS',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your Shop. Your Billing.\nYour Complete Business System.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryDark,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Fast POS billing, stock, customer khata, expenses aur reports — Android phone aur tablet dono par.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                  ),
                  const SizedBox(height: 24),

                  // Feature Cards
                  _buildFeatureTile(
                    icon: Icons.smartphone,
                    title: 'Phone + Tablet Ready',
                    desc: 'Dono ke liye alag optimised touch layout.',
                  ),
                  const SizedBox(height: 8),
                  _buildFeatureTile(
                    icon: Icons.qr_code_2,
                    title: 'Dynamic UPI QR Billing',
                    desc: 'PhonePe, GPay, Paytm se turant customer payment.',
                  ),
                  const SizedBox(height: 8),
                  _buildFeatureTile(
                    icon: Icons.menu_book,
                    title: 'Customer Khata (बहीखाता)',
                    desc: 'Market udhar aur WhatsApp payment reminder.',
                  ),
                  const SizedBox(height: 24),

                  // Google Login Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 1,
                      side: const BorderSide(color: AppColors.lightBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            final success = await auth.signInWithGoogle();
                            if (success && context.mounted) {
                              if (auth.user != null) {
                                try {
                                  final shopProvider = context.read<ShopProvider>();
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
                            children: const [
                              Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Continue with Google',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 8),

                  // 2. Gmail & Password Login Button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: const Text(
                      'Gmail और पासवर्ड से लॉगिन (Cloud Sync)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showEmailLoginDialog(context),
                  ),
                  const SizedBox(height: 10),

                  // 3. Join Existing Shop Button for Family / Staff
                  OutlinedButton.icon(
                    icon: const Icon(Icons.group_add, color: AppColors.primary, size: 20),
                    label: const Text(
                      '🔗 परिवार या पार्टनर की दुकान से जुड़ें (Join Shop)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showJoinShopDialog(context),
                  ),
                  const SizedBox(height: 10),

                  // 4. Offline / Demo Mode Button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.flash_on, color: Colors.orange, size: 18),
                    label: const Text(
                      'Direct Offline Mode (डेमो मोड • डेटा सेव नहीं होगा)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  const SizedBox(height: 16),

                  const Text(
                    '🔒 आपका सारा डेटा एन्क्रिप्टेड और सुरक्षित है',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
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

  Widget _buildFeatureTile({required IconData icon, required String title, required String desc}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
