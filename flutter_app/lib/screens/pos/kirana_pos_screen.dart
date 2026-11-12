import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/fmcg_catalog_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/fmcg_item.dart';
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';
import 'widgets/barcode_scanner_dialog.dart';
import 'widgets/cart_panel.dart';

class KiranaPosScreen extends StatefulWidget {
  const KiranaPosScreen({super.key});

  @override
  State<KiranaPosScreen> createState() => _KiranaPosScreenState();
}

class _KiranaPosScreenState extends State<KiranaPosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<FmcgItem> _fmcgResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q != _searchQuery) {
        setState(() {
          _searchQuery = q;
          _fmcgResults = q.isNotEmpty ? FmcgCatalogService.instance.search(q) : [];
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openBarcodeScanner(BuildContext context) {
    SoundService.instance.playButtonClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BarcodeScannerDialog(
        onBarcodeScanned: (barcode) {
          _handleBarcodeScanned(barcode);
        },
      ),
    );
  }

  void _handleBarcodeScanned(String barcode) {
    final productProvider = context.read<ProductProvider>();
    final cart = context.read<CartProvider>();

    // 1. Check local inventory first
    final existingProd = productProvider.findByBarcode(barcode);
    if (existingProd != null) {
      cart.incrementOrAdd(existingProd);
      SoundService.instance.playProductAdd();
      _showScanToast('Added: ${existingProd.name}');
      return;
    }

    // 2. Check 2026 FMCG Catalog
    final fmcg = FmcgCatalogService.instance.findByBarcode(barcode);
    if (fmcg != null) {
      final newProd = Product(
        id: 'fmcg_${fmcg.barcode}',
        shopId: context.read<ShopProvider>().shop.id,
        name: fmcg.name,
        category: fmcg.category,
        unit: fmcg.unit,
        price: fmcg.mrp,
        purchasePrice: fmcg.defaultCostPrice,
        mrp: fmcg.mrp,
        barcode: fmcg.barcode,
      );
      cart.incrementOrAdd(newProd);
      SoundService.instance.playProductAdd();
      _showScanToast('FMCG Added: ${fmcg.name} (MRP: ₹${fmcg.mrp.toStringAsFixed(0)})');
      return;
    }

    SoundService.instance.playError();
    _showScanToast('Barcode not found: $barcode');
  }

  void _showScanToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCartSheet(BuildContext context) {
    SoundService.instance.playButtonClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.90,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Checkout & Bill Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: CartPanel(
                onCompleted: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>().shop;
    final cart = context.watch<CartProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // Kirana Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131D31) : const Color(0xFF0F2038),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Color(0xFFFBBF24), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.name.isNotEmpty ? shop.name : 'Kirana Store',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'KIRANA & FMCG',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '2026 Master Catalog Active',
                              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Cart Quick Badge
                  InkWell(
                    onTap: () => _showCartSheet(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cart.itemCount > 0 ? const Color(0xFFF59E0B) : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shopping_cart_rounded,
                            size: 16,
                            color: cart.itemCount > 0 ? const Color(0xFF0F172A) : Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${cart.itemCount}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: cart.itemCount > 0 ? const Color(0xFF0F172A) : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Barcode Scanner Action Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: InkWell(
                onTap: () => _openBarcodeScanner(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFF59E0B),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFF59E0B), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Scan Barcode (FMCG Scan)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Camera or Bluetooth scanner supported (Maggi, Salt, Soap)',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'SCAN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Search Bar for Kirana & FMCG items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search items (Maggi, Tata Salt, Parle-G, Oil)...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFF59E0B), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Quick FMCG Pills (Top Fast Movers)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                children: [
                  _buildQuickPill('🍜 Maggi ₹15', '8901058852448'),
                  _buildQuickPill('🧂 Tata Namak ₹28', '8901030381014'),
                  _buildQuickPill('🍪 Parle-G ₹5', '8901719101018'),
                  _buildQuickPill('🧈 Amul Butter ₹60', '8901262010052'),
                  _buildQuickPill('🧼 Dettol Soap ₹40', '8901396112004'),
                  _buildQuickPill('🌾 Aashirvaad Atta ₹235', '8901725181226'),
                ],
              ),
            ),

            // Scanned Cart Items / Search Results
            Expanded(
              child: _searchQuery.isNotEmpty
                  ? _buildSearchResults()
                  : (cart.lines.isEmpty ? _buildEmptyCartPlaceholder(isDark) : _buildCartItemsList(cart, isDark)),
            ),

            // Bottom Sticky Checkout Bar
            if (cart.lines.isNotEmpty || cart.isEditingBill)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: cart.isEditingBill
                      ? Border(top: BorderSide(color: Colors.amber.shade600, width: 2))
                      : null,
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (cart.isEditingBill)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '✏️ Editing Bill #${cart.editingSale!.billNo}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.amber.shade800,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          Text(
                            '${cart.itemCount} Items (${cart.totalQty.toStringAsFixed(cart.totalQty.truncateToDouble() == cart.totalQty ? 0 : 2)} Qty)',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          Text(
                            CurrencyFormatter.format(cart.total),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _showCartSheet(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cart.isEditingBill
                            ? Colors.amber.shade700
                            : const Color(0xFF0F2038),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            cart.isEditingBill ? 'Update Bill →' : 'Checkout Bill →',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPill(String title, String barcode) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        onPressed: () => _handleBarcodeScanned(barcode),
      ),
    );
  }

  Widget _buildEmptyCartPlaceholder(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.barcode_reader, size: 64, color: Color(0xFFCBD5E1)),
          SizedBox(height: 12),
          Text(
            'No items scanned yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
          SizedBox(height: 4),
          Text(
            'Scan barcodes with the scan button above\nor search products by name',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_fmcgResults.isEmpty) {
      return const Center(
        child: Text('Item not found in catalog'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: _fmcgResults.length,
      itemBuilder: (ctx, idx) {
        final item = _fmcgResults[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('MRP: ₹${item.mrp.toStringAsFixed(0)} • Barcode: ${item.barcode}', style: const TextStyle(fontSize: 11)),
            trailing: ElevatedButton(
              onPressed: () {
                _handleBarcodeScanned(item.barcode);
                _searchController.clear();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2038),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('+ Add', style: TextStyle(fontSize: 12)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartItemsList(CartProvider cart, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: cart.lines.length,
      itemBuilder: (ctx, idx) {
        final item = cart.lines[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${item.price.toStringAsFixed(0)} / ${item.unit}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                // Stepper
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFDC2626), size: 22),
                      onPressed: () => cart.setQty(item.productId, item.name, item.qty - 1),
                    ),
                    Text(
                      item.qty.toStringAsFixed(item.qty.truncateToDouble() == item.qty ? 0 : 2),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00875A), size: 22),
                      onPressed: () => cart.setQty(item.productId, item.name, item.qty + 1),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${item.total.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
