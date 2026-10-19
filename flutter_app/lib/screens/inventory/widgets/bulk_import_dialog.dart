import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/shop_provider.dart';

class BulkImportDialog extends StatefulWidget {
  const BulkImportDialog({super.key});

  @override
  State<BulkImportDialog> createState() => _BulkImportDialogState();
}

class _ParsedItem {
  String name;
  String category;
  double price;
  double cost;
  double stock;
  String unit;
  bool selected = true;

  _ParsedItem({
    required this.name,
    this.category = 'GENERAL',
    this.price = 0.0,
    this.cost = 0.0,
    this.stock = 10.0,
    this.unit = 'pc',
  });
}

class _BulkImportDialogState extends State<BulkImportDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _csvTextCtrl = TextEditingController();
  final TextEditingController _billTextCtrl = TextEditingController();
  File? _billImage;
  List<_ParsedItem> _parsedItems = [];
  bool _isSaving = false;

  static const String _sampleTemplate = '''चावल बासमती 1kg,किराना,90,75,50,kg
चीनी 1kg,किराना,45,38,100,kg
सरसों तेल 1L,किराना,140,120,30,pc
टाटा नमक 1kg,किराना,28,22,60,pc
पारले-जी बिस्कुट,स्नैक्स,10,8,120,pc
मैगी नूडल्स 70g,स्नैक्स,14,11,80,pc
डव साबुन 100g,पर्सनल केयर,55,46,40,pc
कोलगेट पेस्ट 100g,पर्सनल केयर,65,52,50,pc
अमूल ताजा दूध 500ml,डेयरी,33,30,40,pc
आलू,सब्जी,30,22,50,kg
प्याज,सब्जी,35,26,40,kg
टमाटर,सब्जी,40,30,30,kg''';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _csvTextCtrl.dispose();
    _billTextCtrl.dispose();
    super.dispose();
  }

  void _parseCsvText(String rawText) {
    if (rawText.trim().isEmpty) return;

    final lines = rawText.split(RegExp(r'\r?\n'));
    final List<_ParsedItem> items = [];

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Skip header row if present
      final lower = line.toLowerCase();
      if (lower.startsWith('item') || lower.startsWith('नाम') || lower.startsWith('name') || lower.startsWith('product')) {
        continue;
      }

      // Support Comma separated or Tab separated (direct paste from Excel)
      List<String> parts;
      if (line.contains('\t')) {
        parts = line.split('\t');
      } else {
        parts = line.split(',');
      }

      if (parts.isEmpty) continue;

      final name = parts[0].trim();
      if (name.isEmpty) continue;

      String category = 'GENERAL';
      if (parts.length > 1 && parts[1].trim().isNotEmpty) {
        category = parts[1].trim().toUpperCase();
      }

      double price = 0.0;
      if (parts.length > 2) {
        price = double.tryParse(parts[2].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      }

      double cost = 0.0;
      if (parts.length > 3) {
        cost = double.tryParse(parts[3].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      }

      double stock = 10.0;
      if (parts.length > 4) {
        stock = double.tryParse(parts[4].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 10.0;
      }

      String unit = 'pc';
      if (parts.length > 5 && parts[5].trim().isNotEmpty) {
        unit = parts[5].trim().toLowerCase();
      }

      items.add(_ParsedItem(
        name: name,
        category: category,
        price: price,
        cost: cost,
        stock: stock,
        unit: unit,
      ));
    }

    setState(() {
      _parsedItems = items;
    });
  }

  void _parseBillText(String rawText) {
    if (rawText.trim().isEmpty) return;

    final lines = rawText.split(RegExp(r'\r?\n'));
    final List<_ParsedItem> items = [];

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Extract numbers and words
      // e.g. "Sugar 50kg @ 38 = 1900" or "Fortune Oil 15 130"
      final parts = line.split(RegExp(r'\s{2,}|\t|,|\|'));
      if (parts.length >= 2) {
        final name = parts[0].trim();
        double price = 0.0;
        double cost = 0.0;
        double stock = 10.0;
        String unit = 'pc';

        if (name.toLowerCase().contains('kg') || name.contains('किलो')) {
          unit = 'kg';
        } else if (name.toLowerCase().contains('ltr') || name.contains('लीटर')) {
          unit = 'ltr';
        }

        // Try to find price and stock from remaining tokens
        final numbers = <double>[];
        for (var i = 1; i < parts.length; i++) {
          final clean = parts[i].replaceAll(RegExp(r'[^0-9.]'), '');
          final n = double.tryParse(clean);
          if (n != null && n > 0) numbers.add(n);
        }

        if (numbers.length >= 2) {
          cost = numbers[0];
          price = (cost * 1.15).roundToDouble(); // default 15% margin if only cost provided
          stock = numbers[1];
        } else if (numbers.length == 1) {
          price = numbers[0];
          cost = (price * 0.85).roundToDouble();
        }

        items.add(_ParsedItem(
          name: name,
          category: 'GENERAL',
          price: price,
          cost: cost,
          stock: stock,
          unit: unit,
        ));
      }
    }

    setState(() {
      _parsedItems = items;
    });
  }

  Future<void> _pickBillImage(ImageSource source) async {
    try {
      final img = await ImagePicker().pickImage(source: source, maxWidth: 1200);
      if (img != null) {
        setState(() {
          _billImage = File(img.path);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('बिल फोटो लोड हो गई! नीचे टेक्स्ट बॉक्स में बिल के मुख्य आइटम दर्ज करें या सीधे पार्स करें।'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Pick bill image error: $e");
    }
  }

  Future<void> _saveAllToStock() async {
    final selectedItems = _parsedItems.where((i) => i.selected && i.name.trim().isNotEmpty).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया कम से कम एक आइटम सेलेक्ट करें')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final shop = context.read<ShopProvider>().shop;
      final productProvider = context.read<ProductProvider>();
      const uuid = Uuid();

      final List<Product> batch = [];

      for (final item in selectedItems) {
        // Register category if new
        if (item.category.isNotEmpty && item.category != 'GENERAL') {
          await productProvider.addCategory(item.category);
        }

        final p = Product(
          id: uuid.v4(),
          shopId: shop.id,
          name: item.name.trim(),
          category: item.category.trim().toUpperCase(),
          unit: item.unit.trim().toLowerCase(),
          price: item.price > 0 ? item.price : item.cost,
          purchasePrice: item.cost > 0 ? item.cost : null,
          stock: item.stock,
          lowStockAt: 5.0,
        );
        batch.add(p);
      }

      await productProvider.addProductsBatch(batch);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🎉 ${batch.length} सामान सफलतापूर्वक स्टॉक में जुड़ गए!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Error saving stock: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SafeArea(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650, maxHeight: 850),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface.withOpacity(0.4),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.playlist_add, color: AppColors.primary, size: 24),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('बल्क स्टॉक अपलोड (50-100+ आइटम्स)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Excel, CSV या होलसेल बिल से एक साथ पूरा सामान चढ़ाएं', style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Tab Selector
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                tabs: const [
                  Tab(icon: Icon(Icons.table_chart_outlined, size: 18), text: '1. Excel / CSV लिस्ट'),
                  Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: '2. होलसेल बिल / Invoice'),
                ],
              ),

              // Tab Content Area
              Expanded(
                child: _parsedItems.isEmpty
                    ? TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCsvTab(),
                          _buildBillTab(),
                        ],
                      )
                    : _buildPreviewTable(),
              ),

              // Bottom Actions
              if (_parsedItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('वापस (Reset)'),
                        onPressed: () => setState(() => _parsedItems.clear()),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check, size: 18),
                        label: Text(
                          _isSaving ? 'सेव हो रहा है...' : 'पूरा स्टॉक सेव करें (${_parsedItems.where((i) => i.selected).length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isSaving ? null : _saveAllToStock,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCsvTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Excel / CSV डेटा यहाँ पेस्ट करें:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('सैंपल लोड करें', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  setState(() => _csvTextCtrl.text = _sampleTemplate);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'कॉलम क्रम: नाम, कैटेगरी, बिक्री रेट, खरीद रेट, स्टॉक, यूनिट\n(उदा. चीनी 1kg, किराना, 45, 38, 100, kg)',
            style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _csvTextCtrl,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              hintText: 'चावल 1kg,किराना,90,75,50,kg\nचीनी 1kg,किराना,45,38,100,kg\n...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.paste, size: 16),
                label: const Text('क्लिपबोर्ड से पेस्ट करें'),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    setState(() => _csvTextCtrl.text = data!.text!);
                  }
                },
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.table_view, size: 18, color: Colors.white),
                label: const Text('सामान चेक करें (Preview)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  _parseCsvText(_csvTextCtrl.text);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('होलसेल बिल की फोटो या टेक्स्ट:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('कैमरा से फोटो लें'),
                  onPressed: () => _pickBillImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('गैलरी से बिल चुनें'),
                  onPressed: () => _pickBillImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
          if (_billImage != null) ...[
            const SizedBox(height: 10),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_billImage!, height: 140, fit: BoxFit.cover),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text('बिल के आइटम्स यहाँ लिखें या पेस्ट करें:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _billTextCtrl,
            maxLines: 6,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              hintText: 'उदा:\nFortune Oil 15L 140 30\nTata Tea 250g 80 50\nAashirvaad Atta 10kg 380 20',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.document_scanner, size: 18, color: Colors.white),
              label: const Text('बिल आइटम्स पढ़ें (Extract Items)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                _parseBillText(_billTextCtrl.text);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTable() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              Checkbox(
                value: _parsedItems.every((i) => i.selected),
                onChanged: (v) {
                  setState(() {
                    for (var i in _parsedItems) {
                      i.selected = v ?? false;
                    }
                  });
                },
              ),
              Text(
                '${_parsedItems.length} सामान मिले (सेलेक्ट: ${_parsedItems.where((i) => i.selected).length})',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade900),
              ),
              const Spacer(),
              const Text('रेट / स्टॉक एडिट कर सकते हैं ✏️', style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _parsedItems.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, idx) {
              final item = _parsedItems[idx];
              return ListTile(
                dense: true,
                leading: Checkbox(
                  value: item.selected,
                  onChanged: (v) => setState(() => item.selected = v ?? false),
                ),
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('कैटेगरी: ${item.category} | यूनिट: ${item.unit} | लागत: ${CurrencyFormatter.format(item.cost)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(item.price),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                        ),
                        Text('स्टॉक: ${item.stock}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      onPressed: () {
                        setState(() => _parsedItems.removeAt(idx));
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
