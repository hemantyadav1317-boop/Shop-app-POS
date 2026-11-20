import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/contact_service.dart';
import '../../core/services/sound_service.dart';
import '../../data/models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../providers/shop_provider.dart';

class AddCustomerScreen extends StatefulWidget {
  final String? initialName;
  final String? initialPhone;

  const AddCustomerScreen({
    super.key,
    this.initialName,
    this.initialPhone,
  });

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _nameCtrl;
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _dueCtrl = TextEditingController();

  String _selectedGender = 'Not Given';
  DateTime? _selectedDob;
  bool _isSaving = false;

  final List<String> _genderOptions = ['Not Given', 'Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.initialPhone ?? '');
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _gstCtrl.dispose();
    _dueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    SoundService.instance.playButtonClick();
    final res = await ContactService.pickContact();
    if (!mounted) return;
    if (res != null) {
      if (res.permissionDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('कॉन्टैक्ट चुनने के लिए कृपया सेटिंग्स में Contacts परमिशन चालू करें।'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (res.name.isNotEmpty) _nameCtrl.text = res.name;
      if (res.phone.isNotEmpty) {
        String p = res.phone.replaceAll(RegExp(r'[^0-9+]'), '');
        if (p.startsWith('+91') && p.length > 3) p = p.substring(3);
        if (p.startsWith('0') && p.length > 1) p = p.substring(1);
        _phoneCtrl.text = p;
      }
      setState(() {});
    }
  }

  Future<void> _pickDateOfBirth() async {
    SoundService.instance.playButtonClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  Future<void> _saveCustomer() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter customer name / ग्राहक का नाम लिखें'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    SoundService.instance.playButtonClick();

    try {
      final shop = context.read<ShopProvider>().shop;
      final initialDue = double.tryParse(_dueCtrl.text.trim()) ?? 0.0;

      final newCustomer = Customer(
        id: const Uuid().v4(),
        shopId: shop.id,
        name: name,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        gstNo: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim().toUpperCase(),
        gender: _selectedGender != 'Not Given' ? _selectedGender : null,
        dob: _selectedDob != null ? DateFormat('dd/MM/yyyy').format(_selectedDob!) : null,
        balance: initialDue,
        createdAt: DateTime.now(),
      );

      await context.read<CustomerProvider>().addCustomer(newCustomer);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newCustomer.name} successfully added!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding customer: $e'),
            backgroundColor: AppColors.error,
          ),
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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Add Customer',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Load From Contact button matching reference
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _pickContact,
                    icon: const Icon(Icons.perm_contact_calendar_outlined, size: 18),
                    label: const Text('Load From Contact', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Mobile Number
                _buildFieldLabel('Mobile Number'),
                _buildTextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  hintText: 'Enter 10-digit mobile number',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                // Customer Name
                _buildFieldLabel('Customer Name *'),
                _buildTextFormField(
                  controller: _nameCtrl,
                  keyboardType: TextInputType.name,
                  hintText: 'Enter customer full name',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                // Email id
                _buildFieldLabel('Email id'),
                _buildTextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  hintText: 'Enter email address (optional)',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                // Gender & Date of birth Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gender Dropdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Gender (Optional)'),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedGender,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                items: _genderOptions.map((g) {
                                  return DropdownMenuItem<String>(
                                    value: g,
                                    child: Text(
                                      g,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedGender = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Date of Birth Picker
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Date of birth (Optional)'),
                          InkWell(
                            onTap: _pickDateOfBirth,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _selectedDob != null
                                          ? DateFormat('dd/MM/yyyy').format(_selectedDob!)
                                          : 'Add Date of birth',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _selectedDob != null
                                            ? (isDark ? Colors.white : Colors.black87)
                                            : Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Address
                _buildFieldLabel('Address'),
                _buildTextFormField(
                  controller: _addressCtrl,
                  maxLines: 3,
                  hintText: 'Enter complete address (optional)',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                // GST No
                _buildFieldLabel('GST No'),
                _buildTextFormField(
                  controller: _gstCtrl,
                  textCapitalization: TextCapitalization.characters,
                  hintText: 'e.g. 29ABCDE1234F1Z5 (optional)',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                // Previous due amount
                _buildFieldLabel('Previous due amount'),
                _buildTextFormField(
                  controller: _dueCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  hintText: '₹ 0.00 (optional opening balance)',
                  isDark: isDark,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveCustomer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Add',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
    required String hintText,
    required bool isDark,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: 14.5,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
