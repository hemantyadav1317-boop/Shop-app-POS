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

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // 🏪 Top Shop Profile Header Card
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shop.name.isNotEmpty ? shop.name : 'BillZo Store',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              shop.phone ?? 'फ़ोन नंबर सेट करें',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Online / Offline Status Badge
                      ValueListenableBuilder<bool>(
                        valueListenable: NetworkSyncService.instance.onlineNotifier,
                        builder: (context, isOnline, _) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                  isOnline ? 'ऑनलाइन' : 'ऑफलाइन',
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
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Active Store Type Tags
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (shop.hasVegetableOrProduce)
                        _buildHeaderBadge('🥬 सब्जी व फल'),
                      if (shop.hasGroceryOrFmcg)
                        _buildHeaderBadge('🛒 किराना व FMCG'),
                      if (shop.hasDairy)
                        _buildHeaderBadge('🥛 डेयरी व दूध'),
                      _buildHeaderBadge(isStaff ? '👤 स्टाफ सत्र' : '👑 मालिक सत्र'),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // 📊 SECTION 1: दैनिक बिजनेस हब
                  _buildSectionHeader('📊 दैनिक बिजनेस हब (DAILY BUSINESS)'),

                  _buildDrawerItem(
                    icon: Icons.monetization_on_rounded,
                    iconColor: const Color(0xFF16A34A),
                    title: 'आज की कमाई व मुनाफा',
                    subtitle: 'शुद्ध लाभ, लागत और मार्जिन रिपोर्ट',
                    badge: 'NEW',
                    badgeColor: const Color(0xFF16A34A),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyProfitScreen()));
                    },
                  ),

                  _buildDrawerItem(
                    icon: Icons.assignment_outlined,
                    iconColor: const Color(0xFFD97706),
                    title: 'मंडी / सप्लायर पर्ची',
                    subtitle: 'खत्म हो रहे माल की 1-क्लिक WhatsApp लिस्ट',
                    badge: 'स्मार्ट',
                    badgeColor: const Color(0xFFD97706),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MandiOrderScreen()));
                    },
                  ),

                  _buildDrawerItem(
                    icon: Icons.calendar_month_rounded,
                    iconColor: const Color(0xFF2563EB),
                    title: 'दुकान खर्च व गल्ला (Daybook)',
                    subtitle: 'नकद आया/गया, चाय-किराया और दैनिक हिसाब',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DaybookScreen()));
                    },
                  ),

                  const Divider(height: 16),

                  // ⚙️ SECTION 2: दुकान सेटिंग्स व टूल्स
                  _buildSectionHeader('⚙️ दुकान टूल्स (STORE TOOLS)'),

                  _buildDrawerItem(
                    icon: Icons.settings_rounded,
                    iconColor: const Color(0xFF475569),
                    title: 'पूरी दुकान सेटिंग्स',
                    subtitle: 'दुकान प्रोफाइल, टैक्स, बिल रसीद आदि',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),

                  _buildDrawerItem(
                    icon: Icons.scale_rounded,
                    iconColor: const Color(0xFF0284C7),
                    title: 'इलेक्ट्रॉनिक तौल कांटा',
                    subtitle: 'ब्लूटूथ / USB वजन मशीन जोड़ें',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const WeighingScaleSettingsScreen()));
                    },
                  ),

                  _buildDrawerItem(
                    icon: Icons.print_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    title: 'थर्मल रसीद प्रिंटर',
                    subtitle: 'Bluetooth 58mm / 80mm प्रिंटर सेटअप',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()));
                    },
                  ),

                  _buildDrawerItem(
                    icon: Icons.cloud_download_rounded,
                    iconColor: const Color(0xFF0D9488),
                    title: 'डेटा बैकअप (Backup)',
                    subtitle: 'लोकल फाइल व Google Drive में सुरक्षित डेटा',
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

                  const Divider(height: 16),

                  // 👤 SECTION 3: सिस्टम व सत्र
                  _buildSectionHeader('👤 सिस्टम व प्राथमिकताएँ (SYSTEM)'),

                  ListTile(
                    leading: const Icon(Icons.translate_rounded, color: Color(0xFF2563EB), size: 22),
                    title: const Text('भाषा बदलें / Language', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
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
                    title: const Text('डार्क / लाइट थीम', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: Text(
                      shopProvider.themeMode == ThemeMode.dark ? 'गहरी थीम (Dark)' : 'हल्की थीम (Light)',
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
                    title: const Text('BillZo POS v1.6.8', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: const Text('सिस्टम अप टू डेट है ✓', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('भाषा चुनें (Select Language)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('हिंदी (Hindi)'),
              trailing: locale.localeCode == 'hi' ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                locale.setLocale('hi');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('English'),
              trailing: locale.localeCode == 'en' ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                locale.setLocale('en');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
