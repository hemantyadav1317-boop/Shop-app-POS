import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/sound_service.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';

class MandiOrderScreen extends StatefulWidget {
  const MandiOrderScreen({super.key});

  @override
  State<MandiOrderScreen> createState() => _MandiOrderScreenState();
}

class _MandiOrderScreenState extends State<MandiOrderScreen> {
  final Map<String, TextEditingController> _orderQtyControllers = {};
  final Set<String> _selectedProductIds = {};
  final TextEditingController _supplierPhoneCtrl = TextEditingController();

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
      // Suggested restock quantity: 2x lowStockAt or 20/50 for veggies
      double suggested = (p.lowStockAt > 0 ? (p.lowStockAt * 2) - p.stock : 20.0);
      if (suggested <= 0) suggested = p.unit == 'kg' ? 25.0 : 10.0;

      final text = suggested % 1 == 0 ? suggested.toInt().toString() : suggested.toStringAsFixed(1);
      _orderQtyControllers[p.id] = TextEditingController(text: text);
    }
  }

  @override
  void dispose() {
    for (final ctrl in _orderQtyControllers.values) {
      ctrl.dispose();
    }
    _supplierPhoneCtrl.dispose();
    super.dispose();
  }

  String _buildSlipText() {
    final shop = context.read<ShopProvider>().shop;
    final products = context.read<ProductProvider>().products;
    final productMap = {for (var p in products) p.id: p};

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final phoneLine = (shop.phone != null && shop.phone!.isNotEmpty) ? '📞 ${shop.phone!}\n' : '';

    final buffer = StringBuffer();
    buffer.writeln('📋 *मंडी / राशन खरीदारी पर्ची*');
    buffer.writeln('🏪 *${shop.name}*');
    if (phoneLine.isNotEmpty) buffer.write(phoneLine);
    buffer.writeln('----------------------------------');
    buffer.writeln('तारीख: $dateStr\n');

    int index = 1;
    for (final id in _selectedProductIds) {
      final p = productMap[id];
      if (p != null) {
        final qtyStr = _orderQtyControllers[id]?.text.trim() ?? '1';
        buffer.writeln('$index. *${p.name}* - $qtyStr ${p.unit}');
        index++;
      }
    }

    buffer.writeln('----------------------------------');
    buffer.writeln('कुल आइटम: ${_selectedProductIds.length}');
    buffer.writeln('कृपया माल तैयार रखें या जल्द भेजें। धन्यवाद! 🙏');

    return buffer.toString();
  }

  Future<void> _sendViaWhatsApp() async {
    SoundService.instance.playButtonClick();
    if (_selectedProductIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया पर्ची में कम से कम 1 सामान चुनें!')),
      );
      return;
    }

    final text = _buildSlipText();
    final targetPhone = _supplierPhoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

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
        subject: 'मंडी खरीदारी पर्ची',
      ),
    );
  }

  void _showAddCustomItemDialog() {
    SoundService.instance.playButtonClick();
    final allProducts = context.read<ProductProvider>().products;
    final available = allProducts.where((p) => !_selectedProductIds.contains(p.id)).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  // Top Drag Handle
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

                  // Header with Title & Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'पर्ची में अन्य सामान जोड़ें',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'कैटलॉग में से सामान चुनें',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey),
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

                  // Live Search Box
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      autofocus: false,
                      decoration: const InputDecoration(
                        hintText: 'सामान का नाम खोजें...',
                        prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Product List
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  searchQuery.isEmpty ? 'सभी सामान पहले से पर्ची में शामिल हैं।' : 'कोई सामान नहीं मिला',
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
                                    // Rich Product Icon
                                    Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.inventory_2_rounded,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Product Name & Stock Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
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
                                                      ? 'स्टॉक खत्म (0 ${p.unit})'
                                                      : (isLowStock
                                                          ? 'कम स्टॉक: ${p.stock} ${p.unit}'
                                                          : 'स्टॉक: ${p.stock} ${p.unit}'),
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

                                    // Modern Orange Add Button
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        elevation: 1,
                                      ),
                                      icon: const Icon(Icons.add, size: 15),
                                      label: const Text('जोड़ें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
    final productMap = {for (var p in products) p.id: p};

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.assignment_outlined, color: Color(0xFFFBBF24), size: 22),
            SizedBox(width: 8),
            Text('मंडी / सप्लायर पर्ची', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'सामान जोड़ें',
            onPressed: _showAddCustomItemDialog,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'पर्ची शेयर करें',
            onPressed: _sendViaWhatsApp,
          ),
        ],
      ),
      body: Column(
        children: [
          // Supplier Phone Quick Input Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _supplierPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                      hintText: 'सप्लायर / आढ़ती का फ़ोन नंबर (वैकल्पिक)',
                      hintStyle: const TextStyle(fontSize: 12),
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 14),
                  label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: _sendViaWhatsApp,
                ),
              ],
            ),
          ),

          // Items Count Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'पर्ची में शामिल सामान (${_selectedProductIds.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('और जोड़ें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: _showAddCustomItemDialog,
                ),
              ],
            ),
          ),

          // Main List of Order Items
          Expanded(
            child: _selectedProductIds.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'बधाई! सभी सामान का पर्याप्त स्टॉक है ✓',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'कोई भी आइटम लो-स्टॉक नहीं है। आप मैन्युअल रूप से जोड़ सकते हैं।',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('सामान जोड़ें'),
                          onPressed: _showAddCustomItemDialog,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: _selectedProductIds.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final id = _selectedProductIds.elementAt(i);
                      final p = productMap[id];
                      if (p == null) return const SizedBox.shrink();

                      final ctrl = _orderQtyControllers[id] ?? TextEditingController(text: '10');

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: p.isLowStock
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                  : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                              child: Text(
                                p.name.isNotEmpty ? p.name[0] : '?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: p.isLowStock ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        'स्टॉक: ${p.stock} ${p.unit}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: p.isLowStock ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                        ),
                                      ),
                                      if (p.isLowStock) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('कम स्टॉक', style: TextStyle(fontSize: 9.5, color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Order Quantity Input Field
                            Container(
                              width: 85,
                              margin: const EdgeInsets.only(right: 6),
                              child: TextField(
                                controller: ctrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                decoration: InputDecoration(
                                  suffixText: p.unit,
                                  suffixStyle: const TextStyle(fontSize: 10, color: Colors.grey),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            // Remove Button
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF94A3B8), size: 20),
                              tooltip: 'पर्ची से हटाएं',
                              onPressed: () {
                                SoundService.instance.playButtonClick();
                                setState(() {
                                  _selectedProductIds.remove(id);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Action Bar with SafeArea padding
          if (_selectedProductIds.isNotEmpty)
            SafeArea(
              top: false,
              bottom: true,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3))],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      '${_selectedProductIds.length} सामानों की पर्ची भेजें (WhatsApp)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: _sendViaWhatsApp,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
