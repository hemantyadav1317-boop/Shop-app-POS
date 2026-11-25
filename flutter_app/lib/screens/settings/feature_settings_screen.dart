import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/payment_notification_service.dart';
import '../../core/services/printer_settings_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/utils/payment_qr_helper.dart';
import '../../data/models/shop.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';
import 'weighing_scale_settings_screen.dart';
import 'ai_vision_settings_screen.dart';

class FeatureSettingsScreen extends StatefulWidget {
  const FeatureSettingsScreen({super.key});

  @override
  State<FeatureSettingsScreen> createState() => _FeatureSettingsScreenState();
}

class _FeatureSettingsScreenState extends State<FeatureSettingsScreen> {
  // UPI
  late TextEditingController _upiIdCtrl;
  late TextEditingController _upiNameCtrl;

  // D-Mart Auto-Verification
  bool _autoVerifyEnabled = true;
  bool _cloudRelayEnabled = false;
  bool _notificationPermissionGranted = false;

  // Stock & Checkout Billing
  late bool _allowNegativeStock;
  late bool _autoRoundOffEnabled;
  late String _roundOffMode;

  // Backup & Sync
  bool _syncingCloud = false;
  bool _backupBusy = false;
  String? _lastBackupAt;

  @override
  void initState() {
    super.initState();
    final shop = context.read<ShopProvider>().shop;
    _upiIdCtrl = TextEditingController(text: shop.upiId ?? '');
    _upiNameCtrl = TextEditingController(text: shop.upiPayeeName ?? '');
    _allowNegativeStock = shop.allowNegativeStock;
    _autoRoundOffEnabled = PrinterSettingsService.instance.autoRoundOffEnabled;
    _roundOffMode = PrinterSettingsService.instance.roundOffMode;

    _autoVerifyEnabled = PaymentNotificationService.instance.isAutoVerifyEnabled;
    _cloudRelayEnabled = PaymentNotificationService.instance.isCloudRelayEnabled;
    _checkNotificationPermission();
    _refreshBackupStatus();
  }

  @override
  void dispose() {
    _upiIdCtrl.dispose();
    _upiNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkNotificationPermission() async {
    final granted = await PaymentNotificationService.instance.checkPermission();
    if (mounted) setState(() => _notificationPermissionGranted = granted);
  }

  Future<void> _refreshBackupStatus() async {
    final info = await BackupService.getLastBackupInfo();
    if (mounted) {
      setState(() {
        _lastBackupAt = info['lastAt'];
      });
    }
  }

  Future<void> _saveUpiAndStock() async {
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: AppColors.error, content: Text('सुरक्षा: केवल दुकान मालिक सेटिंग्स बदल सकते हैं।')),
      );
      return;
    }

    final currentShop = context.read<ShopProvider>().shop;
    final updated = currentShop.copyWith(
      upiId: _upiIdCtrl.text.trim().isEmpty ? null : _upiIdCtrl.text.trim(),
      clearUpiId: _upiIdCtrl.text.trim().isEmpty,
      upiPayeeName: _upiNameCtrl.text.trim().isEmpty ? null : _upiNameCtrl.text.trim(),
      clearUpiPayeeName: _upiNameCtrl.text.trim().isEmpty,
      allowNegativeStock: _allowNegativeStock,
    );
    await context.read<ShopProvider>().updateShop(updated);
    await PrinterSettingsService.instance.setAutoRoundOffEnabled(_autoRoundOffEnabled);
    await PrinterSettingsService.instance.setRoundOffMode(_roundOffMode);
    SoundService.instance.playSuccess();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF00875A),
          content: Text('फ़ीचर सेटिंग्स सुरक्षित कर ली गई हैं! ✓'),
        ),
      );
    }
  }

  void _showStaffPairingQrDialog(BuildContext context, Shop shop) {
    final qrData = 'shoppos://pair?phone=${Uri.encodeComponent(shop.phone ?? '')}&pin=${shop.displayShareCode}&shopId=${shop.id}&name=${Uri.encodeComponent(shop.name)}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text('स्टाफ पेयरिंग QR कोड', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'स्टाफ अपने फोन के BillZo ऐप में इस QR को स्कैन करके तुरंत कनेक्ट कर सकता है।',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('बंद करें (Close)'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateNewStaffPin(BuildContext context) async {
    SoundService.instance.playButtonClick();
    final shopProv = context.read<ShopProvider>();
    final newCode = await shopProv.generateNewShareCode();
    SoundService.instance.playSuccess();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          content: Text('✓ नया स्टाफ पिन जारी किया गया: $newCode'),
        ),
      );
    }
  }

  void _showChangePinDialog(BuildContext context, Shop shop) {
    SoundService.instance.playButtonClick();
    final pinCtrl = TextEditingController(text: shop.displayShareCode);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.pin_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('स्टाफ पिन बदलें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'काउंटर पर स्टाफ या परिवार के लिए 6-अंकीय कस्टम पिन सेट करें:',
              style: TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 4),
              decoration: InputDecoration(
                counterText: '',
                labelText: '6-अंकीय पिन दर्ज करें *',
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('रद्द करें'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final newPin = pinCtrl.text.trim();
              if (newPin.length != 6 || int.tryParse(newPin) == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: Colors.red, content: Text('कृपया ठीक 6 अंकों का संख्यात्मक पिन दर्ज करें')),
                );
                return;
              }
              Navigator.pop(ctx);
              await context.read<ShopProvider>().setCustomShareCode(newPin);
              SoundService.instance.playSuccess();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: AppColors.primary, content: Text('✓ नया स्टाफ पिन सुरक्षित हो गया: $newPin')),
                );
              }
            },
            child: const Text('पिन सुरक्षित करें'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareStaffAccess(Shop shop) async {
    SoundService.instance.playButtonClick();
    final msg = '''🏬 *${shop.name}* में स्टाफ बिलिंग एक्सेस:
📱 दुकान मोबाइल: ${shop.phone ?? 'दर्ज नहीं'}
🔑 6-अंकीय स्टाफ पिन: ${shop.displayShareCode}
🔗 सीधा लॉगिन लिंक: shoppos://pair?phone=${Uri.encodeComponent(shop.phone ?? '')}&pin=${shop.displayShareCode}

ऐप खोलकर 'स्टाफ लॉगिन' में यह मैसेज या पिन डालें और दुकान तुरंत कनेक्ट हो जाएगी!''';

    await Share.share(msg, subject: '${shop.name} Staff Access');
  }

  Future<void> _copyStaffPin(BuildContext context, String pin) async {
    SoundService.instance.playButtonClick();
    await Clipboard.setData(ClipboardData(text: pin));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.primary, content: Text('✓ स्टाफ पिन कॉपी किया गया: $pin')),
      );
    }
  }

  Future<void> _exportBackupToPhone() async {
    setState(() => _backupBusy = true);
    try {
      final shopProv = context.read<ShopProvider>();
      final prodProv = context.read<ProductProvider>();
      final custProv = context.read<CustomerProvider>();
      final sales = await SupabaseService.instance.getSales(shopProv.shop.id);

      final result = await BackupService.exportBackupToPhone(
        shop: shopProv.shop,
        products: prodProv.products,
        customers: custProv.customers,
        sales: sales,
        categoriesConfig: prodProv.exportCategoriesConfig(),
      );
      await _refreshBackupStatus();

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF00875A)),
                SizedBox(width: 8),
                Text('बैकअप तैयार है!'),
              ],
            ),
            content: Text('बैकअप फ़ाइल आपके फोन में सुरक्षित सेव हो गई:\n\n${result.path}'),
            actions: [
              ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('ठीक है')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('बैकअप में त्रुटि: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _syncCloudNow() async {
    setState(() => _syncingCloud = true);
    try {
      final shopId = context.read<ShopProvider>().shop.id;
      final flushed = await SupabaseService.instance.flushSyncOutbox(shopId);
      await context.read<ProductProvider>().loadProducts(shopId);
      await context.read<CustomerProvider>().loadCustomers(shopId);
      await _refreshBackupStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00875A),
            content: Text(flushed > 0 ? 'क्लाउड सिंक पूरा हुआ ($flushed बदलाव अपलोड किए गए) ✓' : 'लोकल और क्लाउड डेटा पूरी तरह सिंक हैं ✓'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('सिंक त्रुटि: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _syncingCloud = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>().shop;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final upiId = _upiIdCtrl.text.trim();
    final payeeName = _upiNameCtrl.text.trim().isNotEmpty ? _upiNameCtrl.text.trim() : shop.name;
    final hasValidUpi = upiId.isNotEmpty && upiId.contains('@');
    final upiUri = hasValidUpi
        ? (PaymentQrHelper.buildUpiUri(upiId: upiId, payeeName: payeeName, amount: 100.0, billNo: 'TEST') ?? '')
        : '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Feature Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ⚡ 1. Auto-Payment Verification Card
            Material(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: const Color(0xFF00875A).withValues(alpha: 0.3)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFF00875A).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.flash_on_rounded, color: Color(0xFF00875A), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('इंस्टैंट ऑटो-पेमेंट वेरिफिकेशन', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                            Text('PhonePe / Paytm / GPay / SMS नोटिफिकेशन से तुरंत ऑटो-वेरिफाई', style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Auto Verify Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _autoVerifyEnabled,
                    activeColor: const Color(0xFF00875A),
                    title: const Text('ऑटो-वेरिफिकेशन ऑन रखें', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('पेमेंट आते ही बिल पर हरा टिक (✓) लग जाएगा', style: TextStyle(fontSize: 11)),
                    onChanged: (val) async {
                      await PaymentNotificationService.instance.setAutoVerifyEnabled(val);
                      setState(() => _autoVerifyEnabled = val);
                    },
                  ),

                  // Notification Permission Check Banner
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _notificationPermissionGranted ? const Color(0xFF00875A).withValues(alpha: 0.1) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _notificationPermissionGranted ? const Color(0xFF00875A).withValues(alpha: 0.3) : const Color(0xFFEF4444),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _notificationPermissionGranted ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          color: _notificationPermissionGranted ? const Color(0xFF00875A) : const Color(0xFFEF4444),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _notificationPermissionGranted
                                ? 'ऑटो-पेमेंट वेरिफिकेशन सेवा सक्रिय (सुरक्षित व तैयार)'
                                : 'नोटिफिकेशन एक्सेस बंद है! ऑटो-डिटेक्ट के लिए परमिशन दें',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _notificationPermissionGranted ? const Color(0xFF00875A) : const Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                        if (!_notificationPermissionGranted)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () async {
                              await PaymentNotificationService.instance.openSettings();
                              await Future.delayed(const Duration(seconds: 1));
                              _checkNotificationPermission();
                            },
                            child: const Text('Allow', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),

                  // Cloud Relay Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _cloudRelayEnabled,
                    activeColor: const Color(0xFF00875A),
                    title: const Text('क्लाउड रिले (Owner Phone -> Counter Tablet/PC)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('अगर आप टैबलेट या PC पर बिलिंग करते हैं और पेमेंट फोन पर आती है', style: TextStyle(fontSize: 11)),
                    onChanged: (val) async {
                      await PaymentNotificationService.instance.setCloudRelayEnabled(val);
                      setState(() => _cloudRelayEnabled = val);
                    },
                  ),

                  // Test Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00875A),
                        side: const BorderSide(color: Color(0xFF00875A)),
                      ),
                      icon: const Icon(Icons.science_outlined, size: 16),
                      label: const Text('🧪 ₹1 का टेस्ट पेमेंट चलाएं', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        await PaymentNotificationService.instance.simulatePayment(amount: 1.0, appName: 'Rahul Sharma (PhonePe)');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF00875A),
                              content: Text('टेस्ट पेमेंट ₹1 ट्रिगर किया गया! चेकआउट स्क्रीन पर देखें।'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            ),
            const SizedBox(height: 16),

            // 💳 2. UPI Payment Settings Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('दुकान का UPI पेमेंट QR (Dynamic QR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                  const SizedBox(height: 4),
                  Text('ग्राहकों को बिल स्क्रीन पर स्कैन करने के लिए UPI ID सेट करें', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _upiIdCtrl,
                    decoration: InputDecoration(
                      labelText: 'UPI ID (VPA) *',
                      hintText: 'उदा. shopname@upi ya 9876543210@paytm',
                      prefixIcon: const Icon(Icons.qr_code),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _upiNameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Payee Name (दुकानदार का नाम)',
                      hintText: 'उदा. श्री गणेश किराना',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (hasValidUpi) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                        child: QrImageView(data: upiUri, version: QrVersions.auto, size: 140, backgroundColor: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 👥 3. Staff & Family Sharing Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('स्टाफ व परिवार एक्सेस (Cashier PIN)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                  const SizedBox(height: 4),
                  Text('काउंटर पर भाई, पिताजी या कर्मचारी को केवल बिलिंग अधिकार दें', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('6-Digit Staff PIN:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(
                              shop.displayShareCode,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 3, color: AppColors.primary),
                            ),
                          ],
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          tooltip: 'पिन कॉपी करें',
                          onPressed: () => _copyStaffPin(context, shop.displayShareCode),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('नया पिन बनाएं'),
                          onPressed: () => _generateNewStaffPin(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('पिन बदलें'),
                          onPressed: () => _showChangePinDialog(context, shop),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            elevation: 1,
                          ),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('WhatsApp शेयर', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _shareStaffAccess(shop),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                          label: const Text('Pairing QR'),
                          onPressed: () => _showStaffPairingQrDialog(context, shop),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 💾 4. Backup & Cloud Sync Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('डेटा बैकअप व क्लाउड सिंक', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                  const SizedBox(height: 4),
                  Text('अपने प्रोडक्ट्स, बिक्री और ग्राहकों का सुरक्षित ऑफलाइन बैकअप बनाएं', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                          icon: _backupBusy
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Export Backup'),
                          onPressed: _backupBusy ? null : _exportBackupToPhone,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: _syncingCloud
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.cloud_sync_rounded, size: 18),
                          label: const Text('Cloud Sync'),
                          onPressed: _syncingCloud ? null : _syncCloudNow,
                        ),
                      ),
                    ],
                  ),
                  if (_lastBackupAt != null) ...[
                    const SizedBox(height: 8),
                    Text('अंतिम बैकअप: $_lastBackupAt', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 📦 5. Negative Stock Control Card
            Material(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _allowNegativeStock,
                  activeThumbColor: AppColors.primary,
                  title: const Text('नेगेटिव स्टॉक में बिक्री की अनुमति (Negative Stock)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: const Text('स्टॉक 0 होने पर भी बिल बनाने की अनुमति दें', style: TextStyle(fontSize: 11.5)),
                  onChanged: (val) {
                    SoundService.instance.playButtonClick();
                    setState(() => _allowNegativeStock = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 💰 5b. Auto Round-Off Bill Total Card
            Material(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _autoRoundOffEnabled,
                      activeThumbColor: AppColors.primary,
                      title: const Text(
                        'बिल अमाउंट राउंड फिगर (Auto Round-Off)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      subtitle: const Text(
                        'चेकआउट के समय पैसे (जैसे ₹451.75 / ₹451.80) को ऑटो .00 में बदलें',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      onChanged: (val) async {
                        if (context.read<AuthProvider>().isStaffSession) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.error,
                              content: Text('सुरक्षा: केवल दुकान मालिक सेटिंग्स बदल सकते हैं।'),
                            ),
                          );
                          return;
                        }
                        SoundService.instance.playButtonClick();
                        setState(() => _autoRoundOffEnabled = val);
                        await PrinterSettingsService.instance.setAutoRoundOffEnabled(val);
                      },
                    ),
                    if (_autoRoundOffEnabled) ...[
                      const Divider(height: 16),
                      const Text(
                        'राउंड करने का नियम चुनें (Rounding Rule):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      RadioGroup<String>(
                        groupValue: _roundOffMode,
                        onChanged: (val) async {
                          if (val == null) return;
                          SoundService.instance.playClick();
                          setState(() => _roundOffMode = val);
                          await PrinterSettingsService.instance.setRoundOffMode(val);
                        },
                        child: const Column(
                          children: [
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: 'nearest',
                              title: Text('नज़दीकी रुपया (Nearest Rupee)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: Text('₹451.75 / ₹451.80 → ₹452.00 · ₹436.40 → ₹436.00', style: TextStyle(fontSize: 11)),
                            ),
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: 'floor',
                              title: Text('पैसे हटाएं (Drop Paise / Floor)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: Text('₹451.75 / ₹451.80 → ₹451.00 (हमेशा पैसे .00 करें)', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 🔊 6. POS Sound & Haptics Card
            Material(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: SoundService.instance.isSoundEnabled,
                      activeThumbColor: const Color(0xFF00875A),
                      title: const Text('बिलिंग साउंड इफेक्ट्स (Beep & Cash Sound)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: const Text('स्कैनर बीप, कीपैड टैप और बिल पूरा होने पर आवाज़ पाएं', style: TextStyle(fontSize: 11.5)),
                      onChanged: (val) async {
                        await SoundService.instance.setSoundEnabled(val);
                        if (val) SoundService.instance.playBeep();
                        setState(() {});
                      },
                    ),
                    if (SoundService.instance.isSoundEnabled) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(onPressed: () => SoundService.instance.playBeep(), child: const Text('Beep')),
                          OutlinedButton(onPressed: () => SoundService.instance.playClick(), child: const Text('Click')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00875A), foregroundColor: Colors.white),
                            onPressed: () => SoundService.instance.playSuccess(),
                            child: const Text('Cha-Ching!'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ⚖️ 7. Electronic Weighing Scale Tile
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              tileColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              leading: const Icon(Icons.scale_rounded, color: AppColors.primary),
              title: const Text('इलेक्ट्रॉनिक वेइंग स्केल (Weighing Scale)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Bluetooth या USB तराजू कनेक्ट करें', style: TextStyle(fontSize: 11.5)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeighingScaleSettingsScreen())),
            ),
            const SizedBox(height: 12),

            // 👁️ 8. AI Vision Scanner Tile
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              tileColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              leading: const Icon(Icons.visibility_rounded, color: AppColors.primary),
              title: const Text('AI विजन कैमरा स्कैनर (AI Vision)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('सब्जी/फल को कैमरा से पहचान कर बिल बनाएं', style: TextStyle(fontSize: 11.5)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiVisionSettingsScreen())),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: const Text('Save Feature Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: _saveUpiAndStock,
            ),
          ),
        ),
      ),
    );
  }
}
