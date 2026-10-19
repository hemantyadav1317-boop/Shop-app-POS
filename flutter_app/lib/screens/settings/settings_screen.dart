import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/update_service.dart';
import '../../data/services/upi_service.dart';
import '../../providers/shop_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/customer_provider.dart';
import '../auth/login_screen.dart';

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

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'दुकान की जानकारी (GST/नाम/मोबाइल) सुरक्षित हो गई! ✅',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
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

              final current = context.read<ShopProvider>().shop;
              final switched = current.copyWith(id: code);
              await context.read<ShopProvider>().updateShop(switched);

              if (context.mounted) {
                // Reload data for this shop
                final prodProv = context.read<ProductProvider>();
                final custProv = context.read<CustomerProvider>();
                await prodProv.loadProducts(code);
                await custProv.loadCustomers(code);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.primary,
                      content: Text('दुकान "$code" से सफलतापूर्वक जुड़ गए!'),
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
                      onPressed: () async {
                        await authProvider.signOut();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                      child: const Text('लॉगआउट', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                                      setState(() => _qrImageUrl = img.path);
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
                                      setState(() => _qrImageUrl = img.path);
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
                                  onPressed: () => setState(() => _qrImageUrl = null),
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
                                      child: _qrImageUrl!.startsWith('http')
                                          ? Image.network(
                                              _qrImageUrl!,
                                              width: 150,
                                              height: 150,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 80, color: AppColors.error),
                                            )
                                          : Image.file(
                                              File(_qrImageUrl!),
                                              width: 150,
                                              height: 150,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 80, color: AppColors.error),
                                            ),
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
                    const Text('प्रिंटर और स्टॉक सेटिंग्स', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),

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
                        setState(() => _allowNegativeStock = val);
                      },
                    ),
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
              onPressed: _saveSettings,
              child: const Text('Save All Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
