import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/fmcg_catalog_service.dart';
import '../../core/utils/pos_sound_formatter.dart';
import '../../data/models/fmcg_item.dart';
import '../../data/models/product.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';
import '../pos/widgets/barcode_scanner_dialog.dart';
import '../widgets/product_image_view.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? existing;
  final String? preselectedCategory;

  const AddEditProductScreen({
    super.key,
    this.existing,
    this.preselectedCategory,
  });

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _mrpCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _purchasePriceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _lowStockCtrl;

  late String _unit;
  late String _icon;
  String? _imageUrl;
  String? _selectedCategory;
  final ImagePicker _picker = ImagePicker();
  List<FmcgItem> _fmcgSuggestions = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _mrpCtrl = TextEditingController(text: p?.mrp != null ? p!.mrp.toString() : '');
    _priceCtrl = TextEditingController(text: p != null ? p.price.toString() : '');
    _purchasePriceCtrl = TextEditingController(text: p?.purchasePrice?.toString() ?? '');
    _stockCtrl = TextEditingController(text: p != null ? p.stock.toString() : '0');
    _lowStockCtrl = TextEditingController(text: p != null ? p.lowStockAt.toString() : '5');
    _unit = p?.unit ?? 'kg';
    _icon = p?.icon ?? '📦';
    _imageUrl = p?.imageUrl;

    final prodProv = context.read<ProductProvider>();
    final availableCats = List<String>.from(prodProv.allCategories);
    if (p != null) {
      _selectedCategory = p.category.toUpperCase();
    } else if (widget.preselectedCategory != null && widget.preselectedCategory!.trim().isNotEmpty) {
      _selectedCategory = widget.preselectedCategory!.trim().toUpperCase();
    } else if (availableCats.isNotEmpty) {
      _selectedCategory = availableCats.first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _mrpCtrl.dispose();
    _priceCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _stockCtrl.dispose();
    _lowStockCtrl.dispose();
    super.dispose();
  }

  void _updateFmcgSuggestions(String query) {
    final q = query.trim();
    if (q.length >= 2) {
      setState(() {
        _fmcgSuggestions = FmcgCatalogService.instance.search(q, limit: 5);
      });
    } else {
      if (_fmcgSuggestions.isNotEmpty) {
        setState(() {
          _fmcgSuggestions = [];
        });
      }
    }
  }

  void _applyFmcgItem(FmcgItem item) {
    SoundService.instance.playButtonClick();
    setState(() {
      _nameCtrl.text = item.name;
      _barcodeCtrl.text = item.barcode;
      _mrpCtrl.text = item.mrp.toStringAsFixed(item.mrp % 1 == 0 ? 0 : 2);
      _priceCtrl.text = item.mrp.toStringAsFixed(item.mrp % 1 == 0 ? 0 : 2);
      _purchasePriceCtrl.text = item.defaultCostPrice.toStringAsFixed(item.defaultCostPrice % 1 == 0 ? 0 : 2);
      _unit = item.unit.toLowerCase();
      _icon = item.icon;
      _imageUrl = item.imageUrl;
      _fmcgSuggestions = [];
    });
  }

  void _showAddCategoryDialog(BuildContext context) {
    final newCatCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.category_rounded, color: Color(0xFF1A4B8E), size: 22),
            SizedBox(width: 8),
            Text('नई कैटेगरी जोड़ें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: newCatCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'कैटेगरी का नाम (Category Name) *',
            hintText: 'उदा. COLD DRINKS, DRY FRUITS',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('रद्द करें')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A4B8E),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newName = newCatCtrl.text.trim().toUpperCase();
              if (newName.isNotEmpty) {
                final prodProv = context.read<ProductProvider>();
                await prodProv.addCategory(newName);
                setState(() {
                  _selectedCategory = newName;
                });
                if (mounted) Navigator.pop(dlgCtx);
              }
            },
            child: const Text('जोड़ें (Add)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    if (widget.existing == null) return;
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('सामान हटाएं? (Delete Product)'),
        content: Text('क्या आप सचमुच "${widget.existing!.name}" को स्टॉक से हटाना चाहते हैं?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('रद्द करें')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dlgCtx);
              await context.read<ProductProvider>().deleteProduct(widget.existing!.id);
              SoundService.instance.playButtonClick();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: Colors.red, content: Text('${widget.existing!.name} स्टॉक से हटा दिया गया।')),
                );
              }
            },
            child: const Text('हटाएं (Delete)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text) ?? 0.0;

    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('कृपया सामान का नाम और बिक्री दर सही दर्ज करें!'),
        ),
      );
      return;
    }

    if (_selectedCategory == null || _selectedCategory!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('कृपया सामान की कैटेगरी चुनें या + नई बनाएं!'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final shop = context.read<ShopProvider>().shop;
      final existingId = widget.existing?.id;
      final hasValidUuid = existingId != null &&
          RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
              .hasMatch(existingId);

      final prod = Product(
        id: hasValidUuid ? existingId : const Uuid().v4(),
        shopId: shop.id,
        name: name,
        category: _selectedCategory!.trim().toUpperCase(),
        unit: _unit,
        price: price,
        mrp: double.tryParse(_mrpCtrl.text),
        barcode: _barcodeCtrl.text.trim().isNotEmpty ? _barcodeCtrl.text.trim() : null,
        purchasePrice: double.tryParse(_purchasePriceCtrl.text),
        stock: double.tryParse(_stockCtrl.text) ?? 0.0,
        lowStockAt: double.tryParse(_lowStockCtrl.text) ?? 5.0,
        imageUrl: _imageUrl,
        icon: _icon,
      );

      final provider = context.read<ProductProvider>();
      if (widget.existing == null) {
        await provider.addProduct(prod);
      } else {
        await provider.updateProduct(prod);
      }

      SoundService.instance.playSuccess();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1A4B8E),
            content: Text('✓ "${prod.name}" सफलतापूर्वक सुरक्षित कर लिया गया!'),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.existing != null;
    final prodProv = context.watch<ProductProvider>();
    final availableCats = List<String>.from(prodProv.allCategories);
    if (_selectedCategory != null && !availableCats.contains(_selectedCategory)) {
      availableCats.insert(0, _selectedCategory!);
    }

    final saleVal = double.tryParse(_priceCtrl.text) ?? 0.0;
    final costVal = double.tryParse(_purchasePriceCtrl.text) ?? 0.0;
    final marginVal = saleVal - costVal;
    final marginPct = costVal > 0 ? ((marginVal / costVal) * 100) : 0.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A4B8E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEdit ? 'सामान एडिट करें (Edit Product)' : 'नया सामान जोड़ें (Add Product)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
        ),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              tooltip: 'हटाएं (Delete)',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📦 SECTION 1: सामान्य जानकारी (Basic Info)
            _buildCard(
              isDark: isDark,
              title: 'सामान की सामान्य जानकारी (Basic Details)',
              icon: Icons.inventory_2_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'सामान का नाम (Product Name) *',
                      hintText: 'उदा. आलू, टमाटर, Maggi, Amul Milk',
                      prefixIcon: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF1A4B8E)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) {
                      _updateFmcgSuggestions(val);
                      setState(() {});
                    },
                  ),

                  // FMCG Suggestions Dropdown
                  if (_fmcgSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1A4B8E).withValues(alpha: 0.3)),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: const [
                                Icon(Icons.auto_awesome, size: 14, color: Color(0xFF1A4B8E)),
                                SizedBox(width: 6),
                                Text(
                                  'सुझाव: एक-क्लिक में जोड़ें (FMCG Catalog)',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A4B8E)),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ..._fmcgSuggestions.map((item) => ListTile(
                                dense: true,
                                leading: Text(item.icon, style: const TextStyle(fontSize: 20)),
                                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('₹${item.mrp.toStringAsFixed(0)} / ${item.unit} • Barcode: ${item.barcode}', style: const TextStyle(fontSize: 11)),
                                trailing: const Icon(Icons.touch_app_rounded, color: Color(0xFF1A4B8E), size: 18),
                                onTap: () => _applyFmcgItem(item),
                              )),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Category Selector + New Category Button
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'कैटेगरी (Category) *',
                            prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF1A4B8E)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: availableCats.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF1A4B8E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                        tooltip: 'नई बनाएं',
                        onPressed: () => _showAddCategoryDialog(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Unit Selector Chips
                  const Text('इकाई (Measuring Unit) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: ['kg', 'pc', 'pkt', 'litre', 'bottle', 'g'].map((u) {
                      final isSel = _unit == u;
                      return ChoiceChip(
                        label: Text(u.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSel ? Colors.white : null)),
                        selected: isSel,
                        selectedColor: const Color(0xFF1A4B8E),
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                        onSelected: (sel) {
                          if (sel) setState(() => _unit = u);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 💰 SECTION 2: कीमत व मुनाफा (Pricing & Rates)
            _buildCard(
              isDark: isDark,
              title: 'कीमत व मुनाफा (Pricing & Rates)',
              icon: Icons.currency_rupee_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _mrpCtrl,
                          inputFormatters: [PosNumberSoundFormatter()],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'MRP (₹)',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _priceCtrl,
                          inputFormatters: [PosNumberSoundFormatter()],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'बिक्री दर *',
                            prefixText: '₹ ',
                            labelStyle: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF16A34A))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _purchasePriceCtrl,
                          inputFormatters: [PosNumberSoundFormatter()],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'खरीद दर',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),

                  if (saleVal > 0 && costVal > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: marginVal >= 0 ? const Color(0xFF16A34A).withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: marginVal >= 0 ? const Color(0xFF16A34A).withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                marginVal >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                size: 18,
                                color: marginVal >= 0 ? const Color(0xFF16A34A) : Colors.red,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                marginVal >= 0 ? 'अनुमानित मुनाफा (Profit Margin):' : 'नुकसान (Loss):',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: marginVal >= 0 ? const Color(0xFF16A34A) : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '₹${marginVal.abs().toStringAsFixed(1)} / $_unit (${marginPct.abs().toStringAsFixed(1)}%)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: marginVal >= 0 ? const Color(0xFF16A34A) : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 📊 SECTION 3: स्टॉक व बारकोड (Stock & Barcode)
            _buildCard(
              isDark: isDark,
              title: 'स्टॉक व बारकोड (Stock & Inventory)',
              icon: Icons.bar_chart_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _stockCtrl,
                          inputFormatters: [PosNumberSoundFormatter()],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'वर्तमान स्टॉक ($_unit)',
                            prefixIcon: const Icon(Icons.archive_outlined, color: Color(0xFF1A4B8E)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _lowStockCtrl,
                          inputFormatters: [PosNumberSoundFormatter()],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'अलर्ट सीमा ($_unit)',
                            prefixIcon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _barcodeCtrl,
                          decoration: InputDecoration(
                            labelText: 'बारकोड / SKU (Barcode)',
                            hintText: 'उदा. 8901058852395',
                            prefixIcon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF1A4B8E)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF1A4B8E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                        tooltip: 'बारकोड स्कैन करें',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (scanCtx) => BarcodeScannerDialog(
                              onBarcodeScanned: (code) {
                                SoundService.instance.playBeep();
                                setState(() {
                                  _barcodeCtrl.text = code;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 🖼️ SECTION 4: फोटो / इमेज (Product Photo)
            _buildCard(
              isDark: isDark,
              title: 'सामान की फोटो / इमेज (Visual)',
              icon: Icons.photo_camera_rounded,
              child: Row(
                children: [
                  // Photo Preview
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    alignment: Alignment.center,
                    child: ProductImageView(
                      imageUrl: _imageUrl,
                      fallbackIcon: _icon,
                      size: 64,
                      borderRadius: 12,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPhotoActionChip(
                          icon: Icons.camera_alt_rounded,
                          label: 'कैमरा',
                          onTap: () async {
                            try {
                              final img = await _picker.pickImage(source: ImageSource.camera, maxWidth: 600, maxHeight: 600, imageQuality: 80);
                              if (img != null) {
                                final bytes = await img.readAsBytes();
                                final shop = context.read<ShopProvider>().shop;
                                final url = await SupabaseService.instance.uploadImageBytes(
                                  shopId: shop.id,
                                  folder: 'products',
                                  fileName: '${DateTime.now().millisecondsSinceEpoch}.jpg',
                                  bytes: bytes,
                                );
                                setState(() => _imageUrl = url);
                              }
                            } catch (e) {
                              debugPrint("Camera error: $e");
                            }
                          },
                        ),
                        _buildPhotoActionChip(
                          icon: Icons.photo_library_rounded,
                          label: 'गैलरी',
                          onTap: () async {
                            try {
                              final img = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 600, maxHeight: 600, imageQuality: 80);
                              if (img != null) {
                                final bytes = await img.readAsBytes();
                                final shop = context.read<ShopProvider>().shop;
                                final url = await SupabaseService.instance.uploadImageBytes(
                                  shopId: shop.id,
                                  folder: 'products',
                                  fileName: '${DateTime.now().millisecondsSinceEpoch}.jpg',
                                  bytes: bytes,
                                );
                                setState(() => _imageUrl = url);
                              }
                            } catch (e) {
                              debugPrint("Gallery error: $e");
                            }
                          },
                        ),
                        _buildPhotoActionChip(
                          icon: Icons.emoji_emotions_rounded,
                          label: 'इमोजी',
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (emojiDlg) => SimpleDialog(
                                title: const Text('इमोजी चुनें / Select Emoji'),
                                children: ['🍎', '🍌', '🥭', '🍇', '🥔', '🧅', '🍅', '🥬', '🌶️', '🥛', '🧀', '📦', '🍞', '🍚', '🍫', '🧴', '🧼', '☕', '🥤', '🍪', '🍜', '🧂', '🧈', '🍿']
                                    .map((em) => SimpleDialogOption(
                                          onPressed: () {
                                            setState(() => _icon = em);
                                            Navigator.pop(emojiDlg);
                                          },
                                          child: Text(em, style: const TextStyle(fontSize: 24)),
                                        ))
                                    .toList(),
                              ),
                            );
                          },
                        ),
                        if (_imageUrl != null && _imageUrl!.isNotEmpty)
                          _buildPhotoActionChip(
                            icon: Icons.delete_outline_rounded,
                            label: 'हटाएं',
                            isDestructive: true,
                            onTap: () => setState(() => _imageUrl = null),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -3)),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: Text(
                _isSaving ? 'सुरक्षित हो रहा है...' : (isEdit ? 'सामान अपडेट करें (Update Product)' : 'सामान सुरक्षित करें (Save Product)'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A4B8E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              onPressed: _isSaving ? null : _handleSave,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF1A4B8E)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A4B8E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildPhotoActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.withValues(alpha: 0.1) : const Color(0xFF1A4B8E).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDestructive ? Colors.red.withValues(alpha: 0.3) : const Color(0xFF1A4B8E).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isDestructive ? Colors.red : const Color(0xFF1A4B8E)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isDestructive ? Colors.red : const Color(0xFF1A4B8E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
