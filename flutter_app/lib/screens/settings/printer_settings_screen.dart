import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/bluetooth_printer_service.dart';
import '../../core/services/bluetooth_device_classifier.dart';
import '../../core/services/printer_settings_service.dart';
import '../../data/models/cart_item.dart';
import '../../providers/shop_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
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

  Future<void> _selectBluetoothPrinter(bool isHindi) async {
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
          title: Row(
            children: [
              const Icon(Icons.bluetooth_searching, color: Color(0xFFFF5722)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isHindi ? 'कोई ब्लूटूथ प्रिंटर नहीं मिला' : 'No Bluetooth Printer Found',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Text(
            isHindi
                ? 'कृपया सुनिश्चित करें कि आपका 58mm/80mm थर्मल प्रिंटर चालू है और मोबाइल ब्लूटूथ में पेयर है।\n(पिन: 0000 या 1234)'
                : 'Please make sure your 58mm/80mm thermal printer is ON and paired in phone Bluetooth.\n(Default PIN: 0000 or 1234)',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isHindi ? 'समझ गया' : 'Got It'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.82,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isHindi ? 'पेयर्ड ब्लूटूथ प्रिंटर चुनें' : 'Select Paired Printer',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final d = devices[index];
                  final isCurrent = _btPrinterMac == d.macAdress;
                  final info = BluetoothDeviceClassifier.classify(d.name, d.macAdress);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFFFFEDE6)
                          : (info.isRecommendedForPrinter ? const Color(0xFFF0FDF4) : Colors.transparent),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xFFFF5722)
                            : (info.isRecommendedForPrinter ? const Color(0xFF86EFAC) : Colors.grey.shade200),
                        width: isCurrent ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: isCurrent ? const Color(0xFFFF5722) : info.backgroundColor,
                        child: Icon(
                          info.icon,
                          size: 18,
                          color: isCurrent ? Colors.white : info.primaryColor,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.name.isNotEmpty ? d.name : (isHindi ? 'अज्ञात डिवाइस' : 'Unknown Device'),
                              style: TextStyle(
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                color: isCurrent ? const Color(0xFFFF5722) : null,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: info.backgroundColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: info.primaryColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              info.badgeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: info.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(d.macAdress, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: isCurrent
                          ? const Icon(Icons.check_circle, color: Color(0xFFFF5722), size: 20)
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
                              backgroundColor: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              content: Text(
                                ok
                                    ? (isHindi ? 'प्रिंटर "${d.name}" सफलतापूर्वक कनेक्ट हुआ!' : 'Printer "${d.name}" connected successfully!')
                                    : (isHindi ? 'कनेक्ट नहीं हो सका। कृपया प्रिंटर ऑन रखें।' : 'Could not connect. Please check printer power.'),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTestPrint(bool isHindi) async {
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
        SnackBar(
          backgroundColor: const Color(0xFF16A34A),
          content: Text(isHindi ? '🎉 टेस्ट प्रिंट सफलतापूर्वक प्रिंट हो गया!' : '🎉 Test receipt printed successfully!'),
        ),
      );
    } else {
      SoundService.instance.playError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text(isHindi ? '⚠️ टेस्ट प्रिंट नहीं निकल सका। प्रिंटर कनेक्शन चेक करें।' : '⚠️ Test print failed. Check printer connection.'),
        ),
      );
    }
  }

  Future<void> _saveAllSettings(bool isHindi) async {
    final isStaff = context.read<AuthProvider>().isStaffSession;
    if (isStaff) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text(isHindi ? 'सुरक्षा नियम: केवल दुकान मालिक प्रिंटर सेटिंग्स बदल सकते हैं।' : 'Security Rule: Only store owner can modify printer settings.'),
        ),
      );
      return;
    }
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

    // 3. Show Rich "Saved Successfully" Modal
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
                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              isHindi ? 'सेटिंग्स सफलतापूर्वक सेव हो गईं! 🎉' : 'All Details Saved Successfully! 🎉',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Color(0xFF16A34A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isHindi
                  ? 'प्रिंटर सेटिंग्स, फ़ॉन्ट साइज़ और बिल लेआउट सुरक्षित कर लिए गए हैं।'
                  : 'Printer preferences, font scale and receipt details have been saved.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.35),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(isHindi ? 'ठीक है' : 'Done', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
    final isStaff = context.watch<AuthProvider>().isStaffSession;
    final localeCode = context.watch<LocaleProvider>().localeCode;
    final isHindi = localeCode == 'hi';

    final sampleItems = [
      CartItem(name: isHindi ? 'सरसों तेल 1L' : 'Mustard Oil 1L', unit: 'pc', price: 140.0, qty: 1.0),
      CartItem(name: isHindi ? 'मैगी नूडल्स 70g' : 'Maggi Noodles 70g', unit: 'pc', price: 14.0, qty: 2.0),
      CartItem(name: isHindi ? 'टाटा नमक 1kg' : 'Tata Salt 1kg', unit: 'pc', price: 28.0, qty: 1.0),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF5722), Color(0xFFF97316)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            SoundService.instance.playButtonClick();
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            const Icon(Icons.print_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              isHindi ? 'प्रिंटर सेटअप' : 'Printer Setup',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
            tooltip: isHindi ? 'प्रिंटर विकल्प' : 'Printer Options',
            onPressed: () => _handleTestPrint(isHindi),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 850;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 850 : double.infinity),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isStaff)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_rounded, color: Color(0xFFD97706), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isHindi
                                    ? 'सुरक्षा नियम: केवल दुकान मालिक रसीद फॉर्मेट और दुकान की जानकारी बदल सकते हैं।'
                                    : 'Security Rule: Only store owner can edit receipt format and store details.',
                                style: const TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 1. Printer Connection Card (Matching Image 2)
                    _buildConnectionCard(isDark, isHindi),

                    const SizedBox(height: 14),

                    // 2. Paper Roll Size & Font Size Card (Matching Image 2)
                    _buildPaperAndFontCard(isDark, isHindi, isStaff),

                    const SizedBox(height: 14),

                    // 3. Print Controls Card (Matching Image 2)
                    _buildPrintControlsCard(isDark, isHindi, isStaff),

                    const SizedBox(height: 14),

                    // 4. Shop Bill Details Editing Card (Matching Image 2)
                    _buildShopDetailsCard(isDark, isHindi, isStaff),

                    const SizedBox(height: 14),

                    // 5. Live Visual Receipt Preview
                    _buildLiveReceiptPreview(isDark, isHindi, sampleItems),

                    const SizedBox(height: 20),

                    // Bottom Full-Width Save Button (Matching Image 2)
                    if (!isStaff)
                      SafeArea(
                        top: false,
                        bottom: true,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_rounded, size: 20),
                          label: Text(
                            isHindi ? 'सभी सेटिंग्स सेव करें' : 'Save All Details',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5722),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            elevation: 3,
                          ),
                          onPressed: () => _saveAllSettings(isHindi),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // 1. PRINTER CONNECTION CARD (IMAGE 2)
  // ==========================================
  Widget _buildConnectionCard(bool isDark, bool isHindi) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Peach squircle + Title + Subtitle + Status Pill
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.bluetooth_rounded,
                  color: Color(0xFFF97316),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? 'प्रिंटर कनेक्शन' : 'Printer Connection',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isHindi ? 'अपना ब्लूटूथ प्रिंटर कनेक्ट करें' : 'Connect your Bluetooth printer',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Pill (Matching Image 2: Gray / Green pill)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _btIsConnected ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: _btIsConnected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _btIsConnected
                          ? (isHindi ? 'कनेक्टेड' : 'Connected')
                          : (isHindi ? 'कनेक्ट नहीं है' : 'Not Connected'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _btIsConnected ? const Color(0xFF15803D) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (_btPrinterMac != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.print_rounded, size: 16, color: Color(0xFFFF5722)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_btPrinterName ?? "Thermal Printer"} ($_btPrinterMac)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => _handleTestPrint(isHindi),
                    child: Text(
                      isHindi ? 'टेस्ट प्रिंट' : 'Test Print',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFF5722)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Connect Printer Full-width Button (Matching Image 2)
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isConnectingBt ? null : () => _selectBluetoothPrinter(isHindi),
              icon: _isConnectingBt
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.bluetooth_searching_rounded, size: 20),
              label: Text(
                _isConnectingBt
                    ? (isHindi ? 'कनेक्ट हो रहा है...' : 'Connecting...')
                    : (isHindi ? 'प्रिंटर कनेक्ट करें' : 'Connect Printer'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. PAPER ROLL SIZE & FONT SIZE (IMAGE 2)
  // ==========================================
  Widget _buildPaperAndFontCard(bool isDark, bool isHindi, bool isStaff) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFFF97316),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isHindi ? 'पेपर रोल व फ़ॉन्ट साइज़' : 'Paper Roll Size & Font Size',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Sub-heading 1: Paper Roll Size
          Text(
            isHindi ? 'प्रिंटर पेपर रोल साइज़:' : 'Printer Paper Roll Size:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              // Paper roll illustration
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_rounded, color: Color(0xFFF97316), size: 26),
              ),

              // Option 1: 58mm
              Expanded(
                child: InkWell(
                  onTap: isStaff ? null : () => setState(() => _paperSize = '58mm'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: _paperSize == '58mm' ? const Color(0xFFFFEDE6) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _paperSize == '58mm' ? const Color(0xFFFF5722) : const Color(0xFFE2E8F0),
                        width: _paperSize == '58mm' ? 1.5 : 1,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '58mm (2 Inch)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: _paperSize == '58mm' ? const Color(0xFFFF5722) : null,
                              ),
                            ),
                            if (_paperSize == '58mm') ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.check_circle_rounded, color: Color(0xFFFF5722), size: 14),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isHindi ? 'सबसे छोटा रोल' : 'Smallest roll',
                          style: TextStyle(
                            fontSize: 10,
                            color: _paperSize == '58mm' ? const Color(0xFFFF5722) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Option 2: 80mm
              Expanded(
                child: InkWell(
                  onTap: isStaff ? null : () => setState(() => _paperSize = '80mm'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: _paperSize == '80mm' ? const Color(0xFFFFEDE6) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _paperSize == '80mm' ? const Color(0xFFFF5722) : const Color(0xFFE2E8F0),
                        width: _paperSize == '80mm' ? 1.5 : 1,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '80mm (3 Inch)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: _paperSize == '80mm' ? const Color(0xFFFF5722) : null,
                              ),
                            ),
                            if (_paperSize == '80mm') ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.check_circle_rounded, color: Color(0xFFFF5722), size: 14),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isHindi ? 'बड़ा रोल' : 'Large roll',
                          style: TextStyle(
                            fontSize: 10,
                            color: _paperSize == '80mm' ? const Color(0xFFFF5722) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Sub-heading 2: Font Size
          Text(
            isHindi ? 'फ़ॉन्ट साइज़:' : 'Font Size:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              // "Aa" icon container
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Aa',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFFF97316)),
                ),
              ),

              // Normal (1.0x)
              Expanded(
                child: _buildFontSizePill(
                  label: 'Normal',
                  scale: '1.0×',
                  val: 1.0,
                  isDark: isDark,
                  isStaff: isStaff,
                ),
              ),
              const SizedBox(width: 6),

              // Large (1.25x)
              Expanded(
                child: _buildFontSizePill(
                  label: 'Large',
                  scale: '1.25×',
                  val: 1.25,
                  isDark: isDark,
                  isStaff: isStaff,
                ),
              ),
              const SizedBox(width: 6),

              // X-Large (1.45x)
              Expanded(
                child: _buildFontSizePill(
                  label: 'X-Large',
                  scale: '1.45×',
                  val: 1.45,
                  isDark: isDark,
                  isStaff: isStaff,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Blue Info Alert Box (Matching Image 2)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isHindi
                        ? 'टिप: "Large (1.25×)" चुनने से बिल के सभी अक्षर और टोटल बड़े, साफ़ और तुरंत पढ़ने में आते हैं।'
                        : 'Tip: Selecting "Large (1.25×)" ensures invoice text and totals are bold, crisp and legible.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF1E40AF),
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizePill({
    required String label,
    required String scale,
    required double val,
    required bool isDark,
    required bool isStaff,
  }) {
    final isSelected = (_fontScale - val).abs() < 0.01;

    return InkWell(
      onTap: isStaff ? null : () => setState(() => _fontScale = val),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFEDE6) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF5722) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                      color: isSelected ? const Color(0xFFFF5722) : null,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 2),
                    const Icon(Icons.check_circle_rounded, color: Color(0xFFFF5722), size: 12),
                  ],
                ],
              ),
              Text(
                scale,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? const Color(0xFFFF5722) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 3. PRINT CONTROLS (IMAGE 2)
  // ==========================================
  Widget _buildPrintControlsCard(bool isDark, bool isHindi, bool isStaff) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFFF97316),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? 'प्रिंट कंट्रोल्स' : 'Print Controls',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isHindi
                          ? 'अपनी आवश्यकतानुसार प्रिंट सेटिंग्स को चालू या बंद करें'
                          : 'Configure print preferences according to your needs',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Toggles with Orange Switch (Matching Image 2)
          _buildPrintToggle(
            icon: Icons.print_rounded,
            title: isHindi ? 'प्रिंट हेडर' : 'Print Header',
            value: _showShopName,
            onChanged: (v) => setState(() => _showShopName = v),
            isStaff: isStaff,
          ),
          _buildPrintToggle(
            icon: Icons.chat_bubble_outline_rounded,
            title: isHindi ? 'दैनिक सुविचार' : 'Daily Thought / Quote',
            value: _showQuote,
            onChanged: (v) => setState(() => _showQuote = v),
            isStaff: isStaff,
          ),
          _buildPrintToggle(
            icon: Icons.history_rounded,
            title: isHindi ? 'फुटर संदेश' : 'Visit Again Message',
            value: _showFooter,
            onChanged: (v) => setState(() => _showFooter = v),
            isStaff: isStaff,
          ),
          _buildPrintToggle(
            icon: Icons.qr_code_2_rounded,
            title: isHindi ? 'UPI पेमेंट QR कोड' : 'UPI Payment QR Code',
            value: _showQr,
            onChanged: (v) => setState(() => _showQr = v),
            isStaff: isStaff,
          ),
          _buildPrintToggle(
            icon: Icons.shopping_bag_outlined,
            title: isHindi ? 'भुगतान होते ही ऑटो-प्रिंट' : 'Auto-Print on Payment',
            value: _ps.autoPrintOnPayment,
            onChanged: (v) {
              _ps.setAutoPrintOnPayment(v);
              setState(() {});
            },
            isStaff: isStaff,
          ),
        ],
      ),
    );
  }

  Widget _buildPrintToggle({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isStaff,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF475569)),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ],
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFFFF5722),
            activeTrackColor: const Color(0xFFFFCCBC),
            onChanged: isStaff
                ? null
                : (val) {
                    SoundService.instance.playButtonClick();
                    onChanged(val);
                  },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. SHOP BILL DETAILS (IMAGE 2)
  // ==========================================
  Widget _buildShopDetailsCard(bool isDark, bool isHindi, bool isStaff) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Color(0xFFF97316),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isHindi ? 'बिल पर छपने वाली जानकारी' : 'Bill Details',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Fields in 2-row grid layout matching Image 2
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  readOnly: isStaff,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: isHindi ? 'दुकान का नाम *' : 'Shop Name *',
                    prefixIcon: const Icon(Icons.store_rounded, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _addressCtrl,
                  readOnly: isStaff,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: isHindi ? 'दुकान का पता' : 'Shop Address',
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  readOnly: isStaff,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: isHindi ? 'मोबाइल नंबर' : 'Phone Number',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _gstinCtrl,
                  readOnly: isStaff,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: isHindi ? 'GSTIN (वैकल्पिक)' : 'GSTIN (Optional)',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          TextField(
            controller: _footerCtrl,
            readOnly: isStaff,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: isHindi ? 'बिल का फुटर संदेश' : 'Receipt Footer Message',
              prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. LIVE VISUAL RECEIPT PREVIEW
  // ==========================================
  Widget _buildLiveReceiptPreview(bool isDark, bool isHindi, List<CartItem> sampleItems) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined, color: Color(0xFFFF5722), size: 22),
              const SizedBox(width: 8),
              Text(
                isHindi ? 'लाइव बिल प्रीव्यू' : 'Live Receipt Preview',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
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
                shopName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : (isHindi ? 'मेरी दुकान POS' : 'My Store POS'),
                shopAddress: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
                shopPhone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
                shopEmail: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
                gstin: _gstinCtrl.text.trim().isNotEmpty ? _gstinCtrl.text.trim() : null,
                billNo: 'INV-101',
                dateString: '29 Oct 2026, 09:30 PM',
                customerName: isHindi ? 'राजेश कुमार' : 'Rajesh Kumar',
                customerPhone: '9876543210',
                items: sampleItems,
                subtotal: 182.0,
                discount: 0.0,
                total: 182.0,
                paid: 182.0,
                paymentMode: 'Cash',
                footerMessage: _footerCtrl.text.trim().isNotEmpty ? _footerCtrl.text.trim() : (isHindi ? 'धन्यवाद! फिर पधारें 🙏' : 'Thank You! Visit Again 🙏'),
                quoteLine1: isHindi ? 'कर्म ही पूजा है' : 'Work is Worship',
                quoteLine2: isHindi ? 'शुभ दिन हो!' : 'Have a Great Day!',
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
    );
  }
}
