import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/sound_service.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/menu_visibility_provider.dart';
import '../../providers/shop_provider.dart';
import '../auth/login_screen.dart';
import 'business_details_screen.dart';
import 'feature_settings_screen.dart';
import 'printer_settings_screen.dart';
import 'receipt_settings_screen.dart';
import 'tax_settings_screen.dart';
import 'weighing_scale_settings_screen.dart';
import 'ai_vision_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // App Version
  static const String _appVersion = 'V 1.5.8';

  void _confirmLogout(BuildContext context) {
    SoundService.instance.playButtonClick();
    final authProvider = context.read<AuthProvider>();
    final shop = context.read<ShopProvider>().shop;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewPadding.bottom + MediaQuery.of(ctx).viewInsets.bottom;
        return SafeArea(
          bottom: true,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, 28 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout_rounded, color: Colors.red, size: 28),
                ),
                const SizedBox(height: 12),
                const Text(
                  'लॉगआउट करें? (Confirm Logout)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'क्या आप वाकई "${shop.name}" के खाते से लॉगआउट करना चाहते हैं?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00875A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF00875A).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_done_rounded, color: Color(0xFF00875A), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'चिंता न करें! आपका सारा डेटा (बिल, स्टॉक, खाता) क्लाउड पर सुरक्षित है।',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF00875A)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('रद्द करें (Cancel)', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await authProvider.signOut();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                        child: const Text('हाँ, लॉगआउट करें', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmResetShop(BuildContext context) {
    SoundService.instance.playButtonClick();
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('सुरक्षा नियम: केवल दुकान मालिक शॉप डेटा रीसेट कर सकते हैं।'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restart_alt_rounded, color: Color(0xFFD32F2F), size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Reset Shop Data?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: const Text(
          'क्या आप वाकई अपनी दुकान का टेस्ट डेटा रीसेट करना चाहते हैं?\n\nइससे वर्तमान कार्ट और अस्थायी टेस्ट बिल साफ हो जाएंगे।',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('रद्द करें (Cancel)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CartProvider>().clear();
              SupabaseService.instance.resetLocalData();
              SoundService.instance.playSuccess();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF00875A),
                  content: Text('शॉप का टेस्ट डेटा सफलतापूर्वक रीसेट कर दिया गया है।'),
                ),
              );
            },
            child: const Text('हाँ, रीसेट करें (Reset)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    SoundService.instance.playButtonClick();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Select Language / भाषा चुनें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Text('🇮🇳', style: TextStyle(fontSize: 24)),
                title: const Text('हिन्दी (Hindi)', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF00875A)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('हिन्दी भाषा सेट की गई है।')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
                title: const Text('English', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('English language selected.')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Text('🇮🇳', style: TextStyle(fontSize: 24)),
                title: const Text('Hinglish (हिंग्लिश)', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hinglish selected.')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemeSheet(BuildContext context, ShopProvider shopProvider) {
    SoundService.instance.playButtonClick();
    final currentTheme = shopProvider.themeMode;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Theme / थीम चुनें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.wb_sunny_outlined, color: Colors.amber),
                title: const Text('Light Theme (हल्की थीम)', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: currentTheme == ThemeMode.light
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00875A))
                    : null,
                onTap: () {
                  shopProvider.setThemeMode(ThemeMode.light);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.nightlight_round, color: Colors.indigo),
                title: const Text('Dark Theme (गहरी थीम)', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: currentTheme == ThemeMode.dark
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00875A))
                    : null,
                onTap: () {
                  shopProvider.setThemeMode(ThemeMode.dark);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.settings_brightness_outlined),
                title: const Text('System Default (सिस्टम के अनुसार)', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: currentTheme == ThemeMode.system
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00875A))
                    : null,
                onTap: () {
                  shopProvider.setThemeMode(ThemeMode.system);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 15,
                      color: isDark ? Colors.grey.shade400 : const Color(0xFF212121),
                    ),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.8,
          color: isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = context.watch<ShopProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1), // Exact deep navy/blue from screenshot
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          tooltip: 'Menu',
          onPressed: () {
            if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
              Scaffold.of(context).openDrawer();
            } else {
              context.read<MenuVisibilityProvider>().toggleMenu();
            }
          },
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Business Details
            _buildSettingTile(
              context: context,
              title: 'Business Details',
              subtitle: 'Business Name, Location, Email etc.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BusinessDetailsScreen()),
                );
              },
            ),

            // 2. Receipt
            _buildSettingTile(
              context: context,
              title: 'Receipt',
              subtitle: 'Customize Thermal and PDF Receipt',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReceiptSettingsScreen()),
                );
              },
            ),

            // 3. TAX / VAT
            _buildSettingTile(
              context: context,
              title: 'TAX / VAT',
              subtitle: 'Create and Customize Tax Details',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TaxSettingsScreen()),
                );
              },
            ),

            // 4. Printer Setup
            _buildSettingTile(
              context: context,
              title: 'Printer Setup',
              subtitle: 'Configure your Printer settings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                );
              },
            ),

            // 5. Weighing Scale (इलेक्ट्रॉनिक तराजू)
            _buildSettingTile(
              context: context,
              title: 'Weighing Scale',
              subtitle: 'Configure Bluetooth & USB Weight Scale / इलेक्ट्रॉनिक तराजू',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WeighingScaleSettingsScreen()),
                );
              },
            ),

            // 6. AI Vision Camera
            _buildSettingTile(
              context: context,
              title: 'AI Vision Camera',
              subtitle: 'Smart vegetable & fruit recognition / कैमरा पहचान',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiVisionSettingsScreen()),
                );
              },
            ),

            // 7. Feature Settings
            _buildSettingTile(
              context: context,
              title: 'Feature Settings',
              subtitle: 'Manage App features',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FeatureSettingsScreen()),
                );
              },
            ),

            // 6. Languages
            _buildSettingTile(
              context: context,
              title: 'Languages',
              subtitle: 'Select your preferred Language',
              onTap: () => _showLanguageSheet(context),
            ),

            // 7. Theme
            _buildSettingTile(
              context: context,
              title: 'Theme',
              subtitle: 'Choose your preferred Theme for your App',
              onTap: () => _showThemeSheet(context, shopProvider),
            ),

            // 8. Reset with Reset Shop button
            _buildSettingTile(
              context: context,
              title: 'Reset',
              subtitle: 'If you have completed testing, you can\nreset your data now',
              trailing: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD32F2F),
                  side: BorderSide(
                    color: const Color(0xFFD32F2F).withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: () => _confirmResetShop(context),
                child: const Text(
                  'Reset Shop',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFFD32F2F),
                  ),
                ),
              ),
              onTap: () => _confirmResetShop(context),
            ),

            // Bottom Footer: Version & Sign Out Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 36, 20, 32),
              child: Column(
                children: [
                  const Text(
                    _appVersion,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF757575),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD32F2F),
                        side: const BorderSide(color: Color(0xFFD32F2F), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _confirmLogout(context),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFFD32F2F),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
