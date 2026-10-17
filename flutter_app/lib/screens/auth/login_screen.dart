import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../main_shell.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
                  const SizedBox(height: 28),

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
                  const SizedBox(height: 28),

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
                  const SizedBox(height: 12),

                  // Offline / Demo Mode Button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.flash_on, color: AppColors.primary, size: 18),
                    label: const Text(
                      'Continue Offline (बिना इंटरनेट के चलाएं)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
