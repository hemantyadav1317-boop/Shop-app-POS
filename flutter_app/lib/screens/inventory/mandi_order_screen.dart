import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/sound_service.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/locale_provider.dart';

class MandiOrderScreen extends StatefulWidget {
  const MandiOrderScreen({super.key});

  @override
  State<MandiOrderScreen> createState() => _MandiOrderScreenState();
}

class _MandiOrderScreenState extends State<MandiOrderScreen> {
  final Map<String, TextEditingController> _orderQtyControllers = {};
  final Set<String> _selectedProductIds = {};
  final TextEditingController _searchCtrl = TextEditingController();
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _initOrderList();
  }

  void _initOrderList() {
    final products = context.read<ProductProvider>().products;
    final lowStockItems = products.where((p) => p.isLowStock || p.stock <= p.lowStockAt).toList();

    for (final p in lowStockItems) {
      _selectedProductIds.add(p.id);
      double suggested = (p.lowStockAt > 0 ? (p.lowStockAt * 2) - p.stock : 20.0);
      if (suggested <= 0) suggested = p.unit == 'kg' ? 10.0 : 10.0;

      final text = suggested % 1 == 0 ? suggested.toInt().toString() : suggested.toStringAsFixed(1);
      _orderQtyControllers[p.id] = TextEditingController(text: text);
    }
  }

  @override
  void dispose() {
    for (final ctrl in _orderQtyControllers.values) {
      ctrl.dispose();
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  void _stepQuantity(String productId, double delta) {
    SoundService.instance.playButtonClick();
    final ctrl = _orderQtyControllers[productId];
    if (ctrl == null) return;
    double current = double.tryParse(ctrl.text.trim()) ?? 1.0;
    current += delta;
    if (current < 1) current = 1;
    final text = current % 1 == 0 ? current.toInt().toString() : current.toStringAsFixed(1);
    setState(() {
      ctrl.text = text;
    });
  }

  String _buildSlipText(bool isHindi) {
    final shop = context.read<ShopProvider>().shop;
    final products = context.read<ProductProvider>().products;
    final localeCode = context.read<LocaleProvider>().localeCode;
    final productMap = {for (var p in products) p.id: p};

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final phoneLine = (shop.phone != null && shop.phone!.isNotEmpty) ? '📞 ${shop.phone!}\n' : '';

    final buffer = StringBuffer();
    buffer.writeln(isHindi ? '📋 *मंडी / राशन खरीदारी पर्ची*' : '📋 *Mandi / Supplier Purchase Order*');
    buffer.writeln('🏪 *${shop.name}*');
    if (phoneLine.isNotEmpty) buffer.write(phoneLine);
    buffer.writeln('----------------------------------');
    buffer.writeln('${isHindi ? "तारीख:" : "Date:"} $dateStr\n');

    int index = 1;
    double grandTotal = 0;
    for (final id in _selectedProductIds) {
      final p = productMap[id];
      if (p != null) {
        final qtyVal = double.tryParse(_orderQtyControllers[id]?.text.trim() ?? '1') ?? 1.0;
        final cost = p.price * qtyVal;
        grandTotal += cost;
        final qtyStr = _orderQtyControllers[id]?.text.trim() ?? '1';
        buffer.writeln('$index. *${p.localizedName(localeCode)}* - $qtyStr ${p.unit} (₹ ${cost.toStringAsFixed(2)})');
        index++;
      }
    }

    buffer.writeln('----------------------------------');
    buffer.writeln('${isHindi ? "कुल आइटम:" : "Total Items:"} ${_selectedProductIds.length}');
    buffer.writeln('${isHindi ? "अनुमानित कुल राशि:" : "Estimated Total:"} ₹ ${grandTotal.toStringAsFixed(2)}');
    buffer.writeln(isHindi ? 'कृपया माल तैयार रखें या जल्द भेजें। धन्यवाद! 🙏' : 'Please keep goods ready or dispatch soon. Thank you! 🙏');

    return buffer.toString();
  }

  Future<void> _sendViaWhatsApp(bool isHindi) async {
    SoundService.instance.playButtonClick();
    if (_selectedProductIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isHindi ? 'कृपया पर्ची में कम से कम 1 सामान चुनें!' : 'Please select at least 1 item for the order!')),
      );
      return;
    }

    final text = _buildSlipText(isHindi);
    final targetPhone = _searchCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (targetPhone.isNotEmpty) {
      String clean = targetPhone;
      if (clean.length == 10) clean = '91$clean';
      final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // Default Share Sheet fallback
    SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: isHindi ? 'मंडी खरीदारी पर्ची' : 'Mandi Purchase Order',
      ),
    );
  }

  void _showAddCustomItemDialog(bool isDark, bool isHindi) {
    SoundService.instance.playButtonClick();
    final allProducts = context.read<ProductProvider>().products;
    final available = allProducts.where((p) => !_selectedProductIds.contains(p.id)).toList();
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filtered = available.where((p) {
            if (searchQuery.trim().isEmpty) return true;
            return p.name.toLowerCase().contains(searchQuery.toLowerCase().trim());
          }).toList();

          return SafeArea(
            child: Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEDE6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFFFF5722), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isHindi ? 'पर्ची में अन्य सामान जोड़ें' : 'Add Items to Order Slip',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                isHindi ? 'कैटलॉग में से सामान चुनें' : 'Select items from product catalog',
                                style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search Box
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: isHindi ? 'सामान का नाम खोजें...' : 'Search item name...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFFFF5722)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  searchQuery.isEmpty
                                      ? (isHindi ? 'सभी सामान पहले से पर्ची में शामिल हैं।' : 'All products already added to order.')
                                      : (isHindi ? 'कोई सामान नहीं मिला' : 'No items found'),
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final p = filtered[i];
                              final isOutOfStock = p.stock <= 0;
                              final isLowStock = p.stock > 0 && p.stock <= 5;

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFEDE6),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.inventory_2_rounded,
                                        color: Color(0xFFFF5722),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.localizedName(context.read<LocaleProvider>().localeCode),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isOutOfStock
                                                      ? Colors.red.withValues(alpha: 0.12)
                                                      : (isLowStock
                                                          ? Colors.amber.withValues(alpha: 0.15)
                                                          : const Color(0xFF16A34A).withValues(alpha: 0.12)),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  isOutOfStock
                                                      ? (isHindi ? 'स्टॉक खत्म (0 ${p.unit})' : 'Out of Stock (0 ${p.unit})')
                                                      : (isLowStock
                                                          ? (isHindi ? 'कम स्टॉक: ${p.stock} ${p.unit}' : 'Low Stock: ${p.stock} ${p.unit}')
                                                          : (isHindi ? 'स्टॉक: ${p.stock} ${p.unit}' : 'Stock: ${p.stock} ${p.unit}')),
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: isOutOfStock
                                                        ? Colors.red.shade700
                                                        : (isLowStock
                                                            ? Colors.amber.shade900
                                                            : const Color(0xFF16A34A)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF5722),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        elevation: 1,
                                      ),
                                      icon: const Icon(Icons.add, size: 15),
                                      label: Text(isHindi ? 'जोड़ें' : 'Add', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      onPressed: () {
                                        SoundService.instance.playButtonClick();
                                        setState(() {
                                          _selectedProductIds.add(p.id);
                                          _orderQtyControllers[p.id] = TextEditingController(text: '10');
                                        });
                                        Navigator.pop(ctx);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final products = context.watch<ProductProvider>().products;
    final localeCode = context.watch<LocaleProvider>().localeCode;
    final isHindi = localeCode == 'hi';
    final productMap = {for (var p in products) p.id: p};

    final selectedList = _selectedProductIds.toList().where((id) {
      if (_filterQuery.trim().isEmpty) return true;
      final p = productMap[id];
      if (p == null) return false;
      return p.name.toLowerCase().contains(_filterQuery.toLowerCase()) ||
          p.localizedName(localeCode).toLowerCase().contains(_filterQuery.toLowerCase());
    }).toList();

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
        titleSpacing: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            SoundService.instance.playButtonClick();
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.assignment_rounded, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isHindi ? 'मंडी / सप्लायर पर्ची' : 'Mandi / Supplier Order',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 22),
            tooltip: isHindi ? 'सामान जोड़ें' : 'Add Item',
            onPressed: () => _showAddCustomItemDialog(isDark, isHindi),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
            tooltip: isHindi ? 'पर्ची शेयर करें' : 'Share Order Slip',
            onPressed: () => _sendViaWhatsApp(isHindi),
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
              child: Column(
                children: [
                  // Top Search & WhatsApp Row (Matching Image 3)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Search bar
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (val) {
                                setState(() {
                                  _filterQuery = val;
                                });
                              },
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF64748B)),
                                hintText: isHindi ? 'सप्लायर / आइटम का वर्णन खोजें...' : 'Search supplier / item...',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Green WhatsApp Button (Matching Image 3)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            elevation: 1,
                          ),
                          icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                          label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () => _sendViaWhatsApp(isHindi),
                        ),
                      ],
                    ),
                  ),

                  // Section Header Bar (Matching Image 3: Orange bottom line tab + '+ और जोड़ें')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left active section with orange bottom indicator
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.storefront_rounded, color: Color(0xFFFF5722), size: 18),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      isHindi
                                          ? 'पर्ची में शामिल सामान (${_selectedProductIds.length})'
                                          : 'Items in Order (${_selectedProductIds.length})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 2.5,
                                width: 140,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5722),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Right: '+ और जोड़ें'
                        InkWell(
                          onTap: () => _showAddCustomItemDialog(isDark, isHindi),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.add, size: 16, color: Color(0xFFFF5722)),
                                const SizedBox(width: 2),
                                Text(
                                  isHindi ? 'और जोड़ें' : 'Add More',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFFFF5722),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Order Items List or Illustrated Empty State
                  Expanded(
                    child: selectedList.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Soft shop checklist illustration matching Image 3
                                  Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEDE6),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFFFCCBC), width: 1.5),
                                    ),
                                    child: const Icon(Icons.assignment_turned_in_rounded, size: 48, color: Color(0xFFFF5722)),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    isHindi
                                        ? 'और सामान जोड़ने के लिए\nऊपर दिए गए + बटन पर क्लिक करें'
                                        : 'To add more items,\nclick on the + button above',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF5722),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    ),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: Text(
                                      isHindi ? 'सामान जोड़ें' : 'Add Product',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => _showAddCustomItemDialog(isDark, isHindi),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
                            itemCount: selectedList.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final id = selectedList[i];
                              final p = productMap[id];
                              if (p == null) return const SizedBox.shrink();

                              final ctrl = _orderQtyControllers[id] ?? TextEditingController(text: '10');
                              final qtyVal = double.tryParse(ctrl.text.trim()) ?? 1.0;
                              final totalItemCost = p.price * qtyVal;

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
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Squircle Avatar + Name + Sub-pill + Red Trash
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Pastel squircle avatar with initial & produce icon
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFE4E6),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Center(
                                            child: Text(
                                              p.name.isNotEmpty ? p.name[0].toUpperCase() : 'C',
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFFE11D48),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Title & Category tag
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.localizedName(localeCode),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFEDD5),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  p.category.isNotEmpty
                                                      ? p.category
                                                      : (isHindi ? 'ताजा सामान' : 'Fresh Item'),
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFC2410C),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Delete Trash Icon
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 22),
                                          tooltip: isHindi ? 'पर्ची से हटाएं' : 'Remove from order',
                                          onPressed: () {
                                            SoundService.instance.playButtonClick();
                                            setState(() {
                                              _selectedProductIds.remove(id);
                                            });
                                          },
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    // Row 2: Weight & Rate (Left) + Quantity Stepper (Right)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Weight & Rate (Flexible & Scaled)
                                        Expanded(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.balance_rounded, size: 14, color: Color(0xFF64748B)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${isHindi ? "वजन:" : "Stock:"} ${p.stock} ${p.unit}',
                                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                                ),
                                                const SizedBox(width: 6),
                                                const Text('|', style: TextStyle(color: Color(0xFFCBD5E1))),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '₹ ${isHindi ? "दर प्रति" : "Rate /"} ${p.unit}: ${p.price.toStringAsFixed(2)}',
                                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Quantity Stepper ( -  8.5 kg  + ) matching Image 3
                                        Container(
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () => _stepQuantity(id, -1.0),
                                                borderRadius: BorderRadius.circular(6),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Icon(Icons.remove, size: 16, color: Color(0xFF475569)),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                                child: Text(
                                                  '${ctrl.text} ${p.unit}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () => _stepQuantity(id, 1.0),
                                                borderRadius: BorderRadius.circular(6),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Icon(Icons.add, size: 16, color: Color(0xFFFF5722)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    // Row 3: Bottom Highlight Bar: Total Amount (Image 3)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.calculate_rounded, size: 16, color: Color(0xFFEA580C)),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${isHindi ? "कुल राशि :" : "Total Amount :"} ₹ ${totalItemCost.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13.5,
                                              color: Color(0xFFC2410C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),

      // Bottom Glowing Full-Width WhatsApp Button (Matching Image 3)
      bottomSheet: _selectedProductIds.isNotEmpty
          ? Container(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () => _sendViaWhatsApp(isHindi),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            isHindi
                                ? '${_selectedProductIds.length} सामान की पर्ची भेजें (WhatsApp)'
                                : 'Send ${_selectedProductIds.length} Items Order (WhatsApp)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chat_bubble_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
