import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/update_service.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/locale_provider.dart';
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
  static String get _appVersion => 'V ${UpdateService.currentVersion}';

  void _confirmResetShop(BuildContext context) {
    SoundService.instance.playButtonClick();
    final auth = context.read<AuthProvider>();
    final isHindi = context.read<LocaleProvider>().localeCode == 'hi';

    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(isHindi
              ? 'सुरक्षा नियम: केवल दुकान मालिक शॉप डेटा रीसेट कर सकते हैं।'
              : 'Permission denied: Only store owners can reset shop data.'),
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
            Expanded(
              child: Text(
                isHindi ? 'शॉप डेटा रीसेट करें?' : 'Reset Shop Data?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          isHindi
              ? 'क्या आप वाकई अपनी दुकान का टेस्ट डेटा रीसेट करना चाहते हैं?\n\nइससे वर्तमान कार्ट और अस्थायी टेस्ट बिल साफ हो जाएंगे।'
              : 'Are you sure you want to reset test data?\n\nThis will clear cart and temporary demo records.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
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
                SnackBar(
                  backgroundColor: const Color(0xFF00875A),
                  content: Text(isHindi
                      ? 'शॉप का टेस्ट डेटा सफलतापूर्वक रीसेट कर दिया गया है।'
                      : 'Shop test data reset successfully.'),
                ),
              );
            },
            child: Text(isHindi ? 'हाँ, रीसेट करें' : 'Reset Data', style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final isHindi = context.read<LocaleProvider>().localeCode == 'hi';

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
                        isHindi ? 'थीम चुनें' : 'Choose Theme',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                      Text(
                        isHindi ? 'ऐप का रूप और रंग चुनें' : 'Select app visual style',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildThemeOptionCard(
                ctx: ctx,
                title: isHindi ? 'हल्की थीम (Light)' : 'Light Theme',
                subtitle: isHindi ? 'दिन के उपयोग के लिए साफ़ और स्पष्ट' : 'Clean & clear for daytime',
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
                title: isHindi ? 'गहरी थीम (Dark)' : 'Dark Theme',
                subtitle: isHindi ? 'रात के समय आँखों के लिए आरामदायक' : 'Comfortable for low light',
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
                title: isHindi ? 'सिस्टम अनुसार (Auto)' : 'System Default',
                subtitle: isHindi ? 'फ़ोन की सेटिंग के अनुसार बदलें' : 'Follow device settings',
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

  /// Upgraded Rich Floating Card matching the reference design:
  /// - Round elevated container
  /// - Pastel icon squircle on left
  /// - Vertical color accent line
  /// - Crisp title & subtitle
  /// - Soft chevron right
  Widget _buildRichSettingCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color squircleBgColor,
    required Color accentBarColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            SoundService.instance.playButtonClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // 1. Icon Squircle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: squircleBgColor,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: iconColor, size: 23),
                ),

                // 2. Vertical Accent Line
                Container(
                  width: 3,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: accentBarColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // 3. Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // 4. Trailing Action or Chevron
                trailing ??
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: Color(0xFF0F172A),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = context.watch<ShopProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHindi = context.watch<LocaleProvider>().localeCode == 'hi';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Vibrant Sunset Orange Header with Gear Watermark
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFF6D00),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
              tooltip: 'Back',
              onPressed: () {
                SoundService.instance.playButtonClick();
                Navigator.pop(context);
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: Text(
                isHindi ? 'सेटिंग्स' : 'Settings',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 0.3,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? const LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFFF5722), Color(0xFFFF9100)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                    ),
                  ),
                  // Watermark Gear in Top-Right Corner
                  Positioned(
                    right: -10,
                    top: -10,
                    child: Opacity(
                      opacity: 0.18,
                      child: const Icon(
                        Icons.settings_rounded,
                        size: 110,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Cards List
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. Business Details
                _buildRichSettingCard(
                  context: context,
                  icon: Icons.business_center_rounded,
                  iconColor: const Color(0xFF0284C7),
                  squircleBgColor: isDark ? const Color(0xFF0284C7).withValues(alpha: 0.18) : const Color(0xFFE0F2FE),
                  accentBarColor: const Color(0xFF0284C7),
                  title: isHindi ? 'दुकान विवरण' : 'Business Details',
                  subtitle: isHindi ? 'दुकान का नाम, पता, संपर्क आदि' : 'Business Name, Location, Email etc.',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BusinessDetailsScreen()),
                    );
                  },
                ),

                // 2. Receipt
                _buildRichSettingCard(
                  context: context,
                  icon: Icons.receipt_long_rounded,
                  iconColor: const Color(0xFF16A34A),
                  squircleBgColor: isDark ? const Color(0xFF16A34A).withValues(alpha: 0.18) : const Color(0xFFDCFCE7),
                  accentBarColor: const Color(0xFF16A34A),
                  title: isHindi ? 'रसीद सेटिंग्स' : 'Receipt',
                  subtitle: isHindi ? 'थर्मल और PDF रसीद कस्टमाइज़ करें' : 'Customize Thermal and PDF Receipt',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReceiptSettingsScreen()),
                    );
                  },
                ),

                // 3. TAX / VAT
                _buildRichSettingCard(
                  context: context,
                  icon: Icons.request_quote_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  squircleBgColor: isDark ? const Color(0xFF7C3AED).withValues(alpha: 0.18) : const Color(0xFFF3E8FF),
                  accentBarColor: const Color(0xFF7C3AED),
                  title: 'TAX / VAT',
                  subtitle: isHindi ? 'टैक्स व GST दरें सेट करें' : 'Create and Customize Tax Details',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TaxSettingsScreen()),
                    );
                  },
                ),

                // 4. Printer Setup
                _buildRichSettingCard(
                  context: context,
                  icon: Icons.print_rounded,
                  iconColor: const Color(0xFFEA580C),
                  squircleBgColor: isDark ? const Color(0xFFEA580C).withValues(alpha: 0.18) : const Color(0xFFFFEDD5),
                  accentBarColor: const Color(0xFFEA580C),
                  title: isHindi ? 'प्रिंटर सेटअप' : 'Printer Setup',
                  subtitle: isHindi ? 'ब्लूटूथ व USB रसीद प्रिंटर' : 'Configure your Printer settings',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                    );
                  },
                ),

                // 5. Weighing Scale
                _buildRichSettingCard(
                  context: context,
                  icon: Icons.scale_rounded,
                  iconColor: const Color(0xFF0D9488),
                  squircleBgColor: isDark ? const Color(0xFF0D9488).withValues(alpha: 0.18) : const Color(0xFFCCFBF1),
                  accentBarColor: const Color(0xFF0D9488),
                  title: isHindi ? 'इलेक्ट्रॉनिक कांटा' : 'Weighing Scale',
                  subtitle: isHindi ? 'ब्लूटूथ व USB वजन मशीन जोड़ें' : 'Configure Bluetooth & USB Weight Scale',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WeighingScaleSettingsScreen()),
                    );
                  },
                ),

                // 6. AI Vision Camera
                _buildRichSettingCard(
                  context: context,
                  icon: Icons.camera_alt_rounded,
                  iconColor: const Color(0xFF4F46E5),
                  squircleBgColor: isDark ? const Color(0xFF4F46E5).withValues(alpha: 0.18) : const Color(0xFFE0E7FF),
                  accentBarColor: const Color(0xFF4F46E5),
                  title: 'AI Vision Camera',
                  subtitle: isHindi ? 'सब्जी व फल की ऑटोमैटिक पहचान' : 'Smart vegetable & fruit recognition',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AiVisionSettingsScreen()),
                    );
                  },
                ),

                // 7. Feature Settings
                _buildRichSettingCard(
                  context: context,
                  icon: Icons.tune_rounded,
                  iconColor: const Color(0xFF16A34A),
                  squircleBgColor: isDark ? const Color(0xFF16A34A).withValues(alpha: 0.18) : const Color(0xFFDCFCE7),
                  accentBarColor: const Color(0xFF16A34A),
                  title: isHindi ? 'फीचर सेटिंग्स' : 'Feature Settings',
                  subtitle: isHindi ? 'ऐप फीचर्स चालू या बंद करें' : 'Manage App features',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FeatureSettingsScreen()),
                    );
                  },
                ),

                // 8. Language
                _buildRichSettingCard(
                  context: context,
                  icon: Icons.language_rounded,
                  iconColor: const Color(0xFF0284C7),
                  squircleBgColor: isDark ? const Color(0xFF0284C7).withValues(alpha: 0.18) : const Color(0xFFE0F2FE),
                  accentBarColor: const Color(0xFF0284C7),
                  title: isHindi ? 'भाषा' : 'Language',
                  subtitle: context.watch<LocaleProvider>().currentLanguageName,
                  onTap: () => _showLanguageSheet(context),
                ),

                // 9. Theme
                _buildRichSettingCard(
                  context: context,
                  icon: Icons.palette_rounded,
                  iconColor: const Color(0xFF9333EA),
                  squircleBgColor: isDark ? const Color(0xFF9333EA).withValues(alpha: 0.18) : const Color(0xFFF3E8FF),
                  accentBarColor: const Color(0xFF9333EA),
                  title: isHindi ? 'थीम' : 'Theme',
                  subtitle: shopProvider.themeMode == ThemeMode.dark
                      ? (isHindi ? 'गहरी थीम (Dark)' : 'Dark Theme')
                      : (shopProvider.themeMode == ThemeMode.light
                          ? (isHindi ? 'हल्की थीम (Light)' : 'Light Theme')
                          : (isHindi ? 'सिस्टम अनुसार' : 'System Default')),
                  onTap: () => _showThemeSheet(context, shopProvider),
                ),

                // 10. Reset Shop Data
                _buildRichSettingCard(
                  context: context,
                  icon: Icons.restart_alt_rounded,
                  iconColor: const Color(0xFFDC2626),
                  squircleBgColor: isDark ? const Color(0xFFDC2626).withValues(alpha: 0.18) : const Color(0xFFFEE2E2),
                  accentBarColor: const Color(0xFFDC2626),
                  title: isHindi ? 'डेटा रीसेट' : 'Reset',
                  subtitle: isHindi ? 'टेस्टिंग डेटा और कार्ट साफ करें' : 'Reset test shop data & orders',
                  onTap: () => _confirmResetShop(context),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      isHindi ? 'रीसेट' : 'Reset',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Footer: Version
                Center(
                  child: Text(
                    _appVersion,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
