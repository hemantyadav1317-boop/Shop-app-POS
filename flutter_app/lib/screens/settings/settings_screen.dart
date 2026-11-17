import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/sound_service.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/locale_provider.dart';
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
  static const String _appVersion = 'V 1.5.9';

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
    final localeProvider = context.read<LocaleProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final currentCode = context.watch<LocaleProvider>().localeCode;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.language_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Language / भाषा चुनें',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                        ),
                        Text(
                          'अपनी पसंदीदा भाषा चुनें',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: LocaleProvider.supportedLanguages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, idx) {
                      final lang = LocaleProvider.supportedLanguages[idx];
                      final isSelected = lang['code'] == currentCode;
                      return Material(
                        color: isSelected
                            ? (isDark ? AppColors.primary.withValues(alpha: 0.25) : AppColors.primarySurface.withValues(alpha: 0.7))
                            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            SoundService.instance.playSuccess();
                            await localeProvider.setLocale(lang['code']!);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(lang['flag'] ?? '🇮🇳', style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lang['name']!,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isSelected
                                              ? AppColors.primary
                                              : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                        ),
                                      ),
                                      Text(
                                        lang['sub']!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                                else
                                  Icon(Icons.radio_button_unchecked_rounded, size: 20, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showThemeSheet(BuildContext context, ShopProvider shopProvider) {
    SoundService.instance.playButtonClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTheme = shopProvider.themeMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.palette_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appearance / थीम चुनें',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                      Text(
                        'ऐप का रूप और रंग चुनें',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildThemeOptionCard(
                ctx: ctx,
                title: 'Light Theme (हल्की थीम)',
                subtitle: 'दिन के उपयोग के लिए साफ़ और स्पष्ट',
                icon: Icons.wb_sunny_rounded,
                iconColor: Colors.amber.shade700,
                isSelected: currentTheme == ThemeMode.light,
                onTap: () {
                  SoundService.instance.playSuccess();
                  shopProvider.setThemeMode(ThemeMode.light);
                  Navigator.pop(ctx);
                },
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildThemeOptionCard(
                ctx: ctx,
                title: 'Dark Theme (गहरी थीम)',
                subtitle: 'रात के समय आँखों के लिए आरामदायक',
                icon: Icons.nightlight_round,
                iconColor: Colors.indigo.shade300,
                isSelected: currentTheme == ThemeMode.dark,
                onTap: () {
                  SoundService.instance.playSuccess();
                  shopProvider.setThemeMode(ThemeMode.dark);
                  Navigator.pop(ctx);
                },
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildThemeOptionCard(
                ctx: ctx,
                title: 'System Default (फ़ोन सेटिंग अनुसार)',
                subtitle: 'डिवाइस के डार्क/लाइट मोड के साथ स्वतः बदलें',
                icon: Icons.brightness_auto_rounded,
                iconColor: Colors.teal,
                isSelected: currentTheme == ThemeMode.system,
                onTap: () {
                  SoundService.instance.playSuccess();
                  shopProvider.setThemeMode(ThemeMode.system);
                  Navigator.pop(ctx);
                },
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOptionCard({
    required BuildContext ctx,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: isSelected
          ? (isDark ? AppColors.primary.withValues(alpha: 0.25) : AppColors.primarySurface.withValues(alpha: 0.7))
          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: isSelected ? AppColors.primary : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
              else
                Icon(Icons.radio_button_unchecked_rounded, size: 20, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
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
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          context.tr('settings'),
          style: const TextStyle(
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

            // 8. Languages
            _buildSettingTile(
              context: context,
              title: context.tr('language'),
              subtitle: context.watch<LocaleProvider>().currentLanguageName,
              onTap: () => _showLanguageSheet(context),
            ),

            // 9. Theme
            _buildSettingTile(
              context: context,
              title: context.tr('theme'),
              subtitle: shopProvider.themeMode == ThemeMode.dark
                  ? 'Dark Theme (गहरी थीम)'
                  : (shopProvider.themeMode == ThemeMode.light ? 'Light Theme (हल्की थीम)' : 'System Default (सिस्टम अनुसार)'),
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
