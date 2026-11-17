import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/sound_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';

class TaxSettingsScreen extends StatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  State<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends State<TaxSettingsScreen> {
  late TextEditingController _gstinCtrl;
  bool _isSaving = false;
  bool _enableGst = false;
  double _defaultTaxRate = 5.0;
  bool _pricesIncludeTax = true;

  final List<double> _rates = [0.0, 5.0, 12.0, 18.0, 28.0];

  @override
  void initState() {
    super.initState();
    final shop = context.read<ShopProvider>().shop;
    _gstinCtrl = TextEditingController(text: shop.gstin ?? '');
    _enableGst = (shop.gstin != null && shop.gstin!.trim().isNotEmpty);
  }

  @override
  void dispose() {
    _gstinCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: AppColors.error, content: Text('सुरक्षा: केवल दुकान मालिक टैक्स विवरण बदल सकते हैं।')),
      );
      return;
    }

    final gstin = _gstinCtrl.text.trim().toUpperCase();
    if (_enableGst && gstin.isNotEmpty && gstin.length != 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('GSTIN नंबर 15 अक्षरों का होना चाहिए (e.g. 07AAAAA0000A1Z5)'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final currentShop = context.read<ShopProvider>().shop;
      final updated = currentShop.copyWith(
        gstin: _enableGst && gstin.isNotEmpty ? gstin : null,
        clearGstin: !_enableGst || gstin.isEmpty,
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
                Text('टैक्स विवरण सुरक्षित कर लिया गया है! ✓', style: TextStyle(fontWeight: FontWeight.bold)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('TAX / VAT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // GST Toggle Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _enableGst,
                activeColor: AppColors.primary,
                title: const Text('बिल पर GST / TAX लागू करें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('ग्राहकों को दिए जाने वाले बिल पर टैक्स ब्रेकअप दिखाएं', style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
                onChanged: (val) => setState(() => _enableGst = val),
              ),
            ),
            const SizedBox(height: 16),

            if (_enableGst) ...[
              // GSTIN Input
              TextField(
                controller: _gstinCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 15,
                decoration: InputDecoration(
                  labelText: 'दुकान का GSTIN नंबर (15 Digits)',
                  hintText: 'उदा. 07AAAAA0000A1Z5',
                  prefixIcon: const Icon(Icons.receipt_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),

              // Default Tax Rate Selector
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
                    const Text('डिफ़ॉल्ट टैक्स दर (Default GST Rate)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      'नए जोड़े जाने वाले सामान के लिए डिफ़ॉल्ट टैक्स दर',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _rates.map((rate) {
                        final isSelected = _defaultTaxRate == rate;
                        return ChoiceChip(
                          label: Text('${rate.toStringAsFixed(0)}% GST'),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setState(() => _defaultTaxRate = rate),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tax Included vs Excluded Toggle
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
                    const Text('टैक्स गणना का प्रकार (Pricing Type)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('MRP / बिक्री मूल्य में टैक्स पहले से शामिल है', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('अधिकतर रिटेल/किराना दुकानों में यही इस्तेमाल होता है (Tax Inclusive)', style: TextStyle(fontSize: 11.5)),
                      value: true,
                      groupValue: _pricesIncludeTax,
                      onChanged: (v) => setState(() => _pricesIncludeTax = v ?? true),
                    ),
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('बिल पर टैक्स अलग से जुड़ेगा (Tax Extra)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('होलसेल / B2B बिलिंग के लिए (Tax Exclusive)', style: TextStyle(fontSize: 11.5)),
                      value: false,
                      groupValue: _pricesIncludeTax,
                      onChanged: (v) => setState(() => _pricesIncludeTax = v ?? false),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'GST बंद होने पर बिल बिना टैक्स ब्रेकअप के सादे कैश मेमो की तरह प्रिंट होंगे।',
                        style: TextStyle(fontSize: 12.5, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
              label: const Text('Save TAX / VAT Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: _isSaving ? null : _saveSettings,
            ),
          ),
        ),
      ),
    );
  }
}
