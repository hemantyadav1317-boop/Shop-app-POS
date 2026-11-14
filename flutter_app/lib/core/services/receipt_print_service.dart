import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/sale.dart';
import '../../data/models/shop.dart';
import 'bluetooth_printer_service.dart';
import 'ai_quote_service.dart';
import 'printer_settings_service.dart';
import 'sound_service.dart';
import '../utils/payment_qr_helper.dart';

class ReceiptPrintService {
  /// Generate PDF document for thermal receipt (58mm or 80mm) with Hindi Unicode support
  static Future<pw.Document> generateReceiptDocument({
    required Sale sale,
    required Shop shop,
    String? shopEmail,
  }) async {
    final pdf = pw.Document();
    final is80mm = shop.printPaperSize == '80mm';
    final rollFormat = is80mm
        ? const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm)
        : const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm);

    final dateFormat = DateFormat('dd-MM-yyyy hh:mm a');
    final formattedDate = dateFormat.format(sale.createdAt);
    final payeeName = (shop.upiPayeeName != null && shop.upiPayeeName!.trim().isNotEmpty)
        ? shop.upiPayeeName!.trim()
        : shop.name;
    final qrDecision = sale.resolveQr(
      upiId: shop.upiId,
      shopName: payeeName,
      googleReviewUrl: shop.googleReviewUrl,
    );
    final showQr = PrinterSettingsService.instance.showQr;

    // Load Devanagari Hindi font so Indian characters and Hindi item names render properly
    pw.ThemeData? themeData;
    try {
      final fontRegular = await PdfGoogleFonts.notoSansDevanagariRegular();
      final fontBold = await PdfGoogleFonts.notoSansDevanagariBold();
      themeData = pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      );
    } catch (_) {
      // Fallback to default if offline / no internet connection
    }

    pdf.addPage(
      pw.Page(
        theme: themeData,
        pageFormat: rollFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Store Header
              pw.Center(
                child: pw.Text(
                  shop.name,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: is80mm ? 14 : 12),
                ),
              ),
              if (shop.address != null && shop.address!.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    shop.address!,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
              if (shop.phone != null && shop.phone!.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'Phone: ${shop.phone!}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
              if (shopEmail != null && shopEmail.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'Email: $shopEmail',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ),
              if (shop.gstin != null && shop.gstin!.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'GSTIN: ${shop.gstin!}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8),

              // Invoice Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text('Bill No: #${sale.billNo}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      if (sale.isEdited) ...[
                        pw.SizedBox(width: 4),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(width: 0.6),
                            borderRadius: pw.BorderRadius.circular(2),
                          ),
                          child: pw.Text(
                            sale.editedTagText,
                            style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  pw.Text(formattedDate, style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              if (sale.customerName != null && sale.customerName!.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text('Customer: ${sale.customerName!}', style: const pw.TextStyle(fontSize: 8)),
                if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
                  pw.Text('Mobile: ${sale.customerPhone!}', style: const pw.TextStyle(fontSize: 7)),
              ],
              pw.Divider(thickness: 0.8),

              // Table Headers
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('Item', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Item Lines
              ...sale.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(item.name, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            pw.Text('₹${item.price.toStringAsFixed(2)} / ${item.unit}', style: const pw.TextStyle(fontSize: 6.5)),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text('${item.qty}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('₹${item.total.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }),
              pw.Divider(thickness: 0.8),

              // Totals
              if (sale.discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('₹${sale.subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              if (sale.discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('-₹${sale.discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GRAND TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: is80mm ? 12 : 10)),
                  pw.Text('₹${sale.total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: is80mm ? 12 : 10)),
                ],
              ),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Payment Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payment Mode:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(sale.paymentMode.toUpperCase(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Amount Paid:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('₹${sale.paid.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (sale.due > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Balance (Due / शेष):', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text('₹${sale.due.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              if (sale.paymentMode == 'split') ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  [
                    if (sale.cashPaid > 0) 'Cash: ₹${sale.cashPaid.toStringAsFixed(2)}',
                    if (sale.upiPaid > 0) 'UPI Paid: ₹${sale.upiPaid.toStringAsFixed(2)}',
                    if (sale.effectiveUpiPayable > 0) 'UPI Due: ₹${sale.effectiveUpiPayable.toStringAsFixed(2)}',
                    if (sale.creditAmount > 0) 'Credit: ₹${sale.creditAmount.toStringAsFixed(2)}',
                  ].join(' | '),
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ],
              pw.SizedBox(height: 3),
              pw.Text(
                sale.isFullyPaidAndVerified
                    ? 'Status: PAID (Verified)'
                    : (sale.effectiveUpiPayable > 0.009
                        ? 'Status: PAYMENT PENDING (UPI ₹${sale.effectiveUpiPayable.toStringAsFixed(2)})'
                        : 'Status: PENDING / UDHAR'),
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
              ),

              if (showQr && qrDecision.hasQr) ...[
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.6),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        qrDecision.headline,
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                      ),
                      if (qrDecision.type == BillQrType.upiPayment) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          qrDecision.instructionText,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                      pw.SizedBox(height: 4),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrDecision.qrData!,
                        width: is80mm ? 105 : 85,
                        height: is80mm ? 105 : 85,
                      ),
                      pw.SizedBox(height: 4),
                      if (qrDecision.type == BillQrType.upiPayment) ...[
                        pw.Text(
                          'बकाया / Payable: ₹${qrDecision.amountToPay.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                        ),
                        if (qrDecision.upiId != null && qrDecision.upiId!.isNotEmpty)
                          pw.Text(qrDecision.upiId!, style: const pw.TextStyle(fontSize: 7)),
                      ] else ...[
                        pw.Text(
                          qrDecision.instructionText,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8),

              // AI Dynamic Quote
              pw.Center(
                child: pw.Text(
                  AiQuoteService.getQuoteForBillNo(sale.billNo).line1,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  AiQuoteService.getQuoteForBillNo(sale.billNo).line2,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic),
                ),
              ),
              pw.SizedBox(height: 3),

              // Footer Message
              pw.Center(
                child: pw.Text(
                  shop.receiptFooter ?? 'धन्यवाद! फिर पधारें 🙏',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'Powered by Shop POS',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Print receipt directly via Bluetooth thermal printer or open system print dialog
  static Future<bool> printReceipt({
    required Sale sale,
    required Shop shop,
    Uint8List? imageBytes,
    String? shopEmail,
  }) async {
    // 1. Try Direct Bluetooth Thermal Printing if a printer is saved / connected
    try {
      final isConnected = await BluetoothPrinterService.isConnected();
      final savedMac = await BluetoothPrinterService.getSavedPrinterMac();
      if (isConnected || (savedMac != null && savedMac.isNotEmpty)) {
        final success = await BluetoothPrinterService.printReceiptDirect(
          sale: sale,
          shop: shop,
          imageBytes: imageBytes,
        );
        if (success) {
          return true;
        }
      }
    } catch (_) {}

    // 2. Fallback to Android System Print / PDF Spooler
    if (imageBytes != null) {
      final doc = pw.Document();
      final img = pw.MemoryImage(imageBytes);
      final is80mm = shop.printPaperSize == '80mm';
      final rollFormat = is80mm
          ? const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm)
          : const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm);

      doc.addPage(
        pw.Page(
          pageFormat: rollFormat,
          build: (pw.Context context) => pw.Center(child: pw.Image(img)),
        ),
      );
      final bytes = await doc.save();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'Invoice_${sale.billNo}',
      );
      return false;
    }

    final pdf = await generateReceiptDocument(sale: sale, shop: shop, shopEmail: shopEmail);
    final bytes = await pdf.save();

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Invoice_${sale.billNo}',
    );
    return false;
  }

  /// Build contextual share message matching verified vs pending payment state
  static String buildShareCaption({required Sale sale, required Shop shop}) {
    final payeeName = (shop.upiPayeeName != null && shop.upiPayeeName!.trim().isNotEmpty)
        ? shop.upiPayeeName!.trim()
        : shop.name;
    final decision = sale.resolveQr(
      upiId: shop.upiId,
      shopName: payeeName,
      googleReviewUrl: shop.googleReviewUrl,
    );
    final editSuffix = sale.isEdited ? ' [${sale.editedTagText}]' : '';
    if (decision.type == BillQrType.upiPayment) {
      return 'बिल / Invoice #${sale.billNo}$editSuffix - ${shop.name}\n'
          'कुल राशि: ₹${sale.total.toStringAsFixed(2)} | बकाया (UPI): ₹${decision.amountToPay.toStringAsFixed(2)}\n'
          '${PaymentQrHelper.upiPaymentInstructionHindi}';
    }
    if (decision.type == BillQrType.googleReview) {
      return 'बिल / Invoice #${sale.billNo}$editSuffix - ${shop.name}\n'
          'भुगतान प्राप्त (₹${sale.paid.toStringAsFixed(2)}) ✓\n'
          '${PaymentQrHelper.googleReviewInstructionHindi}';
    }
    return 'बिल / Invoice #${sale.billNo}$editSuffix - ${shop.name} (₹${sale.total.toStringAsFixed(2)})';
  }

  /// Download bill PDF (with embedded UPI Payment or Google Review QR) to local storage
  static Future<File> downloadReceiptPdf({
    required Sale sale,
    required Shop shop,
    String? shopEmail,
  }) async {
    final pdf = await generateReceiptDocument(
      sale: sale,
      shop: shop,
      shopEmail: shopEmail,
    );
    final bytes = await pdf.save();
    final baseDir = await getApplicationDocumentsDirectory();
    final invoicesDir = Directory('${baseDir.path}/Invoices');
    if (!await invoicesDir.exists()) {
      await invoicesDir.create(recursive: true);
    }
    final file = File('${invoicesDir.path}/Invoice_${sale.billNo}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Export / Save Bill PDF via Android system share/save dialog
  static Future<void> exportReceiptPdf({
    required Sale sale,
    required Shop shop,
    String? shopEmail,
  }) async {
    final pdf = await generateReceiptDocument(
      sale: sale,
      shop: shop,
      shopEmail: shopEmail,
    );
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Invoice_${sale.billNo}.pdf',
    );
  }

  /// Share receipt image or PDF on WhatsApp or other apps
  static Future<void> shareReceipt({
    required Sale sale,
    required Shop shop,
    Uint8List? imageBytes,
    String? shopEmail,
  }) async {
    final caption = buildShareCaption(sale: sale, shop: shop);
    if (imageBytes != null) {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Invoice_${sale.billNo}.png');
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: caption,
      );
      return;
    }

    final pdf = await generateReceiptDocument(sale: sale, shop: shop, shopEmail: shopEmail);
    final bytes = await pdf.save();

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Invoice_${sale.billNo}.pdf',
    );
  }

  /// Builds a complete, professionally formatted WhatsApp invoice text
  static String buildDetailedWhatsAppInvoice({
    required Sale sale,
    required Shop shop,
  }) {
    final sb = StringBuffer();
    sb.writeln('🧾 *${shop.name}*');
    if (shop.phone != null && shop.phone!.isNotEmpty) sb.writeln('📞 Phone: ${shop.phone}');
    if (shop.address != null && shop.address!.isNotEmpty) sb.writeln('📍 ${shop.address}');
    sb.writeln('--------------------------------');
    sb.writeln('📄 *Invoice #${sale.billNo}* ${sale.isEdited ? "(${sale.editedTagText})" : ""}');
    sb.writeln('📅 ${DateFormat('dd-MM-yyyy hh:mm a').format(sale.createdAt.toLocal())}');
    if (sale.customerName != null && sale.customerName!.isNotEmpty) {
      sb.writeln('👤 Customer: ${sale.customerName}');
    }
    sb.writeln('--------------------------------');
    sb.writeln('*आइटम्स (Items):*');
    for (int i = 0; i < sale.items.length; i++) {
      final it = sale.items[i];
      sb.writeln('${i + 1}. ${it.name} - ${it.qty} ${it.unit} x ₹${it.price.toStringAsFixed(0)} = ₹${it.total.toStringAsFixed(0)}');
    }
    sb.writeln('--------------------------------');
    sb.writeln('कुल राशि (Subtotal): ₹${sale.subtotal.toStringAsFixed(2)}');
    if (sale.discount > 0) {
      sb.writeln('छूट (Discount): -₹${sale.discount.toStringAsFixed(2)}');
    }
    sb.writeln('💰 *कुल देय (Total): ₹${sale.total.toStringAsFixed(2)}*');
    sb.writeln('भुगतान (Paid): ₹${sale.paid.toStringAsFixed(2)} (${sale.paymentMode.toUpperCase()})');
    if (sale.due > 0) {
      sb.writeln('⚠️ *बकाया (Due): ₹${sale.due.toStringAsFixed(2)}*');
    }

    if (shop.upiId != null && shop.upiId!.isNotEmpty && sale.effectiveUpiPayable > 0.009) {
      final upiUri = 'upi://pay?pa=${shop.upiId}&pn=${Uri.encodeComponent(shop.upiPayeeName ?? shop.name)}&am=${sale.effectiveUpiPayable.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent("Bill ${sale.billNo} ${shop.name}")}';
      sb.writeln('\n⚡ *1-क्लिक UPI भुगतान लिंक:*');
      sb.writeln(upiUri);
    }
    if (shop.receiptFooter != null && shop.receiptFooter!.isNotEmpty) {
      sb.writeln('\n${shop.receiptFooter}');
    } else {
      sb.writeln('\nधन्यवाद! फिर पधारें 🙏');
    }
    return sb.toString();
  }

  /// Displays a direct WhatsApp Share dialog where entering the customer's phone number
  /// directly opens WhatsApp for that customer with the bill invoice!
  static Future<void> showWhatsAppShareDialog(
    BuildContext context, {
    required Sale sale,
    required Shop shop,
    Uint8List? imageBytes,
    String? shopEmail,
  }) async {
    final phoneCtrl = TextEditingController(text: sale.customerPhone ?? '');
    File? cachedImageFile;

    if (imageBytes != null) {
      try {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/Invoice_${sale.billNo}.png');
        await file.writeAsBytes(imageBytes);
        cachedImageFile = file;
      } catch (e) {
        debugPrint("Error saving bill screenshot: $e");
      }
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final phoneText = phoneCtrl.text.trim();
          final cleanPhone = phoneText.replaceAll(RegExp(r'[^0-9]'), '');
          final isValidPhone = cleanPhone.length >= 10;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            title: Row(
              children: const [
                Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'WhatsApp पर बिल भेजें',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      'बिल #${sale.billNo} • कुल: ₹${sale.total.toStringAsFixed(0)} • ${sale.items.length} आइटम्स',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF16A34A)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'ग्राहक का मोबाइल नंबर दर्ज करें (WhatsApp Number):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    autofocus: phoneCtrl.text.isEmpty,
                    decoration: InputDecoration(
                      hintText: 'उदा. 9876543210',
                      prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF25D366)),
                      suffixIcon: phoneCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                phoneCtrl.clear();
                                setDialogState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 18),

                  // 1. Primary Action: Direct WhatsApp Chat
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
                    label: Text(
                      isValidPhone ? 'सीधे WhatsApp पर भेजें' : 'WhatsApp पर भेजें',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () async {
                      String clean = phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
                      if (clean.length == 10) clean = '91$clean';

                      if (clean.length < 10) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFFDC2626),
                            content: Text('कृपया सही 10-अंकों का मोबाइल नंबर दर्ज करें!'),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(ctx);
                      SoundService.instance.playSuccess();

                      final detailedText = buildDetailedWhatsAppInvoice(sale: sale, shop: shop);
                      final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(detailedText)}');

                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }

                      // Also share receipt image via Share sheet if available
                      if (cachedImageFile != null) {
                        await Share.shareXFiles(
                          [XFile(cachedImageFile.path)],
                          text: buildShareCaption(sale: sale, shop: shop),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 10),

                  // 2. Secondary Action: Share Image on Any App
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.share_outlined, size: 18, color: Colors.blueGrey),
                    label: const Text(
                      'अन्य ऐप्स पर शेयर करें (Share Sheet)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await shareReceipt(
                        sale: sale,
                        shop: shop,
                        imageBytes: imageBytes,
                        shopEmail: shopEmail,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
