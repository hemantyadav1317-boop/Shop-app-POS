import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/bluetooth_printer_service.dart';
import '../../core/services/printer_settings_service.dart';
import '../../data/models/cart_item.dart';
import '../../providers/shop_provider.dart';
import '../pos/widgets/bill_receipt_card.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  // Service
  final _ps = PrinterSettingsService.instance;

  // Bluetooth state
  String? _btPrinterName;
  String? _btPrinterMac;
  bool _btIsConnected = false;
  bool _isConnectingBt = false;

  // Local printer config state
  late String _paperSize;
  late double _fontScale;
  late bool _showShopName;
  late bool _showAddress;
  late bool _showPhone;
  late bool _showEmail;
  late bool _showGstin;
  late bool _showInvoiceNo;
  late bool _showCustomer;
  late bool _showQuote;
  late bool _showFooter;
  late bool _showQr;

  // Editable Shop details for bill
  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _gstinCtrl;
  late TextEditingController _footerCtrl;

  @override
  void initState() {
    super.initState();
    final shop = context.read<ShopProvider>().shop;

    _paperSize = _ps.paperSize;
    _fontScale = _ps.fontScale;
    _showShopName = _ps.showShopName;
    _showAddress = _ps.showAddress;
    _showPhone = _ps.showPhone;
    _showEmail = _ps.showEmail;
    _showGstin = _ps.showGstin;
    _showInvoiceNo = _ps.showInvoiceNo;
    _showCustomer = _ps.showCustomer;
    _showQuote = _ps.showQuote;
    _showFooter = _ps.showFooter;
    _showQr = _ps.showQr;

    _nameCtrl = TextEditingController(text: shop.name);
    _addressCtrl = TextEditingController(text: shop.address ?? '');
    _phoneCtrl = TextEditingController(text: shop.phone ?? '');
    _emailCtrl = TextEditingController(text: '');
    _gstinCtrl = TextEditingController(text: shop.gstin ?? '');
    _footerCtrl = TextEditingController(text: shop.receiptFooter ?? 'धन्यवाद! फिर पधारें 🙏');

    _loadBtPrinterInfo();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _gstinCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
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
    try {
      await BluetoothPrinterService.isPermissionGranted();
    } catch (_) {}

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
                child: Text('कोई ब्लूटूथ प्रिंटर नहीं मिला', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: const Text(
            'कृपया सुनिश्चित करें कि आपका 58mm/80mm थर्मल प्रिंटर चालू है और मोबाइल की ब्लूटूथ सेटिंग्स में पेयर (Paired) है।\n(डिफ़ॉल्ट पिन: 0000 या 1234)',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
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
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'पेयर्ड ब्लूटूथ प्रिंटर चुनें / Select Printer',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...devices.map((d) {
              final isCurrent = _btPrinterMac == d.macAdress;
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                tileColor: isCurrent ? AppColors.primarySurface : null,
                leading: Icon(
                  Icons.print_rounded,
                  color: isCurrent ? AppColors.primary : Colors.grey.shade700,
                ),
                title: Text(
                  d.name.isNotEmpty ? d.name : 'Unknown Device',
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    color: isCurrent ? AppColors.primary : null,
                  ),
                ),
                subtitle: Text(d.macAdress, style: const TextStyle(fontSize: 11)),
                trailing: isCurrent
                    ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                    : const Icon(Icons.chevron_right, size: 18),
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => _isConnectingBt = true);
                  final ok = await BluetoothPrinterService.connectPrinter(d.macAdress);
                  if (ok) {
                    await BluetoothPrinterService.saveSelectedPrinter(d.macAdress, d.name);
                    SoundService.instance.playSuccess();
                  } else {
                    SoundService.instance.playError();
                  }
                  await _loadBtPrinterInfo();
                  if (mounted) {
                    setState(() => _isConnectingBt = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: ok ? AppColors.primary : AppColors.error,
                        content: Text(ok ? 'प्रिंटर "${d.name}" सफलतापूर्वक कनेक्ट हुआ!' : 'कनेक्ट नहीं हो सका। कृपया प्रिंटर ऑन रखें।'),
                      ),
                    );
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTestPrint() async {
    SoundService.instance.playButtonClick();
    final shop = context.read<ShopProvider>().shop.copyWith(
          name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
          address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
          phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
          printPaperSize: _paperSize,
        );

    final ok = await BluetoothPrinterService.printTestReceipt(shop);
    if (!mounted) return;

    if (ok) {
      SoundService.instance.playSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primary,
          content: Text('🎉 टेस्ट प्रिंट सफलतापूर्वक प्रिंट हो गया!'),
        ),
      );
    } else {
      SoundService.instance.playError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('⚠️ टेस्ट प्रिंट नहीं निकल सका। प्रिंटर कनेक्शन चेक करें।'),
        ),
      );
    }
  }

  Future<void> _saveAllSettings() async {
    SoundService.instance.playSuccess();

    // 1. Save Printer Display & Font Settings
    await _ps.saveAll(
      paperSize: _paperSize,
      fontScale: _fontScale,
      showShopName: _showShopName,
      showAddress: _showAddress,
      showPhone: _showPhone,
      showEmail: _showEmail,
      showGstin: _showGstin,
      showInvoiceNo: _showInvoiceNo,
      showCustomer: _showCustomer,
      showQuote: _showQuote,
      showFooter: _showFooter,
      showQr: _showQr,
    );

    // 2. Save Updated Shop Details if changed
    if (!mounted) return;
    final shopProv = context.read<ShopProvider>();
    final currentShop = shopProv.shop;
    final updatedShop = currentShop.copyWith(
      name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : currentShop.name,
      address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
      phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
      gstin: _gstinCtrl.text.trim().isNotEmpty ? _gstinCtrl.text.trim() : null,
      receiptFooter: _footerCtrl.text.trim().isNotEmpty ? _footerCtrl.text.trim() : currentShop.receiptFooter,
      printPaperSize: _paperSize,
    );
    await shopProv.updateShop(updatedShop);

    if (!mounted) return;

    // 3. Show Rich "All Details Saved Successfully! 🎉" Modal
    showDialog(
      context: context,
      barrierDismissible: true,
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
              'प्रिंटर सेटिंग्स, फ़ॉन्ट साइज़ और बिल लेआउट सफलतापूर्वक सुरक्षित कर लिए गए हैं।',
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sample items for live receipt preview
    final sampleItems = [
      CartItem(name: 'सरसों तेल 1L', unit: 'pc', price: 140.0, qty: 1.0),
      CartItem(name: 'मैगी नूडल्स 70g', unit: 'pc', price: 14.0, qty: 2.0),
      CartItem(name: 'टाटा नमक 1kg', unit: 'pc', price: 28.0, qty: 1.0),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('प्रिंटर सेटिंग्स / Printer Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('सेव करें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00875A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _saveAllSettings,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Bluetooth Connection Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bluetooth, color: AppColors.primary, size: 22),
                            SizedBox(width: 8),
                            Text('थर्मल प्रिंटर कनेक्शन', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _btIsConnected
                                ? Colors.green.shade50
                                : (_btPrinterMac != null ? Colors.amber.shade50 : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _btIsConnected
                                  ? Colors.green
                                  : (_btPrinterMac != null ? Colors.amber : Colors.grey),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 4,
                                backgroundColor: _btIsConnected
                                    ? Colors.green
                                    : (_btPrinterMac != null ? Colors.amber : Colors.grey),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _btIsConnected ? 'Connected' : (_btPrinterMac != null ? 'Paired' : 'Not Connected'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _btIsConnected
                                      ? Colors.green.shade800
                                      : (_btPrinterMac != null ? Colors.amber.shade900 : Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_btPrinterMac != null) ...[
                      Text(
                        'प्रिंटर: ${_btPrinterName ?? "Thermal Printer"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'MAC Address: $_btPrinterMac',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isConnectingBt ? null : _selectBluetoothPrinter,
                            icon: _isConnectingBt
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.bluetooth_searching, size: 16),
                            label: Text(
                              _btPrinterMac == null ? 'प्रिंटर कनेक्ट करें' : 'प्रिंटर बदलें / स्कैन करें',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        if (_btPrinterMac != null) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _handleTestPrint,
                            icon: const Icon(Icons.print_outlined, size: 16),
                            label: const Text('टेस्ट प्रिंट', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 2. Paper Roll Size & Thermal Font Scaling (Solves Tiny Print Customer Complaint)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.format_size_rounded, color: AppColors.primary, size: 22),
                        SizedBox(width: 8),
                        Text('पेपर साइज़ और फ़ॉन्ट स्केल', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'थर्मल प्रिंटर पर टेक्स्ट को बड़ा और साफ़ प्रिंट करने के लिए फ़ॉन्ट साइज़ चुनें:',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),

                    // Paper Size Selector
                    const Text('प्रिंटर रोल साइज़ (Paper Roll):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _paperSize = '58mm'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _paperSize == '58mm' ? AppColors.primarySurface : (isDark ? Colors.white10 : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _paperSize == '58mm' ? AppColors.primary : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '58mm (2 Inch)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _paperSize == '58mm' ? AppColors.primary : null,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'मानक POS रोल',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _paperSize == '58mm' ? AppColors.primary : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _paperSize = '80mm'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _paperSize == '80mm' ? AppColors.primarySurface : (isDark ? Colors.white10 : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _paperSize == '80mm' ? AppColors.primary : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '80mm (3 Inch)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _paperSize == '80mm' ? AppColors.primary : null,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'बड़ा चौड़ा रोल',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _paperSize == '80mm' ? AppColors.primary : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Thermal Font Size Scale
                    const Text('थर्मल टेक्स्ट साइज़ (Font Size):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFontOption(
                            label: 'Normal',
                            sub: '1.0x',
                            scaleVal: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildFontOption(
                            label: 'Large',
                            sub: '1.25x ⭐',
                            scaleVal: 1.25,
                            isRecommended: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildFontOption(
                            label: 'X-Large',
                            sub: '1.45x',
                            scaleVal: 1.45,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00875A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00875A).withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFF00875A), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '💡 टिप: "Large (1.25x)" चुनने से बिल के सभी अक्षर और टोटल बड़े, साफ़ और तुरंत पढ़ने में आते हैं।',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF00875A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 3. Bill Layout & Header Controls (Toggles)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
                        SizedBox(width: 8),
                        Text('बिल में क्या प्रिंट करें? (Print Controls)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'अपनी आवश्यकतानुसार बिल के किसी भी हिस्से को चालू या बंद करें:',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),

                    _buildToggleTile('दुकान का नाम (Shop Name)', _showShopName, (v) => setState(() => _showShopName = v)),
                    _buildToggleTile('दुकान का पता (Address)', _showAddress, (v) => setState(() => _showAddress = v)),
                    _buildToggleTile('मोबाइल / फ़ोन नंबर (Phone)', _showPhone, (v) => setState(() => _showPhone = v)),
                    _buildToggleTile('ईमेल आईडी (Email ID)', _showEmail, (v) => setState(() => _showEmail = v)),
                    _buildToggleTile('GSTIN नंबर', _showGstin, (v) => setState(() => _showGstin = v)),
                    _buildToggleTile('बिल नंबर व दिनांक (Invoice & Date)', _showInvoiceNo, (v) => setState(() => _showInvoiceNo = v)),
                    _buildToggleTile('ग्राहक का विवरण (Customer Name/Phone)', _showCustomer, (v) => setState(() => _showCustomer = v)),
                    _buildToggleTile('शुभ विचार (AI Daily Thought / Quote)', _showQuote, (v) => setState(() => _showQuote = v)),
                    _buildToggleTile('फ़ुटर संदेश (Visit Again Message)', _showFooter, (v) => setState(() => _showFooter = v)),
                    _buildToggleTile('UPI पेमेंट QR कोड (Scan & Pay)', _showQr, (v) => setState(() => _showQr = v)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 4. Shop Information Editing
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storefront_outlined, color: AppColors.primary, size: 22),
                        SizedBox(width: 8),
                        Text('बिल पर छपने वाली जानकारी (Bill Details)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'दुकान का नाम *',
                        prefixIcon: Icon(Icons.store),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'दुकान का पता',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'मोबाइल नंबर',
                        prefixIcon: Icon(Icons.phone_outlined),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _gstinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'GSTIN (वैकल्पिक)',
                        prefixIcon: Icon(Icons.receipt_long_outlined),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _footerCtrl,
                      decoration: const InputDecoration(
                        labelText: 'बिल का फ़ुटर संदेश',
                        prefixIcon: Icon(Icons.message_outlined),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 5. Live Visual Receipt Preview
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.visibility_outlined, color: AppColors.primary, size: 22),
                        SizedBox(width: 8),
                        Text('लाइव बिल प्रीव्यू / Live Receipt Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'आपकी चुनी हुई सेटिंग्स के अनुसार थर्मल प्रिंटर पर बिल ऐसा दिखेगा:',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: BillReceiptCard(
                          shopName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'मेरी दुकान POS',
                          shopAddress: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
                          shopPhone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
                          shopEmail: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
                          gstin: _gstinCtrl.text.trim().isNotEmpty ? _gstinCtrl.text.trim() : null,
                          billNo: 'INV-101',
                          dateString: '29 Oct 2026, 09:30 PM',
                          customerName: 'राजेश कुमार',
                          customerPhone: '9876543210',
                          items: sampleItems,
                          subtotal: 182.0,
                          discount: 0.0,
                          total: 182.0,
                          paid: 182.0,
                          paymentMode: 'Cash',
                          footerMessage: _footerCtrl.text.trim().isNotEmpty ? _footerCtrl.text.trim() : 'धन्यवाद! फिर पधारें 🙏',
                          quoteLine1: 'कर्म ही पूजा है',
                          quoteLine2: 'शुभ दिन हो!',
                          fontScale: _fontScale,
                          showShopName: _showShopName,
                          showAddress: _showAddress,
                          showPhone: _showPhone,
                          showEmail: _showEmail,
                          showGstin: _showGstin,
                          showInvoiceNo: _showInvoiceNo,
                          showCustomer: _showCustomer,
                          showQuote: _showQuote,
                          showFooter: _showFooter,
                          showQr: _showQr,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Big Save Button
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('सभी सेटिंग्स सेव करें (Save All Details)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00875A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 3,
              ),
              onPressed: _saveAllSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontOption({
    required String label,
    required String sub,
    required double scaleVal,
    bool isRecommended = false,
  }) {
    final isSelected = (_fontScale - scaleVal).abs() < 0.01;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _fontScale = scaleVal),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : (isDark ? Colors.white10 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isRecommended ? AppColors.primary.withValues(alpha: 0.4) : Colors.transparent),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: isSelected ? AppColors.primary : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isRecommended ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : (isRecommended ? Colors.green.shade800 : Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      value: value,
      activeTrackColor: AppColors.primary,
      onChanged: (val) {
        SoundService.instance.playButtonClick();
        onChanged(val);
      },
    );
  }
}

