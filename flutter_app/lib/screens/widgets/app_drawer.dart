import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/network_sync_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/update_service.dart';
import '../../data/services/local_db_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';
import '../daybook/daybook_screen.dart';
import '../inventory/mandi_order_screen.dart';
import '../reports/daily_profit_screen.dart';
import '../settings/business_details_screen.dart';
import '../settings/printer_settings_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/weighing_scale_settings_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shopProvider = context.watch<ShopProvider>();
    final shop = shopProvider.shop;
    final auth = context.watch<AuthProvider>();
    final locale = context.watch<LocaleProvider>();
    final isHindi = locale.localeCode == 'hi';

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // 🏪 Top Shop Profile Header Card
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFF1E3A8A), const Color(0xFF1E40AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Bar: Online/Offline Sync Pill + Close [✕] Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Online / Offline Status Badge
                      ValueListenableBuilder<bool>(
                        valueListenable: NetworkSyncService.instance.onlineNotifier,
                        builder: (context, isOnline, _) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? const Color(0xFF10B981).withValues(alpha: 0.25)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isOnline ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: isOnline ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                  size: 7,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isOnline
                                      ? (locale.localeCode == 'hi' ? 'ऑनलाइन' : 'Online')
                                      : (locale.localeCode == 'hi' ? 'ऑफलाइन' : 'Offline'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      // Close Drawer Button
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Store Identity Info
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessDetailsScreen()));
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shop.name.isNotEmpty ? shop.name : 'मेरी दुकान (BillZo POS)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16.5,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (shop.phone != null && shop.phone!.isNotEmpty)
                                    ? '📞 ${shop.phone}'
                                    : (isHindi ? 'दुकान विवरण देखें / बदलें ➔' : 'View / Edit Store Profile ➔'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 22),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 24),
                children: [
                  // SECTION 1: DAILY BUSINESS
                  _buildSectionHeader(isHindi ? 'दैनिक बिजनेस' : 'DAILY BUSINESS'),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.trending_up_rounded,
                    iconColor: const Color(0xFF16A34A),
                    iconBgColor: isDark ? const Color(0xFF16A34A).withValues(alpha: 0.15) : const Color(0xFFE8F5E9),
                    title: isHindi ? 'मुनाफा रिपोर्ट' : 'Profit & Margin',
                    subtitle: isHindi ? 'दैनिक कमाई और लागत' : 'Daily earnings and costs',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyProfitScreen()));
                    },
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.assignment_outlined,
                    iconColor: const Color(0xFFD97706),
                    iconBgColor: isDark ? const Color(0xFFD97706).withValues(alpha: 0.15) : const Color(0xFFFFF3E0),
                    title: isHindi ? 'सप्लायर ऑर्डर' : 'Supplier Orders',
                    subtitle: isHindi ? 'कम स्टॉक व आर्डर' : 'Low stock & orders',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MandiOrderScreen()));
                    },
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.calendar_month_outlined,
                    iconColor: const Color(0xFF2563EB),
                    iconBgColor: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.15) : const Color(0xFFE3F2FD),
                    title: isHindi ? 'रोकड़ बही' : 'Cash Book',
                    subtitle: isHindi ? 'दैनिक नकद व खर्च' : 'Cash in, out & expenses',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DaybookScreen()));
                    },
                  ),

                  const SizedBox(height: 12),

                  // SECTION 2: STORE TOOLS
                  _buildSectionHeader(isHindi ? 'दुकान टूल्स' : 'STORE TOOLS'),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.settings_outlined,
                    iconColor: isDark ? Colors.white70 : const Color(0xFF334155),
                    iconBgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    title: isHindi ? 'दुकान सेटिंग्स' : 'Store Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.scale_outlined,
                    iconColor: isDark ? Colors.white70 : const Color(0xFF334155),
                    iconBgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    title: isHindi ? 'इलेक्ट्रॉनिक कांटा' : 'Weighing Scale',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const WeighingScaleSettingsScreen()));
                    },
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.print_outlined,
                    iconColor: isDark ? Colors.white70 : const Color(0xFF334155),
                    iconBgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    title: isHindi ? 'रसीद प्रिंटर' : 'Receipt Printer',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()));
                    },
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.cloud_upload_outlined,
                    iconColor: isDark ? Colors.white70 : const Color(0xFF334155),
                    iconBgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    title: isHindi ? 'डेटा बैकअप' : 'Data Backup',
                    onTap: () async {
                      Navigator.pop(context);
                      SoundService.instance.playButtonClick();
                      final prodProv = context.read<ProductProvider>();
                      final custProv = context.read<CustomerProvider>();
                      final sales = await LocalDbService.instance.getSales(shop.id);
                      final result = await BackupService.exportBackupToPhone(
                        shop: shop,
                        products: prodProv.products,
                        customers: custProv.customers,
                        sales: sales,
                        categoriesConfig: prodProv.exportCategoriesConfig(),
                      );
                      await BackupService.shareBackupFile(result.file);
                    },
                  ),

                  const SizedBox(height: 12),

                  // SECTION 3: SYSTEM & PREFERENCES
                  _buildSectionHeader(isHindi ? 'सिस्टम व सेटिंग्स' : 'SYSTEM & PREFERENCES'),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.translate_rounded,
                    iconColor: const Color(0xFF2563EB),
                    iconBgColor: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.15) : const Color(0xFFE3F2FD),
                    title: isHindi ? 'भाषा बदलें' : 'Change Language',
                    subtitle: locale.currentLanguageName,
                    onTap: () {
                      SoundService.instance.playButtonClick();
                      _showLanguageDialog(context);
                    },
                  ),

                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFFEAB308).withValues(alpha: 0.15) : const Color(0xFFFEF9C3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        shopProvider.themeMode == ThemeMode.dark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                        color: const Color(0xFFEAB308),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      isHindi ? 'डार्क थीम' : 'Dark Theme',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      shopProvider.themeMode == ThemeMode.dark
                          ? (isHindi ? 'चालू' : 'On')
                          : (isHindi ? 'बंद' : 'Off'),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    trailing: Switch(
                      value: shopProvider.themeMode == ThemeMode.dark,
                      activeColor: const Color(0xFFEA580C),
                      onChanged: (val) {
                        SoundService.instance.playButtonClick();
                        shopProvider.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                      },
                    ),
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.system_update_rounded,
                    iconColor: const Color(0xFF16A34A),
                    iconBgColor: isDark ? const Color(0xFF16A34A).withValues(alpha: 0.15) : const Color(0xFFE8F5E9),
                    title: 'BillZo POS v${UpdateService.currentVersion}',
                    subtitle: isHindi ? 'सिस्टम अप टू डेट है ✓' : 'System is up to date ✓',
                    onTap: () {
                      SoundService.instance.playButtonClick();
                      UpdateService.showUpdateDialogIfNeeded(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14.5,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      subtitle: (subtitle != null && subtitle.isNotEmpty)
          ? Text(
              subtitle,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
      onTap: () {
        SoundService.instance.playButtonClick();
        onTap();
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final locale = context.read<LocaleProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHindi = locale.localeCode == 'hi';

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
                    Text(
                      isHindi ? 'भाषा चुनें' : 'Select Language',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: LocaleProvider.supportedLanguages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
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
                            await locale.setLocale(lang['code']!);
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
                                  child: Text(
                                    lang['name']!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                    ),
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
}
