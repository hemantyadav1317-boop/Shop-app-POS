import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/update_service.dart';
import '../../providers/shop_provider.dart';

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

  Future<void> _saveSettings() async {
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
    );

    await context.read<ShopProvider>().updateShop(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primary,
          content: Text('सेटिंग्स सेव हो गईं! (Settings Saved)'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = context.watch<ShopProvider>();

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

            // UPI QR Code Settings
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
                        Text('UPI पेमेंट सेटिंग्स / Dynamic QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'बिलिंग के समय ग्राहक को सीधा स्कैन करने के लिए अपनी UPI ID दर्ज करें।',
                      style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _upiIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'दुकानदार की UPI ID (जैसे: 9876543210@paytm, shop@okhdfcbank)',
                        prefixIcon: Icon(Icons.payment),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _upiNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Payee Name (दुकान या आपका नाम)',
                        prefixIcon: Icon(Icons.person_pin_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Thermal Printer & Negative Stock
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('प्रिंटर और स्टॉक सेटिंग्स', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('थर्मल पेपर साइज / Paper Size:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: '58mm', label: Text('58 mm')),
                            ButtonSegment(value: '80mm', label: Text('80 mm')),
                          ],
                          selected: {_paperSize},
                          onSelectionChanged: (val) {
                            setState(() => _paperSize = val.first);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _footerCtrl, decoration: const InputDecoration(labelText: 'रसीद पर नीचे का संदेश (Receipt Footer)')),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      title: const Text('नेगेटिव स्टॉक की अनुमति (Negative Stock)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('स्टॉक 0 होने पर भी बिल बनाने की अनुमति दें', style: TextStyle(fontSize: 11)),
                      value: _allowNegativeStock,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() => _allowNegativeStock = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
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
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saveSettings,
              child: const Text('Save All Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
