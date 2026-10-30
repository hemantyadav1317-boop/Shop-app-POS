import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/update_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/receipt_print_service.dart';
import '../../core/services/bluetooth_printer_service.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../data/models/sale.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/shop.dart';
import '../../data/services/upi_service.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/shop_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/customer_provider.dart';
import '../auth/login_screen.dart';
import 'printer_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _gstinCtrl;
  late TextEditingController _upiIdCtrl;
  late TextEditingController _upiNameCtrl;
  late TextEditingController _footerCtrl;
  late String _paperSize;
  late bool _allowNegativeStock;
  String? _qrImageUrl;

  String? _btPrinterName;
  String? _btPrinterMac;
  bool _btIsConnected = false;
  bool _isConnectingBt = false;
  bool _isSyncingCloud = false;

  @override
  void initState() {
    super.initState();
    final shop = context.read<ShopProvider>().shop;
    _nameCtrl = TextEditingController(text: shop.name);
    _phoneCtrl = TextEditingController(text: shop.phone ?? '');
    _addressCtrl = TextEditingController(text: shop.address ?? '');
    _gstinCtrl = TextEditingController(text: shop.gstin ?? '');
    _upiIdCtrl = TextEditingController(text: shop.upiId ?? '');
    _upiNameCtrl = TextEditingController(text: shop.upiPayeeName ?? '');
    _footerCtrl = TextEditingController(text: shop.receiptFooter ?? 'धन्यवाद! फिर पधारें 🙏');
    _paperSize = shop.printPaperSize;
    _allowNegativeStock = shop.allowNegativeStock;
    _qrImageUrl = shop.qrImageUrl;

    _upiIdCtrl.addListener(() => setState(() {}));
    _upiNameCtrl.addListener(() => setState(() {}));

    void attachTypeSound(TextEditingController ctrl) {
      String prev = ctrl.text;
      ctrl.addListener(() {
        if (ctrl.text != prev) {
          prev = ctrl.text;
          SoundService.instance.playTypeKey();
        }
      });
    }

    attachTypeSound(_nameCtrl);
    attachTypeSound(_phoneCtrl);
    attachTypeSound(_addressCtrl);
    attachTypeSound(_gstinCtrl);
    attachTypeSound(_upiIdCtrl);
    attachTypeSound(_upiNameCtrl);
    attachTypeSound(_footerCtrl);

    _loadBtPrinterInfo();
  }

  Future<void> _loadBtPrinterInfo() async {
    final mac = await BluetoothPrinterService.getSavedPrinterMac();
    final name = await BluetoothPrinterService.getSavedPrinterName();
    final connected = await BluetoothPrinterService.isConnected();
    if (mounted) {
      setState(() {
        _btPrinterMac = mac;
        _btPrinterName = name;
        _btIsConnected = connected;
      });
    }
  }

  Future<void> _selectBluetoothPrinter() async {
    setState(() => _isConnectingBt = true);

    // 1. Request Android Nearby Devices / Bluetooth permission prompt
    try {
      await BluetoothPrinterService.isPermissionGranted();
    } catch (_) {}

    // 2. Fetch paired devices
    List<BluetoothInfo> devices = [];
    try {
      devices = await BluetoothPrinterService.getPairedDevices();
    } catch (e) {
      debugPrint("Error fetching devices: $e");
    }

    if (mounted) {
      setState(() => _isConnectingBt = false);
    }
    if (!mounted) return;

    if (devices.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.bluetooth_searching, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Niyama BT-58 प्रिंटर नहीं मिला',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Niyama BT-58 प्रिंटर को कनेक्ट करने का आसान तरीका:\n',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                '1. अपने Niyama प्रिंटर का पावर बटन ऑन करें (Green light ऑन होगी)।\n'
                '2. अपने फ़ोन / टैबलेट की Bluetooth Settings खोलें।\n'
                '3. "Pair new device" में "BT-58" या "Niyama" दिखेगा, उस पर टैप करके Pair करें (PIN: 0000 या 1234 डालें)।\n'
                '4. फ़ोन में Pair होने के बाद वापस इस ऐप में आकर "प्रिंटर खोजें" दबाएं।',
                style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.lightTextPrimary),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('समझ गया (OK)'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.print, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('उपलब्ध ब्लूटूथ प्रिंटर चुनें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (ctx, i) {
                    final d = devices[i];
                    final isSelected = d.macAdress == _btPrinterMac;
                    return ListTile(
                      leading: Icon(Icons.bluetooth, color: isSelected ? AppColors.primary : Colors.grey),
                      title: Text(d.name.isNotEmpty ? d.name : 'Unknown Thermal Printer', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(d.macAdress, style: const TextStyle(fontSize: 11)),
                      trailing: isSelected
                          ? const Chip(label: Text('चुना हुआ', style: TextStyle(fontSize: 11, color: Colors.green)), backgroundColor: Color(0xFFE8F5E9))
                          : const Icon(Icons.chevron_right),
                      onTap: () async {
                        Navigator.pop(ctx);
                        setState(() => _isConnectingBt = true);
                        final ok = await BluetoothPrinterService.connectPrinter(d.macAdress);
                        await BluetoothPrinterService.saveSelectedPrinter(d.macAdress, d.name);
                        if (ok) {
                          SoundService.instance.playSuccess();
                        } else {
                          SoundService.instance.playButtonClick();
                        }
                        if (mounted) {
                          setState(() {
                            _btPrinterMac = d.macAdress;
                            _btPrinterName = d.name;
                            _btIsConnected = ok;
                            _isConnectingBt = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: ok ? AppColors.primary : AppColors.warning,
                              content: Text(ok ? '${d.name} प्रिंटर सफलतापूर्वक कनेक्ट हो गया!' : '${d.name} सेव हो गया (प्रिंट करते समय कनेक्ट होगा)'),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _gstinCtrl.dispose();
    _upiIdCtrl.dispose();
    _upiNameCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  void _confirmLogout(BuildContext context) {
    SoundService.instance.playButtonClick();
    final authProvider = context.read<AuthProvider>();
    final shop = context.read<ShopProvider>().shop;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
  }

  Widget _buildStoreModeCard(BuildContext context, ShopProvider shopProvider) {
    final currentType = shopProvider.storeType;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final modes = [
      {
        'id': 'vegetable',
        'title': 'फल व सब्ज़ी स्टोर (Produce Store)',
        'subtitle': 'तौल-आधारित (Kg/Gram), टच-स्क्रीन काउंटर',
        'icon': '🥕',
        'tag': 'टच फर्स्ट',
        'color': const Color(0xFF00875A),
      },
      {
        'id': 'kirana',
        'title': 'किराना व जनरल स्टोर (Kirana & Grocery)',
        'subtitle': 'बारकोड गन स्कैन, 2026 MRP, पैकेट वैरिएंट, मुनाफा मार्जिन',
        'icon': '🛒',
        'tag': 'बारकोड & MRP',
        'color': const Color(0xFF2563EB),
      },
      {
        'id': 'mix',
        'title': 'मिक्स सुपरमार्ट (Produce + Grocery)',
        'subtitle': 'किराना सामान + ताज़ा फल-सब्ज़ी एक ही बिल में',
        'icon': '🏪',
        'tag': 'ऑल-इन-वन',
        'color': const Color(0xFF7C3AED),
      },
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: currentType == 'kirana'
              ? const Color(0xFF2563EB).withValues(alpha: 0.4)
              : (currentType == 'mix'
                  ? const Color(0xFF7C3AED).withValues(alpha: 0.4)
                  : const Color(0xFF00875A).withValues(alpha: 0.4)),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (currentType == 'kirana'
                            ? const Color(0xFF2563EB)
                            : (currentType == 'mix' ? const Color(0xFF7C3AED) : const Color(0xFF00875A)))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    currentType == 'kirana' ? '🛒' : (currentType == 'mix' ? '🏪' : '🥕'),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'दुकान का प्रकार (Store Business Mode)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'अपनी दुकान के अनुसार बिलिंग इंटरफेस चुनें',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...modes.map((m) {
              final isSelected = currentType == m['id'];
              final color = m['color'] as Color;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () async {
                    SoundService.instance.playButtonClick();
                    await shopProvider.setStoreType(m['id'] as String);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: color,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          content: Row(
                            children: [
                              Text(m['icon'] as String, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('मोड बदला गया: "${m['title']}" सक्रिय है!'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: isDark ? 0.2 : 0.08)
                          : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : (isDark ? Colors.white12 : Colors.grey.shade300),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(m['icon'] as String, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    m['title'] as String,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: isSelected ? color : null,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      m['tag'] as String,
                                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                m['subtitle'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? color : Colors.grey.shade400,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    FocusScope.of(context).unfocus();
    final currentShop = context.read<ShopProvider>().shop;
    final updated = currentShop.copyWith(
      name: _nameCtrl.text.trim().isEmpty ? 'Shop POS' : _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      gstin: _gstinCtrl.text.trim().isEmpty ? null : _gstinCtrl.text.trim(),
      upiId: _upiIdCtrl.text.trim().isEmpty ? null : _upiIdCtrl.text.trim(),
      upiPayeeName: _upiNameCtrl.text.trim().isEmpty ? null : _upiNameCtrl.text.trim(),
      receiptFooter: _footerCtrl.text.trim(),
      printPaperSize: _paperSize,
      allowNegativeStock: _allowNegativeStock,
      qrImageUrl: _qrImageUrl,
    );

    await context.read<ShopProvider>().updateShop(updated);
    SoundService.instance.playSuccess();

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF00875A).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00875A), size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'All Details Saved Successfully! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Color(0xFF00875A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'दुकान की सभी जानकारी व सेटिंग्स सफलतापूर्वक सुरक्षित कर ली गई हैं।',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.35),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00875A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ठीक है (Done)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _handleManualCloudSync() async {
    setState(() => _isSyncingCloud = true);
    try {
      final auth = context.read<AuthProvider>();
      final shopProvider = context.read<ShopProvider>();
      final productProvider = context.read<ProductProvider>();
      final customerProvider = context.read<CustomerProvider>();

      Shop targetShop = shopProvider.shop;
      final u = auth.user;
      if (u != null) {
        targetShop = await SupabaseService.instance.syncUserShop(
          userId: u.id,
          userEmail: u.email ?? '',
          fallback: targetShop,
        );
        if (targetShop.id != shopProvider.shop.id) {
          await shopProvider.setShop(targetShop);
        }
      }

      final summary = await SupabaseService.instance.syncAllCloudData(targetShop.id);
      await productProvider.loadProducts(targetShop.id);
      await customerProvider.loadCustomers(targetShop.id);

      if (mounted) {
        SoundService.instance.playSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Row(
              children: [
                const Icon(Icons.cloud_done, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'क्लाउड सिंक सफल! प्रोडक्ट्स: ${summary['products']}, ग्राहक: ${summary['customers']}, बिल: ${summary['sales']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('सिंक एरर: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingCloud = false);
      }
    }
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
              child: Text('मौजूदा दुकान से जुड़ें / Join Shop', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'यदि आपके भाई या पिता ने पहले से दुकान बना रखी है, तो उनका दुकान कोड (Shop ID) यहाँ दर्ज करें:',
              style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
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

              SoundService.instance.playButtonClick();
              final shopProv = context.read<ShopProvider>();
              final joined = await shopProv.joinShop(code);

              if (context.mounted) {
                // Reload data for this shop
                final prodProv = context.read<ProductProvider>();
                final custProv = context.read<CustomerProvider>();
                await prodProv.loadProducts(joined.id);
                await custProv.loadCustomers(joined.id);
                await SupabaseService.instance.getSales(joined.id);

                // Update text controllers in settings so new shop details show immediately
                _nameCtrl.text = joined.name;
                _phoneCtrl.text = joined.phone ?? '';
                _addressCtrl.text = joined.address ?? '';
                _gstinCtrl.text = joined.gstin ?? '';
                _upiIdCtrl.text = joined.upiId ?? '';
                _upiNameCtrl.text = joined.upiPayeeName ?? '';
                _footerCtrl.text = joined.receiptFooter ?? 'धन्यवाद! फिर पधारें 🙏';
                _qrImageUrl = joined.qrImageUrl;
                _paperSize = joined.printPaperSize;
                _allowNegativeStock = joined.allowNegativeStock;

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (context.mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.primary,
                      content: Text('दुकान "${joined.name}" से सफलतापूर्वक जुड़ गए!'),
                    ),
                  );
                }
              }
            },
            child: const Text('दुकान से जुड़ें (Join)'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, String shopId) {
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_add, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text('सदस्य जोड़ें / Add Family or Staff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'अपने भाई, पिता या स्टाफ का Google Email दर्ज करें ताकि उन्हें इस दुकान का पूर्ण एक्सेस मिल सके:',
              style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'ईमेल पता (Gmail / Email) *',
                hintText: 'brother@gmail.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.primary,
                  content: Text('$email को दुकान एक्सेस के लिए जोड़ दिया गया है'),
                ),
              );
            },
            child: const Text('एक्सेस दें (Invite)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = context.watch<ShopProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentShop = shopProvider.shop;

    final upiId = _upiIdCtrl.text.trim();
    final payeeName = _upiNameCtrl.text.trim().isNotEmpty ? _upiNameCtrl.text.trim() : currentShop.name;
    final hasValidUpi = upiId.isNotEmpty && upiId.contains('@');
    final upiUri = hasValidUpi
        ? UpiService.generateUpiUri(upiId: upiId, payeeName: payeeName, amount: 100.0, note: 'POS Payment Test')
        : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('सेटिंग्स / Shop Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Account Profile Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primarySurface,
                      radius: 22,
                      child: const Icon(Icons.person, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authProvider.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            authProvider.email ?? (authProvider.isGuestMode ? 'ऑफ़लाइन मोड (Guest)' : 'लॉगिन नहीं है'),
                            style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _confirmLogout(context),
                      child: const Text('लॉगआउट', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 🏪 3-Door Store Mode Switcher Card
            _buildStoreModeCard(context, shopProvider),
            const SizedBox(height: 12),

            // 🖨️ Dedicated Printer Settings Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: const Color(0xFF00875A).withValues(alpha: 0.3)),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00875A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.print_rounded, color: Color(0xFF00875A), size: 24),
                ),
                title: const Text(
                  '🖨️ प्रिंटर सेटिंग्स (Printer Settings)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: const Text(
                  'ब्लूटूथ प्रिंटर, फ़ॉन्ट साइज़ और बिल लेआउट कस्टमाइज़ करें',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF00875A)),
                onTap: () {
                  SoundService.instance.playButtonClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // ☁️ Multi-Device Cloud Sync Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: (currentShop.id.length >= 30)
                      ? Colors.green.shade400
                      : Colors.orange.shade400,
                  width: 1.2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_sync,
                          color: (currentShop.id.length >= 30)
                              ? Colors.green.shade700
                              : Colors.orange.shade800,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'मल्टी-डिवाइस क्लाउड सिंक स्थिति',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Theme.of(context).textTheme.titleMedium?.color,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (currentShop.id.length >= 30)
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (currentShop.id.length >= 30)
                                  ? Colors.green.shade300
                                  : Colors.orange.shade300,
                            ),
                          ),
                          child: Text(
                            (currentShop.id.length >= 30) ? '🟢 लाइव सिंक' : '🟠 ऑफ़लाइन / डेमो',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: (currentShop.id.length >= 30)
                                  ? Colors.green.shade800
                                  : Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black26
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('लॉगिन ईमेल: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Text(
                                  authProvider.email ?? 'लॉगिन नहीं है (Guest Mode)',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isSyncingCloud
                            ? null
                            : () {
                                SoundService.instance.playButtonClick();
                                _handleManualCloudSync();
                              },
                        icon: _isSyncingCloud
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.sync, size: 18),
                        label: Text(
                          _isSyncingCloud ? 'सिंक हो रहा है...' : 'Sync Data (डेटा सिंक)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Family & Staff Sharing Card (Bhai / Father Access)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primarySurface.withOpacity(0.3),
                      Theme.of(context).cardColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.people_alt, color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'दुकान शेयरिंग / Family & Staff Access',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'अपने भाई, पिता या पार्टनर को दुकान का एक्सेस देने के लिए यह दुकान कोड साझा करें:',
                      style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                    ),
                    const SizedBox(height: 10),

                    // Shop Code Box with Copy & Share
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.qr_code_2, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('आपकी दुकान का कोड (Shop ID):', style: TextStyle(fontSize: 10, color: AppColors.lightTextSecondary)),
                                SelectableText(
                                  currentShop.id,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18, color: AppColors.primary),
                            tooltip: 'कोड कॉपी करें',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: currentShop.id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('दुकान कोड कॉपी हो गया!')),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.share, size: 18, color: Colors.green),
                            tooltip: 'WhatsApp पर भेजें',
                            onPressed: () async {
                              final text = 'नमस्ते, यह हमारी दुकान "${currentShop.name}" का POS ऐप कोड है:\n${currentShop.id}\n\nऐप में लॉगिन करके इस कोड से दुकान कनेक्ट कर सकते हैं।';
                              final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              } else {
                                Clipboard.setData(ClipboardData(text: text));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('शेयरिंग मैसेज कॉपी हो गया!')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.person_add_alt_1, size: 15),
                            label: const Text('सदस्य जोड़ें (+ Member)', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            onPressed: () => _showAddMemberDialog(context, currentShop.id),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.login, size: 15),
                            label: const Text('दुकान से जुड़ें (Join)', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            onPressed: () => _showJoinShopDialog(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Store Profile Details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('दुकान की जानकारी / Store Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'दुकान का नाम *', prefixIcon: Icon(Icons.storefront))),
                    const SizedBox(height: 10),
                    TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'मोबाइल नंबर', prefixIcon: Icon(Icons.phone))),
                    const SizedBox(height: 10),
                    TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'पता (Address)', prefixIcon: Icon(Icons.location_on_outlined))),
                    const SizedBox(height: 10),
                    TextField(controller: _gstinCtrl, decoration: const InputDecoration(labelText: 'GSTIN (वैकल्पिक)', prefixIcon: Icon(Icons.receipt_outlined))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // UPI QR Code Settings with Live QR & Custom QR upload
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.qr_code, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('UPI पेमेंट सेटिंग्स व QR कोड', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'बिलिंग के समय ग्राहक सीधे आपके UPI QR कोड को स्कैन कर के भुगतान कर सकते हैं।',
                      style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _upiIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'दुकानदार की UPI ID * (उदा. 9876543210@paytm, shop@okhdfcbank)',
                        prefixIcon: Icon(Icons.payment),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _upiNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Payee Name (दुकान या खाताधारक का नाम)',
                        prefixIcon: Icon(Icons.person_pin_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // QR Code Options & Live Preview Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'दुकान का QR कोड (QR Code Preview)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'आप ऑटोमैटिक UPI QR उपयोग कर सकते हैं या अपनी दुकान का स्टैंडी QR फोटो लगा सकते हैं:',
                            style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                          ),
                          const SizedBox(height: 10),

                          // QR Image Upload Action Buttons
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.photo_camera, size: 14),
                                label: const Text('कैमरा से QR फोटो लें', style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () async {
                                  try {
                                    final img = await ImagePicker().pickImage(
                                      source: ImageSource.camera,
                                      maxWidth: 800,
                                      maxHeight: 800,
                                    );
                                    if (img != null) {
                                      final bytes = await img.readAsBytes();
                                      final shop = context.read<ShopProvider>().shop;
                                      final uploadedUrl = await SupabaseService.instance.uploadImageBytes(
                                        shopId: shop.id,
                                        folder: 'qr',
                                        fileName: 'shop_qr_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                        bytes: bytes,
                                      );
                                      setState(() => _qrImageUrl = uploadedUrl);
                                      SoundService.instance.playSuccess();
                                    }
                                  } catch (e) {
                                    debugPrint("QR Pick Camera error: $e");
                                  }
                                },
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.photo_library, size: 14),
                                label: const Text('गैलरी से QR चुनें', style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () async {
                                  try {
                                    final img = await ImagePicker().pickImage(
                                      source: ImageSource.gallery,
                                      maxWidth: 800,
                                      maxHeight: 800,
                                    );
                                    if (img != null) {
                                      final bytes = await img.readAsBytes();
                                      final shop = context.read<ShopProvider>().shop;
                                      final uploadedUrl = await SupabaseService.instance.uploadImageBytes(
                                        shopId: shop.id,
                                        folder: 'qr',
                                        fileName: 'shop_qr_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                        bytes: bytes,
                                      );
                                      setState(() => _qrImageUrl = uploadedUrl);
                                      SoundService.instance.playSuccess();
                                    }
                                  } catch (e) {
                                    debugPrint("QR Pick Gallery error: $e");
                                  }
                                },
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.link, size: 14),
                                label: const Text('QR इमेज लिंक (URL)', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () {
                                  final urlCtrl = TextEditingController(text: _qrImageUrl?.startsWith('http') == true ? _qrImageUrl : '');
                                  showDialog(
                                    context: context,
                                    builder: (uCtx) => AlertDialog(
                                      title: const Text('QR कोड इमेज URL दर्ज करें', style: TextStyle(fontSize: 14)),
                                      content: TextField(
                                        controller: urlCtrl,
                                        decoration: const InputDecoration(
                                          hintText: 'https://example.com/shop-qr.png',
                                          prefixIcon: Icon(Icons.link),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(uCtx), child: const Text('Cancel')),
                                        ElevatedButton(
                                          onPressed: () {
                                            final val = urlCtrl.text.trim();
                                            if (val.isNotEmpty) {
                                              setState(() => _qrImageUrl = val);
                                              SoundService.instance.playSuccess();
                                            }
                                            Navigator.pop(uCtx);
                                          },
                                          child: const Text('Set QR'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              if (_qrImageUrl != null && _qrImageUrl!.isNotEmpty)
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 14),
                                  label: const Text('फोटो हटाएं', style: TextStyle(color: AppColors.error, fontSize: 11)),
                                  onPressed: () {
                                    SoundService.instance.playDelete();
                                    setState(() => _qrImageUrl = null);
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // QR Preview Box
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.lightBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_qrImageUrl != null && _qrImageUrl!.isNotEmpty) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _qrImageUrl!.startsWith('data:image')
                                          ? Image.memory(
                                              base64Decode(_qrImageUrl!.split(',').last),
                                              width: 150,
                                              height: 150,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 80, color: AppColors.error),
                                            )
                                          : _qrImageUrl!.startsWith('http')
                                              ? Image.network(
                                                  _qrImageUrl!,
                                                  width: 150,
                                                  height: 150,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 80, color: AppColors.error),
                                                )
                                              : (!kIsWeb
                                                  ? Image.file(
                                                      File(_qrImageUrl!),
                                                      width: 150,
                                                      height: 150,
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 80, color: AppColors.error),
                                                    )
                                                  : const Icon(Icons.qr_code_2, size: 100, color: AppColors.primary)),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text('दुकान का स्टैंडी QR फोटो सेट है', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                                  ] else if (hasValidUpi) ...[
                                    QrImageView(
                                      data: upiUri,
                                      version: QrVersions.auto,
                                      size: 150.0,
                                      backgroundColor: Colors.white,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      payeeName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.lightTextPrimary),
                                    ),
                                    Text(
                                      upiId,
                                      style: const TextStyle(fontSize: 10, color: AppColors.lightTextSecondary),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.green.shade200),
                                      ),
                                      child: const Text('✓ लाइव UPI QR एक्टिव है', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                    ),
                                  ] else ...[
                                    const Icon(Icons.qr_code_2, size: 80, color: AppColors.lightTextSecondary),
                                    const SizedBox(height: 6),
                                    const Text('ऊपर UPI ID दर्ज करें या QR फोटो लगाएं', style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Thermal Printer & Negative Stock (RESPONSIVE FIX FOR 58mm/80mm)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.print, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text('थर्मल प्रिंटर और बिल सेटिंग्स', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Interactive Bluetooth Printer Setup Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _btPrinterMac != null ? Colors.green.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _btPrinterMac != null ? Colors.green.shade200 : Colors.blue.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _btPrinterMac != null ? Icons.bluetooth_connected : Icons.bluetooth,
                                color: _btPrinterMac != null ? Colors.green.shade800 : Colors.blue.shade800,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _btPrinterMac != null
                                      ? 'प्रिंटर: ${_btPrinterName ?? "Thermal Printer"}'
                                      : 'ब्लूटूथ थर्मल प्रिंटर सेट करें (Direct Print)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _btPrinterMac != null ? Colors.green.shade900 : Colors.blue.shade900,
                                  ),
                                ),
                              ),
                              if (_btPrinterMac != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _btIsConnected ? 'कनेक्टेड / Online' : 'सक्रिय / Saved',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ),
                            ],
                          ),
                          if (_btPrinterMac != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'MAC Address: $_btPrinterMac',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                icon: _isConnectingBt
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.bluetooth_searching, size: 16),
                                label: Text(_btPrinterMac == null ? 'प्रिंटर खोजें व कनेक्ट करें' : 'प्रिंटर बदलें'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _isConnectingBt ? null : _selectBluetoothPrinter,
                              ),
                              if (_btPrinterMac != null)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.link_off, size: 16, color: Colors.red),
                                  label: const Text('हटाएं', style: TextStyle(color: Colors.red, fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () async {
                                    await BluetoothPrinterService.forgetPrinter();
                                    setState(() {
                                      _btPrinterMac = null;
                                      _btPrinterName = null;
                                      _btIsConnected = false;
                                    });
                                  },
                                ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.print, size: 16),
                                label: const Text('टेस्ट प्रिंट (Slip)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () async {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('प्रिंटर को टेस्ट प्रिंट भेजा जा रहा है...')),
                                  );
                                  final directOk = await BluetoothPrinterService.printTestReceipt(
                                    currentShop.copyWith(printPaperSize: _paperSize),
                                  );
                                  if (directOk && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Colors.green,
                                        content: Text('✅ टेस्ट प्रिंट सफलतापूर्वक निकल गया!'),
                                      ),
                                    );
                                  } else if (mounted) {
                                    // Fallback to receipt print
                                    final testSale = Sale(
                                      id: 'test-print-${DateTime.now().millisecondsSinceEpoch}',
                                      shopId: currentShop.id,
                                      billNo: 101,
                                      createdAt: DateTime.now(),
                                      paymentMode: 'cash',
                                      subtotal: 140.0,
                                      discount: 0.0,
                                      total: 140.0,
                                      paid: 140.0,
                                      due: 0.0,
                                      items: [
                                        CartItem(productId: 'test-1', name: 'चावल (Rice 1kg)', unit: 'kg', price: 90.0, qty: 1),
                                        CartItem(productId: 'test-2', name: 'चीनी (Sugar 1kg)', unit: 'kg', price: 50.0, qty: 1),
                                      ],
                                    );
                                    await ReceiptPrintService.printReceipt(
                                      sale: testSale,
                                      shop: currentShop.copyWith(printPaperSize: _paperSize),
                                      shopEmail: authProvider.email,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Clean responsive full-width segmented button for 58mm / 80mm
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'थर्मल पेपर साइज / Thermal Paper Size:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: '58mm',
                                icon: Icon(Icons.receipt_outlined, size: 16),
                                label: Text('58 mm (छोटा रोल)'),
                              ),
                              ButtonSegment(
                                value: '80mm',
                                icon: Icon(Icons.receipt_long_outlined, size: 16),
                                label: Text('80 mm (बड़ा रोल)'),
                              ),
                            ],
                            selected: {_paperSize},
                            onSelectionChanged: (val) {
                              setState(() => _paperSize = val.first);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _footerCtrl,
                      decoration: const InputDecoration(
                        labelText: 'रसीद पर नीचे का संदेश (Receipt Footer)',
                        prefixIcon: Icon(Icons.format_quote),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      title: const Text('नेगेटिव स्टॉक की अनुमति (Negative Stock)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('स्टॉक 0 होने पर भी बिल बनाने की अनुमति दें', style: TextStyle(fontSize: 11)),
                      value: _allowNegativeStock,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        SoundService.instance.playButtonClick();
                        setState(() => _allowNegativeStock = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            // 🔊 POS Sound & Haptics Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.volume_up_rounded, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'साउंड व टच इफेक्ट्स / POS Sound & Haptics',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'बिलिंग काउंटर पर प्रोडक्ट जोड़ने, कीपैड टच करने और बिल पेमेंट पूरा होने पर आवाज़ व वाइब्रेशन पाएं।',
                      style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('बिलिंग साउंड इफेक्ट्स (Beep & Cash Sound)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        SoundService.instance.isSoundEnabled ? 'चालू (Enabled)' : 'बंद (Muted)',
                        style: TextStyle(fontSize: 11, color: SoundService.instance.isSoundEnabled ? Colors.green : Colors.grey),
                      ),
                      value: SoundService.instance.isSoundEnabled,
                      onChanged: (val) async {
                        await SoundService.instance.setSoundEnabled(val);
                        if (val) {
                          SoundService.instance.playBeep();
                        }
                        setState(() {});
                      },
                    ),
                    if (SoundService.instance.isSoundEnabled) ...[
                      const Divider(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.qr_code_scanner, size: 16),
                            label: const Text('स्कैनर बीप (Beep)', style: TextStyle(fontSize: 12)),
                            onPressed: () => SoundService.instance.playBeep(),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.touch_app, size: 16),
                            label: const Text('कीपैड टैप (Click)', style: TextStyle(fontSize: 12)),
                            onPressed: () => SoundService.instance.playClick(),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.monetization_on, size: 16),
                            label: const Text('बिल सफलता (Cha-Ching)', style: TextStyle(fontSize: 12)),
                            onPressed: () => SoundService.instance.playSuccess(),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Theme Mode Toggle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('थीम / Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('☀️ Light')),
                            selected: shopProvider.themeMode == ThemeMode.light,
                            onSelected: (_) => shopProvider.setThemeMode(ThemeMode.light),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('🌙 Dark')),
                            selected: shopProvider.themeMode == ThemeMode.dark,
                            onSelected: (_) => shopProvider.setThemeMode(ThemeMode.dark),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('⚙️ Auto')),
                            selected: shopProvider.themeMode == ThemeMode.system,
                            onSelected: (_) => shopProvider.setThemeMode(ThemeMode.system),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // App Update Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.system_update_alt, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('ऐप अपडेट / App Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'v${UpdateService.currentVersion}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'नया अपडेट आने पर ऐप आपको खुद सूचित कर देगा। आप यहाँ से भी जांच सकते हैं।',
                      style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Check for Updates (अपडेट जांचें)'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                      ),
                      onPressed: () {
                        SoundService.instance.playButtonClick();
                        UpdateService.showUpdateDialogIfNeeded(context, showIfNoUpdate: true);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                SoundService.instance.playButtonClick();
                _saveSettings();
              },
              child: const Text('Save All Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
