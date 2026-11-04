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
import 'weighing_scale_settings_screen.dart';
import 'ai_vision_settings_screen.dart';
import '../../providers/weighing_scale_provider.dart';
import '../../providers/ai_vision_provider.dart';

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

  void _showStaffPairingQrDialog(BuildContext context, Shop shop) {
    final qrData = 'shoppos://pair?phone=${Uri.encodeComponent(shop.phone ?? '')}&pin=${shop.displayShareCode}&shopId=${shop.id}&name=${Uri.encodeComponent(shop.name)}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'स्टाफ पेयरिंग QR कोड',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'Staff Instant Pairing QR',
                    style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.primaryDark,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySurface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    shop.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'शॉप मोबाइल: ${shop.phone ?? "सेट नहीं"}  •  पिन: ${shop.displayShareCode}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'स्टाफ अपने फोन के लॉगिन स्क्रीन पर "स्टाफ लॉगिन" में जाकर यह कोड स्कैन या दर्ज कर सकता है।',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ठीक है (Done)'),
          ),
        ],
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
        'subtitle': 'बारकोड गन स्कैन, 2026 MRP, पैकेट वैरिएंट',
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

    final currentMode = modes.firstWhere((m) => m['id'] == currentType, orElse: () => modes[0]);
    final activeColor = currentMode['color'] as Color;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activeColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          // 3D Soft Elevation Box Shadow
          BoxShadow(
            color: activeColor.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
                    color: activeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    currentMode['icon'] as String,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'दुकान का प्रकार (Store Business Mode)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentMode['subtitle'] as String,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dropdown Selector with 3D Pill Design
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: activeColor.withValues(alpha: 0.4), width: 1.2),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: currentType,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: activeColor, size: 24),
                  items: modes.map((m) {
                    final color = m['color'] as Color;
                    return DropdownMenuItem<String>(
                      value: m['id'] as String,
                      child: Row(
                        children: [
                          Text(m['icon'] as String, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              m['title'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: currentType == m['id'] ? color : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              m['tag'] as String,
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) async {
                    if (val != null && val != currentType) {
                      SoundService.instance.playButtonClick();
                      await shopProvider.setStoreType(val);
                      if (context.mounted) {
                        final sel = modes.firstWhere((m) => m['id'] == val);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: sel['color'] as Color,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            content: Row(
                              children: [
                                Text(sel['icon'] as String, style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Expanded(child: Text('मोड बदला गया: "${sel['title'] as String}" सक्रिय है!')),
                              ],
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ),
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
        padding: EdgeInsets.fromLTRB(16, 16, 16, 40 + MediaQuery.of(context).viewPadding.bottom),
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

            // ⚖️ Electronic Weighing Scale (इलेक्ट्रॉनिक कांटा) Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
              ),
              child: Consumer<WeighingScaleProvider>(
                builder: (context, scale, _) {
                  return ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.scale_rounded, color: Color(0xFF2563EB), size: 24),
                    ),
                    title: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '⚖️ इलेक्ट्रॉनिक कांटा',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (scale.isConnected ? const Color(0xFF10B981) : Colors.grey)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            scale.isConnected ? 'CONNECTED' : 'DISCONNECTED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: scale.isConnected ? const Color(0xFF10B981) : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      scale.isConnected
                          ? 'Weighing Scale • ${scale.scaleName ?? "Scale"} • Live: ${scale.liveWeight.toStringAsFixed(3)} ${scale.unit}'
                          : 'Weighing Scale • ब्लूटूथ कांटा कनेक्ट करें',
                      style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF2563EB)),
                    onTap: () {
                      SoundService.instance.playButtonClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WeighingScaleSettingsScreen()),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // 📷 AI Produce Vision & Camera Settings Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Consumer<AiVisionProvider>(
                builder: (context, ai, _) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: ai.isAiVisionActive
                            ? const Color(0xFF06B6D4).withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: ai.isAiVisionActive ? const Color(0xFF06B6D4) : Colors.grey,
                        size: 22,
                      ),
                    ),
                    title: Row(
                      children: [
                        const Text(
                          'AI विज़न व स्मार्ट कैमरा (Smart Produce Vision)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ai.isAiVisionActive
                                ? const Color(0xFF06B6D4).withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ai.isAiVisionActive ? 'ACTIVE' : 'OFF',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: ai.isAiVisionActive ? const Color(0xFF06B6D4) : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      ai.isAiVisionActive
                          ? 'कांटे के साथ ऑटो-डिटेक्शन चालू • ${ai.voiceFeedbackEnabled ? "वॉइस ऑन" : "वॉइस बंद"}'
                          : 'कांटे पर फल-सब्जी ऑटोमैटिक पहचान व बिलिंग सेट करें',
                      style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF06B6D4)),
                    onTap: () {
                      SoundService.instance.playButtonClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AiVisionSettingsScreen()),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'दुकान शेयरिंग / Family & Staff Access',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                '5-Layer सुरक्षित मल्टी-डिवाइस एक्सेस',
                                style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'अपने भाई, पार्टनर या स्टाफ को दुकान का एक्सेस देने के लिए यह विवरण दें:',
                      style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 12),

                    // Modern Details Container: Phone + PIN
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Row 1: Shop Phone
                          Row(
                            children: [
                              const Icon(Icons.phone_android_rounded, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              const Text(
                                'दुकान मोबाइल: ',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightTextSecondary),
                              ),
                              Expanded(
                                child: Text(
                                  currentShop.phone != null && currentShop.phone!.isNotEmpty
                                      ? currentShop.phone!
                                      : 'सेट नहीं (नीचे प्रोफ़ाइल में दर्ज करें)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: currentShop.phone != null ? AppColors.primaryDark : Colors.orange,
                                  ),
                                ),
                              ),
                              if (currentShop.phone != null)
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: currentShop.phone!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('मोबाइल नंबर कॉपी हुआ!')),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.copy, size: 16, color: AppColors.primary),
                                  ),
                                ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1),
                          ),

                          // Row 2: 6-Digit Staff PIN (Guaranteed No Text Wrapping)
                          Row(
                            children: [
                              const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              const Text(
                                'स्टाफ पिन: ',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightTextSecondary),
                              ),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      currentShop.displayShareCode.split('').join(' '),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                        letterSpacing: 3,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18, color: AppColors.primary),
                                tooltip: 'पिन कॉपी करें',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: currentShop.displayShareCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('स्टाफ पिन "${currentShop.displayShareCode}" कॉपी हो गया!')),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.share, size: 18, color: Colors.green),
                                tooltip: 'WhatsApp पर शेयर करें',
                                onPressed: () async {
                                  final phone = currentShop.phone ?? '';
                                  final pin = currentShop.displayShareCode;
                                  final text = '🏪 *${currentShop.name}*\n'
                                      '👥 *स्टाफ लॉगिन एक्सेस (Staff Access)*\n\n'
                                      '📞 दुकान मोबाइल: *$phone*\n'
                                      '🔑 6-अंकीय स्टाफ पिन: *$pin*\n\n'
                                      '📲 ShopPOS ऐप खोलें -> "Staff Login" पर क्लिक करें और मोबाइल व पिन दर्ज करके सीधे दुकान चलाएं!';
                                  final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  } else {
                                    Clipboard.setData(ClipboardData(text: text));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('शेयरिंग विवरण कॉपी हो गया!')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action Buttons Row: Show QR Code & Generate New PIN
                    Row(
                      children: [
                        // Button 1: Show QR Code
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.qr_code_2_rounded, size: 17),
                            label: const Text('📷 QR कोड दिखाएं', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 1,
                            ),
                            onPressed: () => _showStaffPairingQrDialog(context, currentShop),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Button 2: Generate New PIN (Clean single icon)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('नया पिन', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            final newCode = await shopProvider.generateNewShareCode();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.primary,
                                  content: Text('नया 6-अंकीय स्टाफ पिन सेट हुआ: $newCode'),
                                ),
                              );
                            }
                          },
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
