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
    final isStaff = auth.isStaffSession;
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
                        const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Active Store Type Tags
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (shop.hasVegetableOrProduce)
                        _buildHeaderBadge(isHindi ? '🥬 सब्जी व फल' : '🥬 Fruits & Veg'),
                      if (shop.hasGroceryOrFmcg)
                        _buildHeaderBadge(isHindi ? '🛒 किराना व FMCG' : '🛒 Grocery & FMCG'),
                      if (shop.hasDairy)
                        _buildHeaderBadge(isHindi ? '🥛 डेयरी व दूध' : '🥛 Dairy & Milk'),
                      _buildHeaderBadge(isStaff
                          ? (isHindi ? '👤 स्टाफ सत्र' : '👤 Staff Session')
                          : (isHindi ? '👑 दुकान मालिक सत्र' : '👑 Store Owner')),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 24),
                children: [
                  // 📊 SECTION 1: दैनिक बिजनेस हब
                  _buildSectionHeader(isHindi ? '📊 दैनिक बिजनेस हब' : '📊 DAILY BUSINESS'),

                  _buildDrawerItem(
                    icon: Icons.monetization_on_rounded,
                    iconColor: const Color(0xFF16A34A),
                    title: isHindi ? 'आज की कमाई व मुनाफा' : 'Daily Profit & Margin',
                    subtitle: isHindi ? 'शुद्ध लाभ, लागत और मार्जिन रिपोर्ट' : 'Net profit, cost & margin report',
                    badge: isHindi ? 'नया' : 'NEW',
                    badgeColor: const Color(0xFF16A34A),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyProfitScreen()));
                    },
                  ),

                  _buildDrawerItem(
                    icon: Icons.assignment_outlined,
                    iconColor: const Color(0xFFD97706),
                    title: isHindi ? 'मंडी / सप्लायर पर्ची' : 'Supplier Order Sheet',
                    subtitle: isHindi ? 'खत्म हो रहे माल की 1-क्लिक WhatsApp लिस्ट' : '1-Click low-stock WhatsApp sheet',
                    badge: isHindi ? 'स्मार्ट' : 'SMART',
                    badgeColor: const Color(0xFFD97706),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MandiOrderScreen()));
                    },
                  ),

                  _buildDrawerItem(
                    icon: Icons.calendar_month_rounded,
                    iconColor: const Color(0xFF2563EB),
                    title: isHindi ? 'दुकान खर्च व गल्ला' : 'Daybook & Cash Drawer',
                    subtitle: isHindi ? 'नकद आया/गया, चाय-किराया और दैनिक हिसाब' : 'Cash in/out, shop expenses & register',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DaybookScreen()));
                    },
                  ),

                  Divider(
                    height: 24,
                    thickness: 0.8,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    indent: 16,
                    endIndent: 16,
                  ),

                  // ⚙️ SECTION 2: दुकान सेटिंग्स व टूल्स
                  _buildSectionHeader(isHindi ? '⚙️ दुकान टूल्स' : '⚙️ STORE TOOLS'),

                  _buildDrawerItem(
                    icon: Icons.settings_rounded,
                    iconColor: const Color(0xFF475569),
                    title: isHindi ? 'पूरी दुकान सेटिंग्स' : 'Store Settings',
                    subtitle: isHindi ? 'दुकान प्रोफाइल, टैक्स, बिल रसीद आदि' : 'Store profile, tax, receipt setup & more',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),

                  _buildDrawerItem(
                    icon: Icons.scale_rounded,
                    iconColor: const Color(0xFF0284C7),
                    title: isHindi ? 'इलेक्ट्रॉनिक तौल कांटा' : 'Electronic Weighing Scale',
                    subtitle: isHindi ? 'ब्लूटूथ / USB वजन मशीन जोड़ें' : 'Connect Bluetooth / USB weight machine',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const WeighingScaleSettingsScreen()));
                    },
                  ),

                  _buildDrawerItem(
                    icon: Icons.print_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    title: isHindi ? 'थर्मल रसीद प्रिंटर' : 'Thermal Receipt Printer',
                    subtitle: isHindi ? 'Bluetooth 58mm / 80mm प्रिंटर सेटअप' : 'Bluetooth 58mm / 80mm printer setup',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()));
                    },
                  ),

                  _buildDrawerItem(
                    icon: Icons.cloud_download_rounded,
                    iconColor: const Color(0xFF0D9488),
                    title: isHindi ? 'डेटा बैकअप' : 'Data Backup',
                    subtitle: isHindi ? 'लोकल फाइल व Google Drive में सुरक्षित डेटा' : 'Secure local file & cloud data backup',
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

                  Divider(
                    height: 24,
                    thickness: 0.8,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    indent: 16,
                    endIndent: 16,
                  ),

                  // 👤 SECTION 3: सिस्टम व सत्र
                  _buildSectionHeader(isHindi ? '👤 सिस्टम व प्राथमिकताएँ' : '👤 SYSTEM & PREFERENCES'),

                  ListTile(
                    leading: const Icon(Icons.translate_rounded, color: Color(0xFF2563EB), size: 22),
                    title: Text(isHindi ? 'भाषा बदलें' : 'Change Language', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: Text(locale.currentLanguageName, style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      SoundService.instance.playButtonClick();
                      _showLanguageDialog(context);
                    },
                  ),

                  ListTile(
                    leading: Icon(
                      shopProvider.themeMode == ThemeMode.dark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                      color: const Color(0xFFEAB308),
                      size: 22,
                    ),
                    title: Text(isHindi ? 'डार्क थीम' : 'Dark Theme', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: Text(
                      shopProvider.themeMode == ThemeMode.dark
                          ? (isHindi ? 'चालू' : 'On')
                          : (isHindi ? 'बंद' : 'Off'),
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Switch(
                      value: shopProvider.themeMode == ThemeMode.dark,
                      onChanged: (val) {
                        SoundService.instance.playButtonClick();
                        shopProvider.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                      },
                    ),
                  ),

                  ListTile(
                    leading: const Icon(Icons.system_update_rounded, color: Color(0xFF16A34A), size: 22),
                    title: Text('BillZo POS v${UpdateService.currentVersion}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: Text(
                      isHindi ? 'सिस्टम अप टू डेट है ✓' : 'System is up to date ✓',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A)),
                    ),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: (badgeColor ?? AppColors.primary).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeColor ?? AppColors.primary),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
      onTap: () {
        SoundService.instance.playButtonClick();
        onTap();
      },
    );
  }

  Widget _buildHeaderBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
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
