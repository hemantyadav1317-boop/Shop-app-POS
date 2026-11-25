import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/printer_settings_service.dart';
import '../../core/services/sound_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';

class ReceiptSettingsScreen extends StatefulWidget {
  const ReceiptSettingsScreen({super.key});

  @override
  State<ReceiptSettingsScreen> createState() => _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends State<ReceiptSettingsScreen> {
  final _ps = PrinterSettingsService.instance;
  late String _paperSize;
  late double _fontScale;
  late bool _showShopName;
  late bool _showAddress;
  late bool _showPhone;
  late bool _showGstin;
  late bool _showInvoiceNo;
  late bool _showCustomer;
  late bool _showQuote;
  late bool _showFooter;
  late bool _showQr;
  late bool _autoPrint;
  late TextEditingController _footerCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _paperSize = _ps.paperSize;
    _fontScale = _ps.fontScale;
    _showShopName = _ps.showShopName;
    _showAddress = _ps.showAddress;
    _showPhone = _ps.showPhone;
    _showGstin = _ps.showGstin;
    _showInvoiceNo = _ps.showInvoiceNo;
    _showCustomer = _ps.showCustomer;
    _showQuote = _ps.showQuote;
    _showFooter = _ps.showFooter;
    _showQr = _ps.showQr;
    _autoPrint = _ps.autoPrintOnPayment;
    final shop = context.read<ShopProvider>().shop;
    _footerCtrl = TextEditingController(text: shop.receiptFooter ?? 'धन्यवाद! फिर पधारें 🙏');
  }

  @override
  void dispose() {
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: AppColors.error, content: Text('सुरक्षा नियम: केवल दुकान मालिक रसीद सेटिंग्स बदल सकते हैं।')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _ps.saveAll(
        paperSize: _paperSize,
        fontScale: _fontScale,
        showShopName: _showShopName,
        showAddress: _showAddress,
        showPhone: _showPhone,
        showEmail: false,
        showGstin: _showGstin,
        showInvoiceNo: _showInvoiceNo,
        showCustomer: _showCustomer,
        showQuote: _showQuote,
        showFooter: _showFooter,
        showQr: _showQr,
      );
      await _ps.setAutoPrintOnPayment(_autoPrint);

      final currentShop = context.read<ShopProvider>().shop;
      final updated = currentShop.copyWith(
        printPaperSize: _paperSize,
        receiptFooter: _footerCtrl.text.trim(),
      );
      await context.read<ShopProvider>().updateShop(updated);
      SoundService.instance.playSuccess();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF00875A),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('रसीद सेटिंग्स सुरक्षित कर ली गई हैं! ✓', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>().shop;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Receipt Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thermal Paper Size Segmented Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('प्रिंटर पेपर साइज (Paper Width)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    'अपने थर्मल प्रिंटर के रोल साइज के अनुसार चुनें',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _paperSize == '58mm' ? AppColors.primary : Colors.transparent,
                            foregroundColor: _paperSize == '58mm' ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            side: BorderSide(color: _paperSize == '58mm' ? AppColors.primary : Colors.grey.shade400),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => setState(() => _paperSize = '58mm'),
                          child: const Text('58mm (2-इंच रसीद)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _paperSize == '80mm' ? AppColors.primary : Colors.transparent,
                            foregroundColor: _paperSize == '80mm' ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            side: BorderSide(color: _paperSize == '80mm' ? AppColors.primary : Colors.grey.shade400),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => setState(() => _paperSize = '80mm'),
                          child: const Text('80mm (3-इंच रसीद)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Auto-Print Switch Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00875A).withValues(alpha: 0.3)),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _autoPrint,
                activeColor: const Color(0xFF00875A),
                title: const Row(
                  children: [
                    Icon(Icons.flash_on_rounded, color: Color(0xFF00875A), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('इंस्टैंट ऑटो-प्रिंट (Auto-Print)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
                subtitle: const Text(
                  'पेमेंट होते ही बिना किसी बटन दबाए प्रिंटर से रसीद अपने आप बाहर निकलेगी',
                  style: TextStyle(fontSize: 11.5, color: AppColors.lightTextSecondary),
                ),
                onChanged: (val) => setState(() => _autoPrint = val),
              ),
            ),
            const SizedBox(height: 16),

            // Font Scaling
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('रसीद फॉन्ट साइज (Font Size)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        _fontScale <= 1.0 ? 'Normal (1.0x)' : (_fontScale <= 1.25 ? 'Large (1.25x)' : 'Extra Large (1.45x)'),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _fontScale,
                    min: 0.85,
                    max: 1.5,
                    divisions: 3,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _fontScale = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Receipt Header / Content Elements
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('रसीद पर क्या-क्या दिखेगा (Content Toggle)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('दुकान का नाम (Shop Name)'),
                    value: _showShopName,
                    onChanged: (v) => setState(() => _showShopName = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('दुकान का पता (Address)'),
                    value: _showAddress,
                    onChanged: (v) => setState(() => _showAddress = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('फोन नंबर (Phone Number)'),
                    value: _showPhone,
                    onChanged: (v) => setState(() => _showPhone = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('GSTIN नंबर (Tax ID)'),
                    value: _showGstin,
                    onChanged: (v) => setState(() => _showGstin = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('बिल क्रमांक व तारीख (Invoice No & Date)'),
                    value: _showInvoiceNo,
                    onChanged: (v) => setState(() => _showInvoiceNo = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('ग्राहक की जानकारी (Customer Details)'),
                    value: _showCustomer,
                    onChanged: (v) => setState(() => _showCustomer = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('UPI पेमेंट व रिव्यू QR कोड (QR Code)'),
                    value: _showQr,
                    onChanged: (v) => setState(() => _showQr = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Footer Message
            TextField(
              controller: _footerCtrl,
              decoration: InputDecoration(
                labelText: 'रसीद पर नीचे का संदेश (Receipt Footer)',
                hintText: 'उदा. धन्यवाद! फिर पधारें 🙏',
                prefixIcon: const Icon(Icons.format_quote_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),

            // Live Thermal Receipt Preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                    child: const Text('LIVE THERMAL PREVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                  ),
                  const SizedBox(height: 12),
                  if (_showShopName)
                    Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                  if (_showAddress && (shop.address?.isNotEmpty ?? false))
                    Text(shop.address!, style: const TextStyle(fontSize: 11, color: Colors.black87), textAlign: TextAlign.center),
                  if (_showPhone && (shop.phone?.isNotEmpty ?? false))
                    Text('Ph: ${shop.phone}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                  if (_showGstin && (shop.gstin?.isNotEmpty ?? false))
                    Text('GSTIN: ${shop.gstin}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                  const Divider(color: Colors.black54, thickness: 1),
                  if (_showInvoiceNo)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Bill #101', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                        Text('17/11/2026', style: TextStyle(fontSize: 11, color: Colors.black)),
                      ],
                    ),
                  const Divider(color: Colors.black54, thickness: 0.5),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Sugar 1kg x 1', style: TextStyle(fontSize: 12, color: Colors.black)),
                      Text('₹45.00', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tata Tea 250g x 1', style: TextStyle(fontSize: 12, color: Colors.black)),
                      Text('₹80.00', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                  const Divider(color: Colors.black54, thickness: 1),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TOTAL AMOUNT:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                      Text('₹125.00', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_showQr) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(4)),
                      child: const Column(
                        children: [
                          Icon(Icons.qr_code_2, size: 48, color: Colors.black),
                          Text('Scan & Pay / Review', style: TextStyle(fontSize: 9, color: Colors.black54)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(_footerCtrl.text, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black87)),
                ],
              ),
            ),
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
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_rounded, size: 20),
              label: const Text('Save Receipt Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: _isSaving ? null : _saveSettings,
            ),
          ),
        ),
      ),
    );
  }
}
