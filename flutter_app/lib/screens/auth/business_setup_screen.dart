import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/sound_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../main_shell.dart';
import 'login_screen.dart';

class _CountryCode {
  final String code;
  final String dialCode;
  final String flag;
  final String name;

  const _CountryCode({
    required this.code,
    required this.dialCode,
    required this.flag,
    required this.name,
  });
}

const List<_CountryCode> _kCountries = [
  _CountryCode(code: 'IN', dialCode: '+91', flag: '🇮🇳', name: 'India'),
  _CountryCode(code: 'AE', dialCode: '+971', flag: '🇦🇪', name: 'United Arab Emirates (UAE)'),
  _CountryCode(code: 'US', dialCode: '+1', flag: '🇺🇸', name: 'United States'),
  _CountryCode(code: 'GB', dialCode: '+44', flag: '🇬🇧', name: 'United Kingdom'),
  _CountryCode(code: 'CA', dialCode: '+1', flag: '🇨🇦', name: 'Canada'),
  _CountryCode(code: 'NP', dialCode: '+977', flag: '🇳🇵', name: 'Nepal'),
  _CountryCode(code: 'BD', dialCode: '+880', flag: '🇧🇩', name: 'Bangladesh'),
  _CountryCode(code: 'SA', dialCode: '+966', flag: '🇸🇦', name: 'Saudi Arabia'),
  _CountryCode(code: 'SG', dialCode: '+65', flag: '🇸🇬', name: 'Singapore'),
  _CountryCode(code: 'MY', dialCode: '+60', flag: '🇲🇾', name: 'Malaysia'),
  _CountryCode(code: 'AU', dialCode: '+61', flag: '🇦🇺', name: 'Australia'),
  _CountryCode(code: 'QA', dialCode: '+974', flag: '🇶🇦', name: 'Qatar'),
  _CountryCode(code: 'OM', dialCode: '+968', flag: '🇴🇲', name: 'Oman'),
  _CountryCode(code: 'KW', dialCode: '+965', flag: '🇰🇼', name: 'Kuwait'),
];

class BusinessSetupScreen extends StatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen> {
  _CountryCode _selectedCountry = _kCountries[0]; // Default: India 🇮🇳 +91
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedCategory = 'vegetable';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _categories = [
    {
      'id': 'vegetable',
      'label': 'Vegetable & Fruit Store',
      'icon': '🥬',
      'badge': 'Mandi POS',
      'badgeColor': const Color(0xFF10B981),
      'subtitle': 'Weight billing (Kg/g), quick touch pad & mandi rates',
      'defaultName': 'Fresh Veggie Store',
    },
    {
      'id': 'kirana',
      'label': 'Grocery & Kirana Store',
      'icon': '🏪',
      'badge': 'FMCG POS',
      'badgeColor': const Color(0xFF2563EB),
      'subtitle': 'Barcode scanner, 2026 FMCG database, MRP & margins',
      'defaultName': 'Kirana & General Store',
    },
    {
      'id': 'dairy',
      'label': 'Dairy & Milk Parlour',
      'icon': '🥛',
      'badge': 'Dairy',
      'badgeColor': const Color(0xFF06B6D4),
      'subtitle': 'Milk packets, curd, paneer & daily delivery billing',
      'defaultName': 'Dairy Parlour',
    },
    {
      'id': 'bakery',
      'label': 'Bakery & Confectionery',
      'icon': '🍞',
      'badge': 'Bakery',
      'badgeColor': const Color(0xFFF59E0B),
      'subtitle': 'Cakes, breads, pastries & fresh baked items',
      'defaultName': 'Bakes & More',
    },
    {
      'id': 'pharmacy',
      'label': 'Medical & Pharmacy Store',
      'icon': '💊',
      'badge': 'Pharma',
      'badgeColor': const Color(0xFF8B5CF6),
      'subtitle': 'Medicine strips, batch tracking & expiry dates',
      'defaultName': 'Care Pharmacy',
    },
    {
      'id': 'other',
      'label': 'General & Other Retail Store',
      'icon': '📦',
      'badge': 'Retail',
      'badgeColor': const Color(0xFF64748B),
      'subtitle': 'Standard retail POS, multi-category inventory',
      'defaultName': 'My Retail Store',
    },
  ];

  @override
  void initState() {
    super.initState();
    final shop = context.read<ShopProvider>().shop;
    _nameController.text = shop.name.isNotEmpty && shop.name != 'Meri Dukan'
        ? shop.name
        : 'Fresh Veggie Store';

    if (shop.phone != null && shop.phone!.isNotEmpty) {
      String rawPhone = shop.phone!.trim();
      for (final c in _kCountries) {
        if (rawPhone.startsWith(c.dialCode)) {
          _selectedCountry = c;
          rawPhone = rawPhone.substring(c.dialCode.length).trim();
          break;
        }
      }
      _phoneController.text = rawPhone;
    }

    if (_categories.any((c) => c['id'] == shop.storeType)) {
      _selectedCategory = shop.storeType;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _currentCategory {
    return _categories.firstWhere(
      (c) => c['id'] == _selectedCategory,
      orElse: () => _categories[0],
    );
  }

  void _onCategorySelected(String catId) {
    setState(() {
      _selectedCategory = catId;
      final matched = _categories.firstWhere((c) => c['id'] == catId);
      if (_nameController.text.trim().isEmpty ||
          _categories.any((c) => c['defaultName'] == _nameController.text.trim())) {
        _nameController.text = matched['defaultName'] as String;
      }
    });
  }

  void _showCountryPicker(bool isDark) {
    SoundService.instance.playButtonClick();
    final searchCtrl = TextEditingController();
    List<_CountryCode> filtered = List.from(_kCountries);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final dialogBg = isDark ? const Color(0xFF131F3B) : Colors.white;
          final dialogText = isDark ? Colors.white : const Color(0xFF0F172A);
          final dialogSubtext = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
          final inputBg = isDark ? const Color(0xFF0A1124) : const Color(0xFFF8FAFC);
          final inputBorder = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFCBD5E1);

          return AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Country Code',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: dialogText,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  style: TextStyle(
                    color: dialogText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search country or code...',
                    hintStyle: TextStyle(color: dialogSubtext, fontSize: 13),
                    prefixIcon: Icon(Icons.search, size: 20, color: dialogSubtext),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: inputBorder),
                    ),
                  ),
                  onChanged: (query) {
                    final q = query.toLowerCase().trim();
                    setModalState(() {
                      filtered = _kCountries.where((c) {
                        return c.name.toLowerCase().contains(q) ||
                            c.dialCode.contains(q) ||
                            c.code.toLowerCase().contains(q);
                      }).toList();
                    });
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              height: 320,
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No countries found',
                        style: TextStyle(color: dialogSubtext),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (ctx, i) {
                        final country = filtered[i];
                        final isSel = country.code == _selectedCountry.code;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: Text(
                            country.flag,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(
                            country.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              color: isSel ? (isDark ? const Color(0xFFF59E0B) : const Color(0xFF0F2038)) : dialogText,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                country.dialCode,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSel ? (isDark ? const Color(0xFFF59E0B) : const Color(0xFF0F2038)) : dialogSubtext,
                                ),
                              ),
                              if (isSel) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF00875A), size: 18),
                              ],
                            ],
                          ),
                          onTap: () {
                            SoundService.instance.playClick();
                            setState(() => _selectedCountry = country);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: dialogSubtext)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCategorySelectionModal(bool isDark) {
    SoundService.instance.playButtonClick();
    final modalBg = isDark ? const Color(0xFF131F3B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBorder = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: modalBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
              maxWidth: 540,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Business Category',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Personalize your POS billing interface & catalog',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Category Cards List
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final cat = _categories[i];
                        final isSelected = cat['id'] == _selectedCategory;
                        final Color badgeColor = cat['badgeColor'] as Color;

                        return InkWell(
                          onTap: () {
                            SoundService.instance.playClick();
                            _onCategorySelected(cat['id'] as String);
                            Navigator.pop(ctx);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? badgeColor.withValues(alpha: isDark ? 0.15 : 0.08)
                                  : (isDark ? const Color(0xFF0F1A33) : Colors.white),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? badgeColor : cardBorder,
                                width: isSelected ? 1.8 : 1.2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: badgeColor.withValues(alpha: 0.16),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Icon Box
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      cat['icon'] as String,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Text details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              cat['label'] as String,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color: textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: badgeColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              cat['badge'] as String,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: badgeColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        cat['subtitle'] as String,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: textSecondary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Radio indicator
                                Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: isSelected ? badgeColor : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleGetStarted() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your business name')),
      );
      return;
    }

    setState(() => _isLoading = true);
    SoundService.instance.playSuccess();

    try {
      final shopProvider = context.read<ShopProvider>();
      final currentShop = shopProvider.shop;
      final enteredPhone = _phoneController.text.trim();
      final fullPhone = enteredPhone.isNotEmpty
          ? '${_selectedCountry.dialCode} $enteredPhone'
          : null;

      final updatedShop = currentShop.copyWith(
        name: name,
        phone: fullPhone,
        storeType: _selectedCategory,
      );

      await shopProvider.updateShop(updatedShop);

      // Permanently remember that user has completed onboarding setup
      final prefs = await SharedPreferences.getInstance();
      final auth = context.read<AuthProvider>();
      final userKey = auth.user != null ? 'setup_done_${auth.user!.id}' : 'setup_done_guest';
      await prefs.setBool(userKey, true);
      await prefs.setString('selected_store_type', _selectedCategory);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving business details: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    final auth = context.read<AuthProvider>();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('setup_done_guest');
    await prefs.remove('is_guest_mode');
    await prefs.remove('selected_store_type');
    await auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currCat = _currentCategory;

    // High-Contrast Colors explicitly calibrated for both Light & Dark modes
    final scaffoldBg = isDark
        ? const Color(0xFF0A1124) // Deep Navy
        : (isDesktop ? const Color(0xFFF1F5F9) : Colors.white);

    final cardBg = isDark
        ? const Color(0xFF131F3B) // Rich Dark Slate
        : Colors.white;

    final cardBorder = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);

    // Guaranteed High-Contrast Colors for Inputs & Text
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final hintColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final headingColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subheadColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 20,
              vertical: isDesktop ? 32 : 18,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: isDesktop
                    ? const EdgeInsets.symmetric(horizontal: 36, vertical: 34)
                    : const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: isDesktop
                    ? BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Breadcrumb: Setup • Business Details
                    Row(
                      children: [
                        Text(
                          'Setup',
                          style: TextStyle(
                            color: labelColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Business Details',
                          style: TextStyle(
                            color: headingColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Header Title (Matching Image 2)
                    Text(
                      'Enter your\nBusiness Details',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: headingColor,
                        height: 1.15,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tell us about your shop so we can personalize your experience.',
                      style: TextStyle(
                        fontSize: 14,
                        color: subheadColor,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 1. CONTACT NUMBER (With Flag & Country Code Selector)
                    Text(
                      'CONTACT NUMBER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: inputBorder, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          // Flag & Dial Code Button
                          InkWell(
                            onTap: () => _showCountryPicker(isDark),
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _selectedCountry.flag,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedCountry.dialCode,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_drop_down_rounded,
                                    size: 18,
                                    color: labelColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: inputBorder,
                          ),
                          // Phone Number Input (Explicit High Contrast)
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              cursorColor: isDark ? const Color(0xFFF59E0B) : const Color(0xFF0F2038),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textColor, // Explicit readable text color
                              ),
                              decoration: InputDecoration(
                                hintText: '98765 43210 (Optional)',
                                hintStyle: TextStyle(
                                  fontSize: 13.5,
                                  color: hintColor,
                                  fontWeight: FontWeight.normal,
                                ),
                                filled: true,
                                fillColor: inputBg, // Explicit background matching container
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. BUSINESS CATEGORY (Custom Professional Dropdown Selector)
                    Text(
                      'BUSINESS CATEGORY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 7),
                    InkWell(
                      onTap: () => _showCategorySelectionModal(isDark),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: inputBorder, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Text(
                              currCat['icon'] as String,
                              style: const TextStyle(fontSize: 19),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                currCat['label'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: (currCat['badgeColor'] as Color).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                currCat['badge'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: currCat['badgeColor'] as Color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: labelColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. BUSINESS NAME (Explicit High Contrast)
                    Text(
                      'BUSINESS NAME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: inputBorder, width: 1.5),
                      ),
                      child: TextField(
                        controller: _nameController,
                        cursorColor: isDark ? const Color(0xFFF59E0B) : const Color(0xFF0F2038),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor, // Explicit readable text color
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter Business name',
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            color: hintColor,
                            fontWeight: FontWeight.normal,
                          ),
                          filled: true,
                          fillColor: inputBg, // Explicit background matching container
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Info Note Box (Exact match to Image 2 with Dark Mode Support)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEFCE8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : const Color(0xFFFEF08A),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFCA8A04),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You can edit it later from the settings',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF854D0E),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Action Buttons (Get Started → and Sign Out)
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleGetStarted,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF0F2038),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  'Get Started',
                                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 19),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),

                    // Sign Out Button (Matching Image 2 Soft Red/Pink)
                    TextButton(
                      onPressed: _isLoading ? null : _handleSignOut,
                      style: TextButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF3B1D24) : const Color(0xFFFEE2E2),
                        foregroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
