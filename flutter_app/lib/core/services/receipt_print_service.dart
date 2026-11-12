import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/sale.dart';
import '../../data/models/shop.dart';
import 'bluetooth_printer_service.dart';
import 'ai_quote_service.dart';
import 'printer_settings_service.dart';
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
                  pw.Text('Bill No: #${sale.billNo}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
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
    if (decision.type == BillQrType.upiPayment) {
      return 'बिल / Invoice #${sale.billNo} - ${shop.name}\n'
          'कुल राशि: ₹${sale.total.toStringAsFixed(2)} | बकाया (UPI): ₹${decision.amountToPay.toStringAsFixed(2)}\n'
          '${PaymentQrHelper.upiPaymentInstructionHindi}';
    }
    if (decision.type == BillQrType.googleReview) {
      return 'बिल / Invoice #${sale.billNo} - ${shop.name}\n'
          'भुगतान प्राप्त (₹${sale.paid.toStringAsFixed(2)}) ✓\n'
          '${PaymentQrHelper.googleReviewInstructionHindi}';
    }
    return 'बिल / Invoice #${sale.billNo} - ${shop.name} (₹${sale.total.toStringAsFixed(2)})';
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
}
