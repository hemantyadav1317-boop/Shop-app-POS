import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/services/receipt_print_service.dart';
import '../../../../core/services/printer_settings_service.dart';
import '../../../../core/services/bluetooth_printer_service.dart';
import '../../../../core/services/payment_notification_service.dart';
import '../../../../core/services/time_sync_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/payment_qr_helper.dart';
import '../../../../data/models/sale.dart';
import '../../../../data/models/shop.dart';
import '../../../../data/models/payment_transaction.dart';
import '../../../../data/services/local_db_service.dart';
import '../../../../data/services/phonepe_service.dart';
import '../../../../data/services/supabase_service.dart';
import '../../../../data/services/upi_service.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../providers/customer_provider.dart';
import '../../../../providers/shop_provider.dart';
import '../../../../providers/product_provider.dart';
import 'bill_receipt_card.dart';
import '../../../../core/services/ai_quote_service.dart';

class PaymentDialog extends StatefulWidget {
  final VoidCallback onSaleCompleted;

  const PaymentDialog({super.key, required this.onSaleCompleted});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _paymentMode = 'cash'; // 'cash', 'online', 'credit', 'split'
  late TextEditingController _paidController;
  late TextEditingController _upiController;
  late TextEditingController _creditController;
  bool _isSaving = false;
  Sale? _completedSale;
  bool _onlinePaymentVerified = false;
  late int _billNo;
  late final String _clientRef = const Uuid().v4();
  final ScreenshotController _screenshotController = ScreenshotController();
  BillQuote? _currentBillQuote;

  PaymentTransaction? _activePhonePeTx;
  bool _isCreatingPhonePeOrder = false;
  StreamSubscription<PaymentTransaction>? _phonePeSub;
  StreamSubscription<DetectedPayment>? _paymentNotifSub;
  String? _detectedPaymentApp;
  String? _detectedUtr;
  Timer? _phonePeTimer;
  Timer? _qrDebounceTimer;
  int _phonePeRemainingSeconds = 180;
  late final String _upiSessionRef;

  @override
  void initState() {
    super.initState();
    // Unique alphanumeric checkout reference for Google Pay & NPCI compliance
    _upiSessionRef = 'T${(TimeSyncService.instance.nowUtc().millisecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';
    final cart = context.read<CartProvider>();
    final payableTotal = _roundInfo(cart).roundedTotal;
    final editing = cart.editingSale;
    if (editing != null) {
      _billNo = editing.billNo;
      _paymentMode = ['cash', 'online', 'credit', 'split'].contains(editing.paymentMode)
          ? editing.paymentMode
          : 'cash';
      _onlinePaymentVerified = editing.onlineVerified;

      if (_paymentMode == 'cash') {
        _paidController = TextEditingController(text: payableTotal.toStringAsFixed(2));
        _upiController = TextEditingController(text: '0.00');
        _creditController = TextEditingController(text: '0.00');
      } else if (_paymentMode == 'online') {
        _paidController = TextEditingController(text: '0.00');
        _upiController = TextEditingController(text: payableTotal.toStringAsFixed(2));
        _creditController = TextEditingController(text: '0.00');
      } else if (_paymentMode == 'credit') {
        _paidController = TextEditingController(text: '0.00');
        _upiController = TextEditingController(text: '0.00');
        _creditController = TextEditingController(text: payableTotal.toStringAsFixed(2));
      } else {
        final initialCash = editing.cashPaid.clamp(0.0, payableTotal);
        final initialCredit = editing.creditAmount.clamp(0.0, math.max(0.0, payableTotal - initialCash));
        final remUpi = math.max(0.0, payableTotal - initialCash - initialCredit);
        _paidController = TextEditingController(text: initialCash.toStringAsFixed(2));
        _upiController = TextEditingController(text: remUpi.toStringAsFixed(2));
        _creditController = TextEditingController(text: initialCredit.toStringAsFixed(2));
      }
    } else {
      _paidController = TextEditingController(text: payableTotal.toStringAsFixed(2));
      _upiController = TextEditingController(text: '0.00');
      _creditController = TextEditingController(text: '0.00');
      _billNo = 1;
      _initBillNo();
    }
    _loadQuote();

    if (_paymentMode == 'online' || _paymentMode == 'split') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Auto-verify PhonePe countdown timer disabled per user request
        _initPaymentNotificationListener();
      });
    }
  }

  void _initBillNo() async {
    final cart = context.read<CartProvider>();
    if (cart.editingSale != null) return;
    final shop = context.read<ShopProvider>().shop;
    final localPeek = await LocalDbService.instance.peekNextBillNo(shop.id);
    if (mounted && _completedSale == null) {
      setState(() => _billNo = localPeek);
    }
    // Also check cloud counter floor so multi-device billing always previews & allocates sequentially
    await SupabaseService.instance.syncCloudBillCounterFloor(shop.id);
    final syncedPeek = await LocalDbService.instance.peekNextBillNo(shop.id);
    if (mounted && _completedSale == null && syncedPeek > _billNo) {
      setState(() => _billNo = syncedPeek);
    }
  }

  void _initPhonePePayment() async {
    final shop = context.read<ShopProvider>().shop;
    if (!shop.phonePeEnabled) return;

    final cart = context.read<CartProvider>();
    final upiAmount = _paymentMode == 'split'
        ? (double.tryParse(_upiController.text.trim()) ?? 0.0)
        : _roundInfo(cart).roundedTotal;

    if (upiAmount <= 0.009) return;

    _phonePeSub?.cancel();
    _phonePeTimer?.cancel();

    // ⚡ INSTANT QR: Pre-populate fallback transaction so QR code renders on Frame 1 (0ms)
    final instantFallbackTx = PhonePeService.instance.buildFallbackTransaction(
      shop: shop,
      billNo: _billNo,
      amount: upiAmount,
      clientRef: _clientRef,
      paymentMode: _paymentMode,
    );

    setState(() {
      _activePhonePeTx = instantFallbackTx;
      _isCreatingPhonePeOrder = true;
      _phonePeRemainingSeconds = 180;
    });

    final tx = await PhonePeService.instance.createPaymentOrder(
      shop: shop,
      billNo: _billNo,
      amount: upiAmount,
      clientRef: _clientRef,
      paymentMode: _paymentMode,
    );

    if (!mounted) return;

    setState(() {
      _activePhonePeTx = tx;
      _isCreatingPhonePeOrder = false;
    });

    // Start 180-second countdown
    _phonePeTimer = Timer.periodic(const Duration(seconds: 1), (tm) {
      if (!mounted) {
        tm.cancel();
        return;
      }
      setState(() {
        if (_phonePeRemainingSeconds > 0) {
          _phonePeRemainingSeconds--;
        } else {
          tm.cancel();
        }
      });
    });

    // Listen to Realtime status updates with polling fallback
    _phonePeSub = PhonePeService.instance.listenToTransactionStatus(
      merchantTxId: tx.merchantTransactionId,
      onStatusUpdated: (updatedTx) {
        if (!mounted) return;
        setState(() {
          _activePhonePeTx = updatedTx;
        });

        if (updatedTx.isSuccess && !_onlinePaymentVerified) {
          _phonePeTimer?.cancel();
          setState(() {
            _onlinePaymentVerified = true;
          });
          SoundService.instance.playSuccess();
          // Auto-complete bill after brief 600ms celebratory feedback
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted && _completedSale == null && !_isSaving) {
              _processCheckout();
            }
          });
        }
      },
    );
  }

  void _initPaymentNotificationListener() {
    _paymentNotifSub?.cancel();
    if (_onlinePaymentVerified || _completedSale != null || _isSaving) return;

    final cart = context.read<CartProvider>();
    final upiAmount = _paymentMode == 'split'
        ? (double.tryParse(_upiController.text.trim()) ?? 0.0)
        : _roundInfo(cart).roundedTotal;

    if (upiAmount <= 0.009) return;

    // 1. Instant check: was a payment for this exact amount received in the last 60 seconds?
    final existingMatch = PaymentNotificationService.instance.consumeMatchingPayment(upiAmount);
    if (existingMatch != null) {
      _onPaymentVerifiedAutomatically(existingMatch);
      return;
    }

    // 2. Stream check: listen for incoming payment notifications
    _paymentNotifSub = PaymentNotificationService.instance.paymentStream.listen((detected) {
      if (!mounted || _onlinePaymentVerified || _completedSale != null || _isSaving) return;
      if (!detected.isConsumed && (detected.amount - upiAmount).abs() <= 0.05) {
        detected.isConsumed = true;
        _onPaymentVerifiedAutomatically(detected);
      }
    });
  }

  void _onPaymentVerifiedAutomatically(DetectedPayment detected) {
    _phonePeTimer?.cancel();
    _paymentNotifSub?.cancel();
    setState(() {
      _onlinePaymentVerified = true;
      _detectedPaymentApp = detected.appName;
      _detectedUtr = detected.utr;
    });
    SoundService.instance.playSuccess();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF00875A),
        duration: const Duration(seconds: 2),
        content: Text('✓ ${detected.appName} से ₹${detected.amount.toStringAsFixed(2)} प्राप्त हुए! रसीद प्रिंट हो रही है...'),
      ),
    );

    // Instant celebratory feedback -> auto checkout & instant auto-print!
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _completedSale == null && !_isSaving) {
        _processCheckout();
      }
    });
  }

  void _loadQuote() async {
    final quote = await AiQuoteService.getUniqueQuoteForBill();
    if (mounted) {
      setState(() {
        _currentBillQuote = quote;
      });
    }
  }

  @override
  void dispose() {
    _phonePeSub?.cancel();
    _phonePeTimer?.cancel();
    _qrDebounceTimer?.cancel();
    _paymentNotifSub?.cancel();
    _paidController.dispose();
    _upiController.dispose();
    _creditController.dispose();
    super.dispose();
  }

  RoundOffResult _roundInfo(CartProvider cart) {
    final settings = PrinterSettingsService.instance;
    return PaymentQrHelper.applyRoundOff(
      cart.total,
      enabled: settings.autoRoundOffEnabled,
      mode: settings.roundOffMode,
    );
  }

  String _fmtAmt(double val) {
    final rounded = PaymentQrHelper.round2(math.max(0.0, val));
    return rounded % 1 == 0 ? rounded.toInt().toString() : rounded.toStringAsFixed(2);
  }

  void _onCashChanged(String val, CartProvider cart) {
    if (_paymentMode != 'split') {
      setState(() {});
      return;
    }
    _onlinePaymentVerified = false;
    final payableTotal = _roundInfo(cart).roundedTotal;
    final cash = (double.tryParse(val.trim()) ?? 0.0).clamp(0.0, payableTotal);
    final currentCredit = double.tryParse(_creditController.text.trim()) ?? 0.0;
    if (currentCredit > 0.009) {
      final safeCredit = math.min(currentCredit, PaymentQrHelper.round2(math.max(0.0, payableTotal - cash)));
      final remUpi = PaymentQrHelper.round2(math.max(0.0, payableTotal - cash - safeCredit));
      _upiController.text = _fmtAmt(remUpi);
      _creditController.text = _fmtAmt(safeCredit);
    } else {
      final remUpi = PaymentQrHelper.round2(math.max(0.0, payableTotal - cash));
      _upiController.text = _fmtAmt(remUpi);
      _creditController.text = '0';
    }
    setState(() {});
    _triggerUpiQrDebounced();
  }

  void _onUpiChanged(String val, CartProvider cart) {
    if (_paymentMode != 'split') {
      setState(() {});
      return;
    }
    _onlinePaymentVerified = false;
    final payableTotal = _roundInfo(cart).roundedTotal;
    final upi = (double.tryParse(val.trim()) ?? 0.0).clamp(0.0, payableTotal);
    var cash = (double.tryParse(_paidController.text.trim()) ?? 0.0).clamp(0.0, payableTotal);
    if (cash + upi > payableTotal) {
      cash = PaymentQrHelper.round2(math.max(0.0, payableTotal - upi));
      _paidController.text = _fmtAmt(cash);
    }
    final remCredit = PaymentQrHelper.round2(math.max(0.0, payableTotal - cash - upi));
    _creditController.text = _fmtAmt(remCredit);
    setState(() {});
    _triggerUpiQrDebounced();
  }

  void _onCreditChanged(String val, CartProvider cart) {
    if (_paymentMode != 'split') {
      setState(() {});
      return;
    }
    _onlinePaymentVerified = false;
    final payableTotal = _roundInfo(cart).roundedTotal;
    final credit = (double.tryParse(val.trim()) ?? 0.0).clamp(0.0, payableTotal);
    var cash = (double.tryParse(_paidController.text.trim()) ?? 0.0).clamp(0.0, payableTotal);
    if (cash + credit > payableTotal) {
      cash = PaymentQrHelper.round2(math.max(0.0, payableTotal - credit));
      _paidController.text = _fmtAmt(cash);
    }
    final remUpi = PaymentQrHelper.round2(math.max(0.0, payableTotal - cash - credit));
    _upiController.text = _fmtAmt(remUpi);
    setState(() {});
    _triggerUpiQrDebounced();
  }

  void _triggerUpiQrDebounced() {
    _qrDebounceTimer?.cancel();
  }

  void _onModeChanged(String mode) {
    SoundService.instance.playClick();
    final cart = context.read<CartProvider>();
    final payableTotal = _roundInfo(cart).roundedTotal;
    setState(() {
      _paymentMode = mode;
      _onlinePaymentVerified = false;
      if (mode == 'cash') {
        _paidController.text = payableTotal.toStringAsFixed(2);
        _upiController.text = '0.00';
        _creditController.text = '0.00';
      } else if (mode == 'online') {
        _paidController.text = '0.00';
        _upiController.text = payableTotal.toStringAsFixed(2);
        _creditController.text = '0.00';
      } else if (mode == 'credit') {
        _paidController.text = '0.00';
        _upiController.text = '0.00';
        _creditController.text = payableTotal.toStringAsFixed(2);
      } else if (mode == 'split') {
        final halfCash = PaymentQrHelper.round2(payableTotal / 2);
        final remUpi = PaymentQrHelper.round2(math.max(0.0, payableTotal - halfCash));
        _paidController.text = halfCash.toStringAsFixed(2);
        _upiController.text = remUpi.toStringAsFixed(2);
        _creditController.text = '0.00';
      }
    });

    if (mode == 'online' || mode == 'split') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Auto-verify PhonePe countdown timer disabled per user request
        _initPaymentNotificationListener();
      });
    } else {
      _phonePeSub?.cancel();
      _phonePeTimer?.cancel();
      _paymentNotifSub?.cancel();
      _activePhonePeTx = null;
    }
  }

  Future<void> _pickCustomerForCredit(CartProvider cart) async {
    final custProv = context.read<CustomerProvider>();
    final shop = context.read<ShopProvider>().shop;
    if (custProv.customers.isEmpty && shop.id.isNotEmpty) {
      await custProv.loadCustomers(shop.id);
    }
    if (!mounted) return;
    String query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = custProv.customers.where((c) {
            if (query.trim().isEmpty) return true;
            final q = query.trim().toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                (c.phone ?? '').toLowerCase().contains(q);
          }).toList();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 14,
              ),
              child: SizedBox(
                height: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ग्राहक चुनें (Khata Account)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'नाम या मोबाइल नंबर से खोजें...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                      ),
                      onChanged: (v) => setSheetState(() => query = v),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('कोई ग्राहक नहीं मिला'))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (_, idx) {
                                final c = filtered[idx];
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                    child: Text(
                                      c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                  subtitle: Text(
                                    '${c.phone ?? 'No phone'} · बकाया: ₹${c.balance.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                  onTap: () {
                                    cart.setCustomer(c);
                                    Navigator.pop(sheetCtx);
                                    if (mounted) setState(() {});
                                  },
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
      ),
    );
  }

  PaymentBreakdown _computeBreakdown(CartProvider cart) {
    final cashInput = double.tryParse(_paidController.text.trim()) ?? 0.0;
    final upiInput = double.tryParse(_upiController.text.trim()) ?? 0.0;
    final creditInput = double.tryParse(_creditController.text.trim()) ?? 0.0;
    final shop = context.read<ShopProvider>().shop;
    final payableTotal = _roundInfo(cart).roundedTotal;
    return PaymentQrHelper.calculateBreakdown(
      total: payableTotal,
      paymentMode: _paymentMode,
      cashAmount: cashInput,
      upiAmount: upiInput,
      creditAmount: _paymentMode == 'split' ? creditInput : null,
      onlineVerified: _onlinePaymentVerified,
      verificationSource: _paymentMode == 'online' || (_paymentMode == 'split' && upiInput > 0)
          ? (_onlinePaymentVerified
              ? (_detectedPaymentApp != null
                  ? 'notification_${_detectedPaymentApp!.toLowerCase().replaceAll(' ', '_')}'
                  : (shop.phonePeEnabled ? 'phonepe_auto_verified' : 'cashier_verified'))
              : 'unverified')
          : null,
    );
  }

  Sale _buildCurrentSale(Shop shop, CartProvider cart) {
    if (_completedSale != null) return _completedSale!;

    final breakdown = _computeBreakdown(cart);
    final roundRes = _roundInfo(cart);
    final editing = cart.editingSale;
    final nowLocal = TimeSyncService.instance.nowLocal();

    return Sale(
      id: editing?.id ?? _clientRef,
      shopId: shop.id,
      billNo: _billNo,
      customerId: cart.customer?.id,
      customerName: cart.customer?.name,
      customerPhone: cart.customer?.phone,
      items: List.from(cart.lines),
      subtotal: cart.subtotal,
      discount: cart.discount,
      roundOff: roundRes.roundOff,
      total: roundRes.roundedTotal,
      paid: breakdown.paid,
      due: breakdown.due,
      paymentMode: _paymentMode,
      paymentStatus: breakdown.paymentStatus,
      cashPaid: breakdown.cashPaid,
      upiPaid: breakdown.upiPaid,
      upiPayable: breakdown.upiPayable,
      creditAmount: breakdown.creditAmount,
      onlineVerified: breakdown.onlineVerified,
      verificationSource: breakdown.verificationSource,
      note: editing?.note,
      createdAt: editing?.createdAt ?? nowLocal,
      clientRef: editing?.clientRef ?? _clientRef,
      editCount: editing != null ? editing.editCount + 1 : 0,
      lastEditedAt: editing != null ? nowLocal : null,
    );
  }

  Future<void> _processCheckout() async {
    final cart = context.read<CartProvider>();
    final shop = context.read<ShopProvider>().shop;
    final productProv = context.read<ProductProvider>();
    final editing = cart.editingSale;

    if (cart.lines.isEmpty) return;

    // Validate stock if negative stock is disallowed by shop owner
    if (!shop.allowNegativeStock) {
      for (final item in cart.lines) {
        if (item.productId != null) {
          final prod = productProv.getProductById(item.productId);
          final oldQtyInEditedBill = editing == null
              ? 0.0
              : editing.items
                  .where((e) => e.productId == item.productId)
                  .fold<double>(0.0, (s, e) => s + e.qty);
          if (prod != null && (prod.stock + oldQtyInEditedBill) < item.qty) {
            final available = prod.stock + oldQtyInEditedBill;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 4),
                content: Text(
                  available <= 0
                      ? '⚠️ \'${item.name}\' का स्टॉक खत्म है (0 उपलब्ध)! बिल नहीं काटा जा सकता।'
                      : '⚠️ \'${item.name}\' का स्टॉक केवल $available ${item.unit} उपलब्ध है (मांग: ${item.qty})!',
                ),
              ),
            );
            return;
          }
        }
      }
    }

    final isStaff = context.read<AuthProvider>().isStaffSession;
    if (isStaff && (_paymentMode == 'credit' || _paymentMode == 'split')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('सुरक्षा नियम: स्टाफ को उधार (Credit) देने की अनुमति नहीं है। केवल नकद या ऑनलाइन भुगतान लें।'),
        ),
      );
      return;
    }

    if (_paymentMode == 'split') {
      final splitErr = PaymentQrHelper.validateSplitAmounts(
        total: _roundInfo(cart).roundedTotal,
        cashAmount: double.tryParse(_paidController.text.trim()) ?? 0.0,
        upiAmount: double.tryParse(_upiController.text.trim()) ?? 0.0,
        creditAmount: double.tryParse(_creditController.text.trim()) ?? 0.0,
      );
      if (splitErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text(splitErr)),
        );
        return;
      }
    }

    final breakdown = _computeBreakdown(cart);

    if (_paymentMode == 'credit' && cart.customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('उधार बिक्री के लिए ग्राहक (Customer) चुनें!'),
        ),
      );
      return;
    }

    if (_paymentMode == 'split' && breakdown.creditAmount > 0.009 && cart.customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Split में उधार (Credit) राशि रखने के लिए ग्राहक (Customer) चुनें या Cash + UPI पूरा करें!'),
        ),
      );
      return;
    }

    final dueAmount = breakdown.due;

    // 🛑 Check Customer Credit Limit
    if ((_paymentMode == 'credit' || breakdown.creditAmount > 0.009) && cart.customer != null) {
      final creditPortion = _paymentMode == 'credit' ? breakdown.due : breakdown.creditAmount;
      final cust = cart.customer!;
      if (cust.creditLimit > 0 && (cust.balance + creditPortion) > cust.creditLimit) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (alertCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text('क्रेडिट लिमिट अलर्ट!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ग्राहक: ${cust.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('तय क्रेडिट लिमिट:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('₹ ${cust.creditLimit.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('वर्तमान बकाया:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('₹ ${cust.balance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFDC2626))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('इस बिल का उधार:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('₹ ${dueAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('नया कुल बकाया:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('₹ ${(cust.balance + dueAmount).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFDC2626))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'यह बिल ग्राहक की तय सीमा से ₹${((cust.balance + dueAmount) - cust.creditLimit).toStringAsFixed(2)} अधिक हो जाएगा। क्या आप फिर भी उधार देना चाहते हैं?',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(alertCtx, false),
                child: const Text('रद्द करें (Cancel)'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                onPressed: () => Navigator.pop(alertCtx, true),
                child: const Text('हाँ, उधार दें', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    final custProv = context.read<CustomerProvider>();
    setState(() {
      _isSaving = true;
    });

    try {
      final roundRes = _roundInfo(cart);
      final calibratedNowLocal = TimeSyncService.instance.nowLocal();
      final Sale saved;
      if (editing != null) {
        final updatedSale = Sale(
          id: editing.id,
          shopId: shop.id,
          billNo: editing.billNo,
          customerId: cart.customer?.id,
          customerName: cart.customer?.name,
          customerPhone: cart.customer?.phone,
          items: List.from(cart.lines),
          subtotal: cart.subtotal,
          discount: cart.discount,
          roundOff: roundRes.roundOff,
          total: roundRes.roundedTotal,
          paid: breakdown.paid,
          due: breakdown.due,
          paymentMode: _paymentMode,
          paymentStatus: breakdown.paymentStatus,
          cashPaid: breakdown.cashPaid,
          upiPaid: breakdown.upiPaid,
          upiPayable: breakdown.upiPayable,
          creditAmount: breakdown.creditAmount,
          onlineVerified: breakdown.onlineVerified,
          verificationSource: breakdown.verificationSource,
          note: editing.note,
          createdAt: editing.createdAt,
          clientRef: editing.clientRef ?? _clientRef,
          editCount: editing.editCount + 1,
          lastEditedAt: calibratedNowLocal,
        );
        saved = await SupabaseService.instance.updateSale(
          updatedSale,
          previousSale: editing,
        );
        productProv.applyStockDiff(editing.items, saved.items);
        if (saved.due != editing.due || saved.customerId != editing.customerId) {
          custProv.loadCustomers(shop.id);
        }
      } else {
        // Quick 700ms multi-device check before allocating bill number so concurrent phones don't collide
        try {
          await SupabaseService.instance
              .syncCloudBillCounterFloor(shop.id)
              .timeout(const Duration(milliseconds: 700));
        } catch (_) {}
        final confirmedBillNo = await LocalDbService.instance.getNextBillNo(shop.id);
        _billNo = confirmedBillNo;
        final sale = Sale(
          id: const Uuid().v4(),
          shopId: shop.id,
          billNo: confirmedBillNo,
          customerId: cart.customer?.id,
          customerName: cart.customer?.name,
          customerPhone: cart.customer?.phone,
          items: List.from(cart.lines),
          subtotal: cart.subtotal,
          discount: cart.discount,
          roundOff: roundRes.roundOff,
          total: roundRes.roundedTotal,
          paid: breakdown.paid,
          due: breakdown.due,
          paymentMode: _paymentMode,
          paymentStatus: breakdown.paymentStatus,
          cashPaid: breakdown.cashPaid,
          upiPaid: breakdown.upiPaid,
          upiPayable: breakdown.upiPayable,
          creditAmount: breakdown.creditAmount,
          onlineVerified: breakdown.onlineVerified,
          verificationSource: breakdown.verificationSource,
          createdAt: TimeSyncService.instance.nowLocal(),
          clientRef: _clientRef,
        );

        saved = await SupabaseService.instance.createSale(sale);
        // Immediately deduct in UI memory so stock decreases right away on screen
        productProv.deductStock(sale.items);
        // Immediately add Credit / Split Credit to Khata in CustomerProvider without cloud race overwrite
        final double khataCredit = saved.paymentMode == 'split'
            ? saved.creditAmount
            : saved.due;
        if (khataCredit > 0.009 && saved.customerId != null) {
          custProv.applyLocalCredit(saved.customerId!, khataCredit);
        }
      }

      // Trigger quiet phone auto-backup in background without blocking checkout
      unawaited(Future(() {
        BackupService.runAutoBackupIfEnabled(
          shop: shop,
          categoriesConfig: productProv.exportCategoriesConfig(),
        );
      }));

      setState(() {
        _completedSale = saved;
        _isSaving = false;
      });

      SoundService.instance.playSuccess();

      cart.clear();

      // Instant Auto-Print on Payment completion
      if (PrinterSettingsService.instance.autoPrintOnPayment) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            final isConnected = await BluetoothPrinterService.isConnected();
            final savedMac = await BluetoothPrinterService.getSavedPrinterMac();
            if (isConnected || (savedMac != null && savedMac.isNotEmpty)) {
              // Give 250ms for the bill receipt widget to layout and render
              await Future.delayed(const Duration(milliseconds: 250));
              final imageBytes = await _screenshotController.capture(pixelRatio: 2.0).timeout(
                const Duration(milliseconds: 2000),
                onTimeout: () => null,
              );
              await ReceiptPrintService.printReceipt(
                sale: saved,
                shop: shop,
                imageBytes: imageBytes,
              );
            }
          } catch (printErr) {
            debugPrint('[AutoPrint] Non-fatal auto-print error: $printErr');
          }
        });
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Error saving sale: $e')),
        );
      }
    }
  }

  Future<void> _handlePrint() async {
    SoundService.instance.playButtonClick();
    final shop = context.read<ShopProvider>().shop;
    final cart = context.read<CartProvider>();
    final sale = _completedSale ?? _buildCurrentSale(shop, cart);

    try {
      final imageBytes = await _screenshotController.capture(pixelRatio: 2.0);
      await ReceiptPrintService.printReceipt(
        sale: sale,
        shop: shop,
        imageBytes: imageBytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('प्रिंट एरर: $e')),
        );
      }
    }
  }

  Future<void> _handleDownload() async {
    SoundService.instance.playButtonClick();
    final shop = context.read<ShopProvider>().shop;
    final cart = context.read<CartProvider>();
    final sale = _completedSale ?? _buildCurrentSale(shop, cart);
    final userEmail = SupabaseService.instance.client?.auth.currentUser?.email;

    try {
      final savedFile = await ReceiptPrintService.downloadReceiptPdf(
        sale: sale,
        shop: shop,
        shopEmail: (userEmail != null && userEmail.isNotEmpty) ? userEmail : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00875A),
            duration: const Duration(seconds: 4),
            content: Text('बिल PDF सेव हो गया: ${savedFile.path.split(Platform.pathSeparator).last}'),
            action: SnackBarAction(
              label: 'Save / Open',
              textColor: Colors.white,
              onPressed: () {
                ReceiptPrintService.exportReceiptPdf(
                  sale: sale,
                  shop: shop,
                  shopEmail: (userEmail != null && userEmail.isNotEmpty) ? userEmail : null,
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('डाउनलोड एरर: $e')),
        );
      }
    }
  }

  Future<void> _handleShare() async {
    SoundService.instance.playButtonClick();
    final shop = context.read<ShopProvider>().shop;
    final cart = context.read<CartProvider>();
    final sale = _completedSale ?? _buildCurrentSale(shop, cart);

    try {
      final imageBytes = await _screenshotController.capture(pixelRatio: 2.0);
      if (mounted) {
        await ReceiptPrintService.showWhatsAppShareDialog(
          context,
          sale: sale,
          shop: shop,
          imageBytes: imageBytes,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('शेयर एरर: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final shop = context.watch<ShopProvider>().shop;
    final userEmail = SupabaseService.instance.client?.auth.currentUser?.email;

    final roundRes = _roundInfo(cart);
    final payableTotal = roundRes.roundedTotal;
    final cashInput = double.tryParse(_paidController.text.trim()) ?? 0.0;
    final changeDue = (_paymentMode == 'cash' && cashInput > payableTotal)
        ? (cashInput - payableTotal)
        : 0.0;
    final breakdown = _computeBreakdown(cart);

    final checkoutUpiAmount = _paymentMode == 'online'
        ? payableTotal
        : (_paymentMode == 'split' ? breakdown.upiDeclared : 0.0);

    final hasValidUpi = PaymentQrHelper.isValidUpiId(shop.upiId);
    final upiUri = (hasValidUpi && checkoutUpiAmount > 0.009)
        ? UpiService.generateUpiUri(
            upiId: shop.upiId!.trim(),
            payeeName: (shop.upiPayeeName != null && shop.upiPayeeName!.trim().isNotEmpty)
                ? shop.upiPayeeName!.trim()
                : shop.name,
            amount: checkoutUpiAmount,
            note: 'Bill $_billNo',
            billNo: '$_billNo',
            includeTr: false,
          )
        : null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 520;
            final maxDialogWidth = isTablet ? 520.0 : 440.0;
            return Container(
              constraints: BoxConstraints(maxWidth: maxDialogWidth, maxHeight: 760),
              child: _completedSale == null
                  ? _buildCheckoutStep(
                      context: context,
                      cart: cart,
                      shop: shop,
                      userEmail: userEmail,
                      breakdown: breakdown,
                      changeDue: changeDue,
                      checkoutUpiAmount: checkoutUpiAmount,
                      upiUri: upiUri,
                    )
                  : _buildCompletedReceiptStep(
                      context: context,
                      shop: shop,
                      userEmail: userEmail,
                    ),
            );
          },
        ),
      ),
    );
  }

  /// STEP 1: PAYMENT & CHECKOUT VIEW (Payment options + Bill preview + Complete Bill button)
  Widget _buildCheckoutStep({
    required BuildContext context,
    required CartProvider cart,
    required Shop shop,
    required String? userEmail,
    required PaymentBreakdown breakdown,
    required double changeDue,
    required double checkoutUpiAmount,
    required String? upiUri,
  }) {
    return Column(
      children: [
        // 1. Header Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.payment, size: 20, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'चेकआउट व भुगतान (Payment)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 2. Scrollable Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Total Payable Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'कुल देय राशि (Total Payable)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.format(_roundInfo(cart).roundedTotal),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                            if (_roundInfo(cart).roundOff.abs() > 0.001) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Subtotal ${CurrencyFormatter.format(cart.total)} · Round Off ${_roundInfo(cart).roundOff >= 0 ? '+' : '-'}${CurrencyFormatter.format(_roundInfo(cart).roundOff.abs())}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                '${cart.lines.length} सामान (Items)',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                            if (cart.customer != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'ग्राहक: ${cart.customer!.name}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Mode Selection Title
                const Text(
                  'भुगतान का तरीका चुनें (Payment Mode):',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 8),

                // Payment Mode Tabs
                Row(
                  children: [
                    _buildModeTab('cash', 'नकद (Cash)'),
                    const SizedBox(width: 6),
                    _buildModeTab('online', 'ऑनलाइन (UPI)'),
                    if (!context.watch<AuthProvider>().isStaffSession) ...[
                      const SizedBox(width: 6),
                      _buildModeTab('credit', 'उधार (Khata)'),
                      const SizedBox(width: 6),
                      _buildModeTab('split', 'Split'),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // Mode Specific Views:
                // 1. Cash & Split Inputs (placed right above QR so live Dynamic QR reacts in view!)
                if (_paymentMode == 'cash' || _paymentMode == 'split') ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _paymentMode == 'split' ? 'Cash (₹)' : 'Customer दिया Cash (₹)',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _paidController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              decoration: const InputDecoration(
                                prefixText: '₹ ',
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onChanged: (val) => _onCashChanged(val, cart),
                            ),
                          ],
                        ),
                      ),
                      if (_paymentMode == 'split') ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'UPI (₹)',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _upiController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                decoration: const InputDecoration(
                                  prefixText: '₹ ',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                onChanged: (val) => _onUpiChanged(val, cart),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'उधार / Credit (₹)',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5, color: Color(0xFFB45309)),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _creditController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFB45309)),
                                decoration: const InputDecoration(
                                  prefixText: '₹ ',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                onChanged: (val) => _onCreditChanged(val, cart),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_paymentMode == 'cash' && changeDue > 0) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Change वापसी:', style: TextStyle(fontSize: 11, color: Colors.blue)),
                                Text(CurrencyFormatter.format(changeDue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_paymentMode == 'split') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: breakdown.creditAmount > 0 ? Colors.amber.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: breakdown.creditAmount > 0 ? Colors.amber.shade300 : Colors.green.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Cash: ₹${breakdown.cashPaid.toStringAsFixed(0)} · UPI: ₹${breakdown.upiDeclared.toStringAsFixed(0)}${breakdown.upiDeclared > 0 ? (_onlinePaymentVerified ? ' (Paid ✓)' : ' (Pending)') : ''}',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                'उधार: ₹${breakdown.creditAmount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: breakdown.creditAmount > 0 ? Colors.red.shade700 : Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                          if (breakdown.creditAmount > 0.009) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  cart.customer != null ? Icons.account_balance_wallet_outlined : Icons.warning_amber_rounded,
                                  size: 16,
                                  color: cart.customer != null ? const Color(0xFF92400E) : const Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    cart.customer != null
                                        ? '${cart.customer!.name} के खाते में ₹${breakdown.creditAmount.toStringAsFixed(0)} उधार जुड़ेगा'
                                        : 'उधार ₹${breakdown.creditAmount.toStringAsFixed(0)} जोड़ने के लिए ग्राहक चुनें',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: cart.customer != null ? const Color(0xFF92400E) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  ),
                                  onPressed: () => _pickCustomerForCredit(cart),
                                  child: Text(
                                    cart.customer != null ? 'बदलें' : 'ग्राहक चुनें',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],

                // 2. Online / Split Live Dynamic UPI QR
                if (_paymentMode == 'online' || (_paymentMode == 'split' && checkoutUpiAmount > 0.009)) ...[
                  LayoutBuilder(
                    builder: (context, qrConstraints) {
                      final qrSize = (qrConstraints.maxWidth * 0.68).clamp(210.0, 260.0);
                      final hasStandeeFallback = upiUri == null &&
                          shop.qrImageUrl != null &&
                          shop.qrImageUrl!.trim().isNotEmpty;

                      Widget renderQrVisual() {
                        // Always prioritize live Dynamic Amount UPI QR when valid UPI ID is set
                        if (upiUri != null && upiUri.isNotEmpty) {
                          return QrImageView(
                            key: ValueKey(upiUri),
                            data: upiUri,
                            version: QrVersions.auto,
                            size: qrSize,
                            backgroundColor: Colors.white,
                          );
                        }
                        if (hasStandeeFallback) {
                          final imgUrl = shop.qrImageUrl!.trim();
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: imgUrl.startsWith('data:image')
                                ? Image.memory(
                                    base64Decode(imgUrl.split(',').last),
                                    width: qrSize,
                                    height: qrSize,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => _buildNoUpiWarning(),
                                  )
                                : imgUrl.startsWith('http')
                                    ? Image.network(
                                        imgUrl,
                                        width: qrSize,
                                        height: qrSize,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) => _buildNoUpiWarning(),
                                      )
                                    : (!kIsWeb
                                        ? Image.file(
                                            File(imgUrl),
                                            width: qrSize,
                                            height: qrSize,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) => _buildNoUpiWarning(),
                                          )
                                        : _buildNoUpiWarning()),
                          );
                        }
                        return _buildNoUpiWarning();
                      }

                      // Auto-verify countdown timer and MID box disabled per user request
                      const isPhonePeActive = false;

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _onlinePaymentVerified
                                ? Colors.green.shade400
                                : AppColors.primary.withValues(alpha: 0.35),
                            width: 1.4,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 20),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _paymentMode == 'split'
                                        ? 'Split UPI QR कोड स्कैन करें (केवल UPI हिस्सा)'
                                        : 'डायनामिक UPI QR कोड (Dynamic QR)',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E293B)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Center QR with generous Quiet Zone (16px white padding)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: renderQrVisual(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Payable: ${CurrencyFormatter.format(checkoutUpiAmount)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (isPhonePeActive)
                              Text(
                                'PhonePe MID: ${shop.phonePeMerchantId ?? 'Auto'} (${shop.phonePeEnvironment.toUpperCase()})',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF5F259F),
                                ),
                              )
                            else if (shop.upiId != null && shop.upiId!.trim().isNotEmpty)
                              Text(
                                'UPI ID: ${shop.upiId!.trim()}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              )
                            else
                              const Text(
                                'UPI ID: सेट नहीं है (Settings में जोड़ें)',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.w600),
                              ),
                            const SizedBox(height: 8),

                            if (isPhonePeActive) ...[
                              if (_onlinePaymentVerified)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.green.shade400),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 24),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '✓ भुगतान सत्यापित (Verified by PhonePe)',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.green.shade900),
                                            ),
                                            Text(
                                              'बिल अपने आप पूरा हो रहा है... Google Review QR तैयार है ✓',
                                              style: TextStyle(fontSize: 10.5, color: Colors.green.shade800),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFD8B4FE)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5F259F)),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'PhonePe भुगतान की प्रतीक्षा है... (${_phonePeRemainingSeconds ~/ 60}:${(_phonePeRemainingSeconds % 60).toString().padLeft(2, '0')})',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4C1D95)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        alignment: WrapAlignment.center,
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                              side: const BorderSide(color: Color(0xFF5F259F)),
                                            ),
                                            icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF5F259F)),
                                            label: const Text('स्थिति जांचें', style: TextStyle(fontSize: 11, color: Color(0xFF5F259F))),
                                            onPressed: () async {
                                              if (_activePhonePeTx != null) {
                                                final tx = await PhonePeService.instance.checkPaymentStatus(_activePhonePeTx!.merchantTransactionId);
                                                if (tx != null && tx.isSuccess) {
                                                  _phonePeTimer?.cancel();
                                                  setState(() => _onlinePaymentVerified = true);
                                                  SoundService.instance.playSuccess();
                                                  Future.delayed(const Duration(milliseconds: 600), () {
                                                    if (mounted && _completedSale == null && !_isSaving) {
                                                      _processCheckout();
                                                    }
                                                  });
                                                } else {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('भुगतान अभी पेंडिंग है। कृपया ग्राहक से पिन दर्ज करने को कहें।')),
                                                    );
                                                  }
                                                }
                                              }
                                            },
                                          ),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF00875A),
                                              foregroundColor: Colors.white,
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            icon: const Icon(Icons.check_circle_rounded, size: 14),
                                            label: const Text('✅ भुगतान मिल गया', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            onPressed: () {
                                              _phonePeTimer?.cancel();
                                              setState(() {
                                                _onlinePaymentVerified = true;
                                                _detectedPaymentApp = _detectedPaymentApp ?? 'PhonePe / Soundbox';
                                              });
                                              SoundService.instance.playSuccess();
                                              Future.delayed(const Duration(milliseconds: 300), () {
                                                if (mounted && _completedSale == null && !_isSaving) {
                                                  _processCheckout();
                                                }
                                              });
                                            },
                                          ),
                                          if (shop.phonePeEnvironment == 'sandbox')
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF00875A),
                                                foregroundColor: Colors.white,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              icon: const Icon(Icons.science_outlined, size: 14),
                                              label: const Text('🧪 Test Pay', style: TextStyle(fontSize: 11)),
                                              onPressed: () async {
                                                if (_activePhonePeTx != null) {
                                                  final res = await PhonePeService.instance.simulatePaymentSuccess(_activePhonePeTx!.merchantTransactionId);
                                                  if (res != null && res.isSuccess) {
                                                    _phonePeTimer?.cancel();
                                                    setState(() => _onlinePaymentVerified = true);
                                                    SoundService.instance.playSuccess();
                                                    Future.delayed(const Duration(milliseconds: 600), () {
                                                      if (mounted && _completedSale == null && !_isSaving) {
                                                        _processCheckout();
                                                      }
                                                    });
                                                  }
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            ] else ...[
                              if (_onlinePaymentVerified)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.green.shade400),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 24),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '✓ भुगतान सत्यापित (${_detectedPaymentApp ?? 'UPI'})',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.green.shade900),
                                            ),
                                            Text(
                                              _paymentMode == 'split'
                                                  ? 'UPI हिस्सा सत्यापित ✓ — अब बिल पूरा करें दबाएं'
                                                  : 'भुगतान प्राप्त ✓ — रसीद तैयार है',
                                              style: TextStyle(fontSize: 10.5, color: Colors.green.shade800),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else ...[
                                // Single clean verification control (no duplicate checkbox or test banner)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00875A),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 2,
                                    ),
                                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                                    label: Text(
                                      _paymentMode == 'split'
                                          ? '✅ UPI भुगतान मिल गया (Verify UPI)'
                                          : '✅ भुगतान मिल गया · बिल पूरा करें (Mark Paid)',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: () {
                                      _phonePeTimer?.cancel();
                                      setState(() {
                                        _onlinePaymentVerified = true;
                                        _detectedPaymentApp = _detectedPaymentApp ?? 'Manual (साउंडबॉक्स / UPI)';
                                      });
                                      SoundService.instance.playSuccess();
                                      if (_paymentMode != 'split') {
                                        Future.delayed(const Duration(milliseconds: 300), () {
                                          if (mounted && _completedSale == null && !_isSaving) {
                                            _processCheckout();
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // 3. Khata Notice with Credit Limit & Inline Customer Picker
                if (_paymentMode == 'credit') ...[
                  Builder(
                    builder: (context) {
                      final payableTotal = _roundInfo(cart).roundedTotal;
                      final hasCustomer = cart.customer != null;
                      final isOverLimit = hasCustomer &&
                          cart.customer!.creditLimit > 0 &&
                          (cart.customer!.balance + payableTotal) > cart.customer!.creditLimit;

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isOverLimit ? const Color(0xFFFEF2F2) : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isOverLimit ? const Color(0xFFFCA5A5) : Colors.amber.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isOverLimit ? Icons.warning_amber_rounded : Icons.info_outline,
                              color: isOverLimit ? const Color(0xFFDC2626) : Colors.amber.shade800,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hasCustomer
                                        ? 'ग्राहक: ${cart.customer!.name} के खाते में ${CurrencyFormatter.format(payableTotal)} जुड़ेगा।'
                                        : 'कृपया पहले ग्राहक (Customer) चुनें।',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  if (hasCustomer && cart.customer!.creditLimit > 0) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      isOverLimit
                                          ? '⚠️ क्रेडिट लिमिट पार! तय सीमा: ₹${cart.customer!.creditLimit.toStringAsFixed(0)}, नया कुल बकाया: ₹${(cart.customer!.balance + payableTotal).toStringAsFixed(0)}'
                                          : 'क्रेडिट लिमिट: ₹${cart.customer!.creditLimit.toStringAsFixed(0)} (शेष लिमिट: ₹${(cart.customer!.creditLimit - (cart.customer!.balance + payableTotal)).toStringAsFixed(0)})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isOverLimit ? const Color(0xFFDC2626) : const Color(0xFF00875A),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _pickCustomerForCredit(cart),
                              child: Text(hasCustomer ? 'बदलें' : 'ग्राहक चुनें'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // 4. Bill Receipt Preview (loaded right below the payment inputs)
                const SizedBox(height: 8),
                const Divider(thickness: 1.2),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.receipt_long, size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 6),
                    Text(
                      'बिल रसीद (Bill Preview):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                BillReceiptCard(
                  shopName: shop.name,
                  shopAddress: shop.address,
                  shopPhone: shop.phone,
                  shopEmail: (userEmail != null && userEmail.isNotEmpty) ? userEmail : null,
                  gstin: shop.gstin,
                  billNo: '$_billNo',
                  dateString: DateFormat('dd-MM-yyyy h:mm a').format(TimeSyncService.instance.nowLocal()),
                  customerName: cart.customer?.name,
                  customerPhone: cart.customer?.phone,
                  items: cart.lines,
                  subtotal: cart.subtotal,
                  discount: cart.discount,
                  roundOff: _roundInfo(cart).roundOff,
                  total: _roundInfo(cart).roundedTotal,
                  paid: breakdown.paid,
                  due: breakdown.due,
                  paymentMode: _paymentMode,
                  paymentStatus: breakdown.paymentStatus,
                  upiPayableAmount: breakdown.upiPayable,
                  onlineVerified: breakdown.onlineVerified,
                  cashPaid: breakdown.cashPaid,
                  upiPaid: breakdown.upiPaid,
                  creditAmount: breakdown.creditAmount,
                  footerMessage: shop.receiptFooter,
                  upiId: shop.upiId,
                  upiPayeeName: shop.upiPayeeName,
                  googleReviewUrl: shop.googleReviewUrl,
                  editCount: cart.isEditingBill ? (cart.editingSale!.editCount + 1) : 0,
                  showQr: false, // Only 1 live real-time QR code at the top of checkout!
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        const Divider(height: 1),

        // 3. Bottom Action Bar for Step 1: Cancel + Big Complete Bill Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey.shade50,
          child: Row(
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('रद्द करें (Cancel)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cart.isEditingBill ? Colors.amber.shade800 : AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 1,
                  ),
                  onPressed: _isSaving ? null : _processCheckout,
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          cart.isEditingBill
                              ? 'बिल अपडेट करें · ${CurrencyFormatter.format(_roundInfo(cart).roundedTotal)}'
                              : 'बिल पूरा करें · ${CurrencyFormatter.format(_roundInfo(cart).roundedTotal)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// STEP 2: BILL COMPLETED VIEW (Shows full BillReceiptCard + Print/Share/New Sale buttons)
  Widget _buildCompletedReceiptStep({
    required BuildContext context,
    required Shop shop,
    required String? userEmail,
  }) {
    final sale = _completedSale!;
    final dateString = DateFormat('dd-MM-yyyy h:mm a').format(sale.createdAt.toLocal());

    return Column(
      children: [
        // 1. Header Bar with Accurate Status Badge
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      sale.isFullyPaidAndVerified ? Icons.check_circle : Icons.pending_actions_rounded,
                      color: sale.isFullyPaidAndVerified ? Colors.green : Colors.amber.shade700,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sale.isFullyPaidAndVerified
                            ? 'बिल पूरा हो गया (Paid · #${sale.billNo})'
                            : (sale.effectiveUpiPayable > 0.009
                                ? 'Payment Pending · #${sale.billNo}'
                                : 'बिल सेव (उधार बाकी · #${sale.billNo})'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSaleCompleted();
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 2. Scrollable Bill Receipt Card
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Screenshot(
              controller: _screenshotController,
              child: BillReceiptCard(
                shopName: shop.name,
                shopAddress: shop.address,
                shopPhone: shop.phone,
                shopEmail: (userEmail != null && userEmail.isNotEmpty) ? userEmail : null,
                gstin: shop.gstin,
                billNo: '${sale.billNo}',
                dateString: dateString,
                customerName: sale.customerName,
                customerPhone: sale.customerPhone,
                items: sale.items,
                subtotal: sale.subtotal,
                discount: sale.discount,
                roundOff: sale.roundOff,
                total: sale.total,
                paid: sale.paid,
                due: sale.due,
                paymentMode: sale.paymentMode,
                paymentStatus: sale.paymentStatus,
                upiPayableAmount: sale.effectiveUpiPayable,
                onlineVerified: sale.onlineVerified,
                cashPaid: sale.cashPaid,
                upiPaid: sale.upiPaid,
                creditAmount: sale.creditAmount,
                footerMessage: shop.receiptFooter,
                quoteLine1: _currentBillQuote?.line1,
                quoteLine2: _currentBillQuote?.line2,
                upiId: shop.upiId,
                upiPayeeName: shop.upiPayeeName,
                googleReviewUrl: shop.googleReviewUrl,
                editCount: sale.editCount,
              ),
            ),
          ),
        ),

        const Divider(height: 1),

        // 3. Bottom Action Buttons (Back / Share / Download / Print)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: Colors.grey.shade50,
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    SoundService.instance.playButtonClick();
                    Navigator.pop(context);
                    widget.onSaleCompleted();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, color: Color(0xFF2563EB), size: 22),
                        SizedBox(height: 3),
                        Text(
                          'नया बिल',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    SoundService.instance.playButtonClick();
                    _handleShare();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share, color: Color(0xFF16A34A), size: 22),
                        SizedBox(height: 3),
                        Text(
                          'Share Bill',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: _handleDownload,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_rounded, color: Color(0xFF0284C7), size: 22),
                        SizedBox(height: 3),
                        Text(
                          'Download',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    SoundService.instance.playButtonClick();
                    _handlePrint();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.print, color: Color(0xFF2563EB), size: 22),
                        SizedBox(height: 3),
                        Text(
                          'Print Bill',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeTab(String mode, String label) {
    final isSelected = _paymentMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          SoundService.instance.playButtonClick();
          _onModeChanged(mode);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.lightMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.lightBorder),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoUpiWarning() {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 36),
          SizedBox(height: 6),
          Text(
            'UPI QR उपलब्ध नहीं है',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown),
          ),
          SizedBox(height: 4),
          Text(
            'दुकानदार की UPI ID या QR फोटो सेटिंग्स में नहीं है। कृपया सेटिंग्स में दर्ज करें।',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
