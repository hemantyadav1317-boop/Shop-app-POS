import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/receipt_print_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/payment_qr_helper.dart';
import '../../data/models/sale.dart';
import '../../providers/cart_provider.dart';
import '../../providers/customer_provider.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../core/services/sound_service.dart';
import '../pos/widgets/bill_receipt_card.dart';
import '../../core/services/ai_quote_service.dart';

class BillsScreen extends StatefulWidget {
  final VoidCallback? onSwitchToBilling;

  const BillsScreen({super.key, this.onSwitchToBilling});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  List<Sale> _sales = [];
  bool _isLoading = true;
  String _filter = 'all'; // 'all', 'credit', 'online', 'cash'

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    final shop = context.read<ShopProvider>().shop;
    final list = await SupabaseService.instance.getSales(shop.id);
    setState(() {
      _sales = list;
      _isLoading = false;
    });
  }

  List<Sale> get _filteredSales {
    final seenIds = <String>{};
    final unique = <Sale>[];
    for (final s in _sales) {
      if (!seenIds.contains(s.id)) {
        seenIds.add(s.id);
        unique.add(s);
      }
    }
    if (_filter == 'credit') {
      return unique.where((s) => s.due > 0).toList();
    } else if (_filter == 'online') {
      return unique.where((s) => s.paymentMode == 'online').toList();
    } else if (_filter == 'cash') {
      return unique.where((s) => s.paymentMode == 'cash').toList();
    }
    return unique;
  }

  void _showBillDetails(Sale sale) {
    final shop = context.read<ShopProvider>().shop;
    final userEmail = SupabaseService.instance.client?.auth.currentUser?.email;
    final dateFormat = DateFormat('dd-MM-yyyy h:mm a');
    final screenshotController = ScreenshotController();
    Sale currentSale = sale;
    bool isVerifying = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Text(
                                  'Invoice #${currentSale.billNo}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                                if (currentSale.isEdited)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.amber.shade600),
                                    ),
                                    child: Text(
                                      currentSale.editedTagText,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              currentSale.isFullyPaidAndVerified
                                  ? 'Status: Paid ✓'
                                  : (currentSale.effectiveUpiPayable > 0.009
                                      ? 'Status: UPI Pending (₹${currentSale.effectiveUpiPayable.toStringAsFixed(0)})'
                                      : 'Status: Due / उधार (₹${currentSale.due.toStringAsFixed(0)})'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: currentSale.isFullyPaidAndVerified ? const Color(0xFF00875A) : Colors.amber.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!context.read<AuthProvider>().isStaffSession) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 24),
                          tooltip: 'Cart में बिल एडिट करें (Edit in Cart)',
                          onPressed: () {
                            Navigator.pop(ctx);
                            _editBillInCart(currentSale);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                          tooltip: 'बिल डिलीट करें (Delete Bill)',
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmDeleteBill(currentSale);
                          },
                        ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                if (currentSale.effectiveUpiPayable > 0.009)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.qr_code_scanner, size: 18, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'UPI बकाया: ₹${currentSale.effectiveUpiPayable.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00875A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          icon: isVerifying
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.verified_outlined, size: 15),
                          label: const Text('Verify Paid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: isVerifying
                              ? null
                              : () async {
                                  setModalState(() => isVerifying = true);
                                  final pendingUpi = currentSale.effectiveUpiPayable;
                                  final newPaid = PaymentQrHelper.round2(
                                    (currentSale.paid + pendingUpi).clamp(0.0, currentSale.total),
                                  );
                                  final newDue = PaymentQrHelper.round2(
                                    (currentSale.total - newPaid) > 0 ? (currentSale.total - newPaid) : 0.0,
                                  );
                                  final verifiedSale = currentSale.copyWith(
                                    paid: newPaid,
                                    due: newDue,
                                    upiPaid: PaymentQrHelper.round2(currentSale.upiPaid + pendingUpi),
                                    upiPayable: 0.0,
                                    onlineVerified: true,
                                    verificationSource: 'cashier_verified',
                                    paymentStatus: newDue <= 0.009 ? 'completed' : 'pending',
                                  );
                                  await SupabaseService.instance.updateSale(verifiedSale);
                                  SoundService.instance.playSuccess();
                                  setModalState(() {
                                    currentSale = verifiedSale;
                                    isVerifying = false;
                                  });
                                  _loadSales();
                                },
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Screenshot(
                      controller: screenshotController,
                      child: BillReceiptCard(
                        shopName: shop.name,
                        shopAddress: shop.address,
                        shopPhone: shop.phone,
                        shopEmail: (userEmail != null && userEmail.isNotEmpty) ? userEmail : null,
                        gstin: shop.gstin,
                        billNo: '${currentSale.billNo}',
                        dateString: dateFormat.format(currentSale.createdAt.toLocal()),
                        customerName: currentSale.customerName,
                        customerPhone: currentSale.customerPhone,
                        items: currentSale.items,
                        subtotal: currentSale.subtotal,
                        discount: currentSale.discount,
                        total: currentSale.total,
                        paid: currentSale.paid,
                        due: currentSale.due,
                        paymentMode: currentSale.paymentMode,
                        paymentStatus: currentSale.paymentStatus,
                        upiPayableAmount: currentSale.effectiveUpiPayable,
                        onlineVerified: currentSale.onlineVerified,
                        cashPaid: currentSale.cashPaid,
                        upiPaid: currentSale.upiPaid,
                        creditAmount: currentSale.creditAmount,
                        footerMessage: shop.receiptFooter,
                        quoteLine1: AiQuoteService.getQuoteForBillNo(currentSale.billNo).line1,
                        quoteLine2: AiQuoteService.getQuoteForBillNo(currentSale.billNo).line2,
                        upiId: shop.upiId,
                        upiPayeeName: shop.upiPayeeName,
                        googleReviewUrl: shop.googleReviewUrl,
                        editCount: currentSale.editCount,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  color: Colors.grey.shade50,
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.pop(ctx),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.reply, color: Color(0xFF2563EB), size: 22),
                                SizedBox(height: 3),
                                Text('Back', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            try {
                              final imageBytes = await screenshotController.capture(pixelRatio: 2.0);
                              await ReceiptPrintService.shareReceipt(sale: currentSale, shop: shop, imageBytes: imageBytes);
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('शेयर एरर: $e')));
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.share, color: Color(0xFF16A34A), size: 22),
                                SizedBox(height: 3),
                                Text('Share Bill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            try {
                              final file = await ReceiptPrintService.downloadReceiptPdf(
                                sale: currentSale,
                                shop: shop,
                                shopEmail: (userEmail != null && userEmail.isNotEmpty) ? userEmail : null,
                              );
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF00875A),
                                    content: Text('PDF सेव: ${file.uri.pathSegments.last}'),
                                    action: SnackBarAction(
                                      label: 'Save / Open',
                                      textColor: Colors.white,
                                      onPressed: () {
                                        ReceiptPrintService.exportReceiptPdf(
                                          sale: currentSale,
                                          shop: shop,
                                          shopEmail: (userEmail != null && userEmail.isNotEmpty) ? userEmail : null,
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(backgroundColor: AppColors.error, content: Text('डाउनलोड एरर: $e')));
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.download_rounded, color: Color(0xFF0284C7), size: 22),
                                SizedBox(height: 3),
                                Text('Download', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            try {
                              final imageBytes = await screenshotController.capture(pixelRatio: 2.0);
                              await ReceiptPrintService.printReceipt(sale: currentSale, shop: shop, imageBytes: imageBytes);
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(backgroundColor: AppColors.error, content: Text('प्रिंट एरर: $e')));
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.print, color: Color(0xFF2563EB), size: 22),
                                SizedBox(height: 3),
                                Text('Print Bill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              ],
                            ),
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
      ),
    );
  }

  Future<void> _editBillInCart(Sale sale) async {
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('सुरक्षा नियम: केवल दुकान मालिक बिल एडिट कर सकते हैं।'),
        ),
      );
      return;
    }

    final cart = context.read<CartProvider>();
    final customerProv = context.read<CustomerProvider>();

    // Protect any active new cart items before replacing them with the bill
    if (cart.lines.isNotEmpty && cart.editingSale?.id != sale.id) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (confirmCtx) => AlertDialog(
          title: Text('Bill #${sale.billNo} Cart में लोड करें?'),
          content: const Text(
            'आपके Cart में अभी कुछ आइटम हैं। क्या उन्हें हटाकर इस पुराने बिल को एडिट करने के लिए लोड करें?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(confirmCtx, false),
              child: const Text('रद्द करें'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(confirmCtx, true),
              child: const Text('हाँ, लोड करें'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }

    final matchedCustomer = sale.customerId == null
        ? null
        : customerProv.customers
            .where((c) => c.id == sale.customerId)
            .firstOrNull;

    cart.startEditingSale(sale, resolvedCustomer: matchedCustomer);
    SoundService.instance.playButtonClick();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.amber.shade800,
        duration: const Duration(seconds: 3),
        content: Text(
          'बिल #${sale.billNo} Cart में खुल गया है — बदलाव करके Checkout से सेव करें।',
        ),
      ),
    );
    widget.onSwitchToBilling?.call();
  }

  void _confirmDeleteBill(Sale sale) {
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('सुरक्षा नियम: केवल दुकान मालिक बिल डिलीट कर सकते हैं।'),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (delCtx) => AlertDialog(
        title: const Text('बिल डिलीट करें?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('क्या आप वाकई बिल #${sale.billNo} (${CurrencyFormatter.format(sale.total)}) को डिलीट/रद्द करना चाहते हैं?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(delCtx),
            child: const Text('रद्द करें (Cancel)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              SoundService.instance.playDelete();
              Navigator.pop(delCtx);
              await SupabaseService.instance.deleteSale(sale.id);
              _loadSales();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: AppColors.error, content: Text('बिल डिलीट कर दिया गया।')),
                );
              }
            },
            child: const Text('हाँ, डिलीट करें'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('बिल हिस्ट्री / Bills History', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('all', 'All Bills (${_sales.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('cash', 'Cash'),
                const SizedBox(width: 8),
                _buildFilterChip('online', 'UPI Online'),
                const SizedBox(width: 8),
                _buildFilterChip('credit', 'उधार (Credit)'),
              ],
            ),
          ),

          // Sales List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadSales,
                    child: _filteredSales.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.lightTextSecondary),
                                    SizedBox(height: 8),
                                    Text('कोई बिल नहीं मिला (No bills yet)', style: TextStyle(color: AppColors.lightTextSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredSales.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                          final sale = _filteredSales[i];

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: sale.due > 0 ? AppColors.error.withOpacity(0.15) : AppColors.primarySurface,
                                child: Icon(
                                  sale.due > 0 ? Icons.book : Icons.receipt,
                                  color: sale.due > 0 ? AppColors.error : AppColors.primary,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text('#${sale.billNo}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (sale.isEdited) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.amber.shade600, width: 0.8),
                                      ),
                                      child: Text(
                                        sale.editedTagText,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sale.customerName ?? 'Walk-in Customer',
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${sale.items.length} items · ${dateFormat.format(sale.createdAt.toLocal())} · ${sale.paymentMode.toUpperCase()}',
                                style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormatter.format(sale.total),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      if (sale.effectiveUpiPayable > 0.009)
                                        Text(
                                          'UPI Pending: ${CurrencyFormatter.format(sale.effectiveUpiPayable)}',
                                          style: TextStyle(color: Colors.amber.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                                        )
                                      else if (sale.due > 0)
                                        Text(
                                          'Due: ${CurrencyFormatter.format(sale.due)}',
                                          style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                    ],
                                  ),
                                  if (!context.read<AuthProvider>().isStaffSession) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
                                      tooltip: 'Cart में एडिट करें',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      onPressed: () => _editBillInCart(sale),
                                    ),
                                  ],
                                ],
                              ),
                              onTap: () => _showBillDetails(sale),
                            ),
                          );
                        },
                      ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primarySurface,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.lightTextSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() => _filter = key);
      },
    );
  }
}
