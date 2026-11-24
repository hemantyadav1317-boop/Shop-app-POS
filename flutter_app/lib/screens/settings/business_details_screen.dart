import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/sound_service.dart';
import '../../core/utils/payment_qr_helper.dart';
import '../../data/models/shop.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/shop_provider.dart';
import '../auth/login_screen.dart';

class BusinessDetailsScreen extends StatefulWidget {
  const BusinessDetailsScreen({super.key});

  @override
  State<BusinessDetailsScreen> createState() => _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends State<BusinessDetailsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _googleReviewUrlCtrl;
  late TextEditingController _footerCtrl;
  String? _qrImageUrl;
  late String _storeType;
  List<String> _hybridModules = [];
  bool _isSaving = false;

  List<Map<String, String>> _getStoreTypes(bool isHindi) {
    if (isHindi) {
      return const [
        {'id': 'kirana', 'label': 'किराना स्टोर', 'icon': '🛒'},
        {'id': 'vegetable', 'label': 'सब्जी व फल', 'icon': '🥬'},
        {'id': 'restaurant', 'label': 'रेस्टोरेंट व कैफे', 'icon': '🍽️'},
        {'id': 'clothing', 'label': 'कपड़े व गारमेंट्स', 'icon': '👕'},
        {'id': 'electronics', 'label': 'इलेक्ट्रॉनिक्स व मोबाइल', 'icon': '📱'},
        {'id': 'medical', 'label': 'दवा व मेडिकल स्टोर', 'icon': '💊'},
        {'id': 'mix', 'label': 'जनरल स्टोर', 'icon': '🏬'},
        {'id': 'other', 'label': 'अन्य व्यवसाय', 'icon': '🏢'},
      ];
    }
    return const [
      {'id': 'kirana', 'label': 'Grocery / Kirana', 'icon': '🛒'},
      {'id': 'vegetable', 'label': 'Vegetables & Fruits', 'icon': '🥬'},
      {'id': 'restaurant', 'label': 'Restaurant & Cafe', 'icon': '🍽️'},
      {'id': 'clothing', 'label': 'Clothing & Garments', 'icon': '👕'},
      {'id': 'electronics', 'label': 'Electronics & Mobile', 'icon': '📱'},
      {'id': 'medical', 'label': 'Pharmacy & Medical', 'icon': '💊'},
      {'id': 'mix', 'label': 'General Store', 'icon': '🏬'},
      {'id': 'other', 'label': 'Other Business', 'icon': '🏢'},
    ];
  }

  @override
  void initState() {
    super.initState();
    final shop = context.read<ShopProvider>().shop;
    _nameCtrl = TextEditingController(text: shop.name);
    _phoneCtrl = TextEditingController(text: shop.phone ?? '');
    _addressCtrl = TextEditingController(text: shop.address ?? '');
    _googleReviewUrlCtrl = TextEditingController(text: shop.googleReviewUrl ?? '');
    _footerCtrl = TextEditingController(text: shop.receiptFooter ?? 'धन्यवाद! फिर पधारें 🙏');
    _qrImageUrl = shop.qrImageUrl;
    _storeType = shop.storeType.isNotEmpty ? shop.storeType : 'kirana';
    _hybridModules = List<String>.from(shop.hybridModules);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _googleReviewUrlCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('सुरक्षा: केवल दुकान मालिक फोटो बदल सकते हैं।'),
        ),
      );
      return;
    }

    try {
      final img = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (img != null) {
        final bytes = await img.readAsBytes();
        final shop = context.read<ShopProvider>().shop;
        final uploadedUrl = await SupabaseService.instance.uploadImageBytes(
          shopId: shop.id,
          folder: 'qr',
          fileName: 'standee_${DateTime.now().millisecondsSinceEpoch}.jpg',
          bytes: bytes,
        );
        setState(() {
          _qrImageUrl = uploadedUrl ?? img.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('फोटो अपलोड में त्रुटि: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _confirmLogout(BuildContext context) {
    SoundService.instance.playButtonClick();
    final authProvider = context.read<AuthProvider>();
    final shop = context.read<ShopProvider>().shop;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHindi = context.read<LocaleProvider>().localeCode == 'hi';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                Text(
                  isHindi ? 'लॉगआउट करें?' : 'Confirm Logout?',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  isHindi
                      ? 'क्या आप वाकई "${shop.name}" के खाते से लॉगआउट करना चाहते हैं?'
                      : 'Are you sure you want to sign out from "${shop.name}"?',
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
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_done_rounded, color: Color(0xFF00875A), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isHindi
                              ? 'चिंता न करें! आपका सारा डेटा (बिल, स्टॉक, खाता) सुरक्षित है।'
                              : 'Your data (bills, stock, khata) is safe and backed up.',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF00875A)),
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
                        child: Text(isHindi ? 'रद्द करें' : 'Cancel', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                        child: Text(isHindi ? 'हाँ, लॉगआउट करें' : 'Sign Out', style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Future<void> _saveSettings() async {
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('सुरक्षा नियम: केवल दुकान मालिक दुकान की जानकारी बदल सकते हैं।'),
        ),
      );
      return;
    }

    final reviewUrl = _googleReviewUrlCtrl.text.trim();
    if (reviewUrl.isNotEmpty && !PaymentQrHelper.isValidGoogleReviewUrl(reviewUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('कृपया मान्य Google Maps Review URL दर्ज करें (https:// से शुरू)।'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final currentShop = context.read<ShopProvider>().shop;
      final updated = currentShop.copyWith(
        name: _nameCtrl.text.trim().isEmpty ? 'BillZo POS' : _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        clearPhone: _phoneCtrl.text.trim().isEmpty,
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        clearAddress: _addressCtrl.text.trim().isEmpty,
        googleReviewUrl: reviewUrl.isEmpty ? null : reviewUrl,
        clearGoogleReviewUrl: reviewUrl.isEmpty,
        receiptFooter: _footerCtrl.text.trim(),
        storeType: _storeType,
        hybridModules: _hybridModules,
        qrImageUrl: (_qrImageUrl != null && _qrImageUrl!.trim().isNotEmpty) ? _qrImageUrl : null,
        clearQrImageUrl: _qrImageUrl == null || _qrImageUrl!.trim().isEmpty,
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
                Text('बिजनेस की जानकारी सुरक्षित कर ली गई है! ✓', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('सेव करने में त्रुटि: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final shopProvider = context.watch<ShopProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHindi = context.watch<LocaleProvider>().localeCode == 'hi';
    final storeTypes = _getStoreTypes(isHindi);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Business Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Account / Role Pill Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: authProvider.isStaffSession ? const Color(0xFFE8F5E9) : const Color(0xFFE0E7FF),
                    radius: 22,
                    child: Icon(
                      authProvider.isStaffSession ? Icons.storefront_rounded : Icons.person_rounded,
                      color: authProvider.isStaffSession ? const Color(0xFF00875A) : AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authProvider.isStaffSession ? shopProvider.shop.name : authProvider.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          authProvider.isStaffSession
                              ? 'स्टाफ: ${authProvider.staffName ?? "कैशियर"}'
                              : (authProvider.email ?? 'मालिक (Owner)'),
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Store Name
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Business / Shop Name *',
                hintText: 'उदा. श्री गणेश किराना स्टोर',
                prefixIcon: const Icon(Icons.storefront_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            // Store Type Dropdown
            DropdownButtonFormField<String>(
              value: storeTypes.any((t) => t['id'] == _storeType) ? _storeType : 'kirana',
              decoration: InputDecoration(
                labelText: isHindi ? 'दुकान का प्रकार' : 'Business Category',
                prefixIcon: const Icon(Icons.storefront_rounded, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: storeTypes.map((t) {
                return DropdownMenuItem<String>(
                  value: t['id'],
                  child: Text('${t['icon']} ${t['label']}', overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _storeType = val;
                    _hybridModules.remove(val);
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            // Hybrid Add-ons
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hub_rounded, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Text(
                        isHindi ? 'अतिरिक्त बिज़नेस मॉड्यूल' : 'Additional Business Modules',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (_storeType != 'kirana')
                        FilterChip(
                          label: Text(isHindi ? '🛒 + किराना व FMCG' : '🛒 + Kirana & FMCG', style: const TextStyle(fontSize: 11.5)),
                          selected: _hybridModules.contains('kirana'),
                          onSelected: (val) {
                            setState(() {
                              if (val) _hybridModules.add('kirana');
                              else _hybridModules.remove('kirana');
                            });
                          },
                        ),
                      if (_storeType != 'vegetable')
                        FilterChip(
                          label: Text(isHindi ? '🥬 + फल व सब्ज़ी' : '🥬 + Fruits & Veg', style: const TextStyle(fontSize: 11.5)),
                          selected: _hybridModules.contains('vegetable'),
                          onSelected: (val) {
                            setState(() {
                              if (val) _hybridModules.add('vegetable');
                              else _hybridModules.remove('vegetable');
                            });
                          },
                        ),
                      if (_storeType != 'dairy')
                        FilterChip(
                          label: Text(isHindi ? '🥛 + डेयरी व दूध' : '🥛 + Dairy & Milk', style: const TextStyle(fontSize: 11.5)),
                          selected: _hybridModules.contains('dairy'),
                          onSelected: (val) {
                            setState(() {
                              if (val) _hybridModules.add('dairy');
                              else _hybridModules.remove('dairy');
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Phone
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Business Phone Number',
                hintText: 'उदा. 9876543210',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            // Location / Address
            TextField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Business Address / Location',
                hintText: 'दुकान का पूरा पता, शहर, पिन कोड',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            // Google Maps Review URL
            TextField(
              controller: _googleReviewUrlCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Google Maps Review Link (Optional)',
                hintText: 'https://g.page/r/... (बिल पर QR बनेगा)',
                prefixIcon: const Icon(Icons.star_outline_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            // Receipt Tagline / Footer Note
            TextField(
              controller: _footerCtrl,
              decoration: InputDecoration(
                labelText: 'Receipt Footer / Tagline',
                hintText: 'उदा. धन्यवाद! फिर पधारें 🙏',
                prefixIcon: const Icon(Icons.format_quote_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),

            // Shop Logo / Standee QR Image
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Store Logo / Standee QR Photo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'अपनी दुकान का लोगो या स्टैंडी का फोटो लगाएं जो रसीद व पेमेंट पर दिखेगा',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  if (_qrImageUrl != null && _qrImageUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _qrImageUrl!,
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.photo_camera, size: 16),
                          label: Text(isHindi ? 'बदलें' : 'Change'),
                          onPressed: () => _pickImage(ImageSource.camera),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: Text(isHindi ? 'हटाएं' : 'Delete'),
                          onPressed: () => setState(() => _qrImageUrl = null),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: Text(isHindi ? 'कैमरा' : 'Camera'),
                            onPressed: () => _pickImage(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(isHindi ? 'गैलरी' : 'Gallery'),
                            onPressed: () => _pickImage(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Sign Out / Logout Option inside Business Details
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: BorderSide(color: const Color(0xFFDC2626).withValues(alpha: 0.5), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                onPressed: () => _confirmLogout(context),
                label: Text(
                  isHindi ? 'लॉगआउट करें (Sign Out)' : 'Sign Out',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
      bottomNavigationBar: authProvider.isStaffSession
          ? null
          : Container(
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
                    label: Text(
                      isHindi ? 'दुकान विवरण सहेजें' : 'Save Business Details',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: _isSaving ? null : _saveSettings,
                  ),
                ),
              ),
            ),
    );
  }
}
