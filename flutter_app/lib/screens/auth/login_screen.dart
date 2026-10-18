import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/update_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
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
  void _showShopSetupDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: 'यादव जनरल स्टोर');
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('दुकान की जानकारी / Store Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'अपनी दुकान का नाम और फ़ोन नंबर दर्ज करें:',
              style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'दुकान का नाम *',
                prefixIcon: Icon(Icons.storefront),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'मोबाइल नंबर',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final shopName = nameCtrl.text.trim();
              if (shopName.isEmpty) return;

              final auth = context.read<AuthProvider>();
              await auth.continueAsShopOwner(
                shopName: shopName,
                phone: phoneCtrl.text.trim(),
              );

              // Update shop provider
              if (context.mounted) {
                final currentShop = context.read<ShopProvider>().shop;
                context.read<ShopProvider>().updateShop(
                      currentShop.copyWith(
                        name: shopName,
                        phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      ),
                    );
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MainShell()),
                );
              }
            },
            child: const Text('शुरू करें (Start POS)'),
          ),
        ],
      ),
    );
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
                if (email.isEmpty || pass.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('कृपया सही ईमेल और कम से कम 6 अक्षरों का पासवर्ड डालें।')),
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
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
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
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const MainShell()),
                              );
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

                  // Email & Password Login Button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: const Text(
                      'ईमेल / पासवर्ड से लॉगिन (Supabase Cloud)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showEmailLoginDialog(context),
                  ),
                  const SizedBox(height: 12),

                  // Quick Shop Setup / Direct Entry Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: const Text(
                      'दुकान का नाम दर्ज करके शुरू करें',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showShopSetupDialog(context),
                  ),
                  const SizedBox(height: 10),

                  // Offline / Demo Mode Button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.flash_on, color: AppColors.primary, size: 18),
                    label: const Text(
                      'Direct Offline Mode (बिना लॉगिन चलाएं)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
