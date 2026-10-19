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
                    pw.Text('Balance (Udhar):', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text('₹${sale.due.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8),

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

  /// Print receipt directly or open system print dialog
  static Future<void> printReceipt({
    required Sale sale,
    required Shop shop,
    Uint8List? imageBytes,
    String? shopEmail,
  }) async {
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
      return;
    }

    final pdf = await generateReceiptDocument(sale: sale, shop: shop, shopEmail: shopEmail);
    final bytes = await pdf.save();

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Invoice_${sale.billNo}',
    );
  }

  /// Share receipt image or PDF on WhatsApp or other apps
  static Future<void> shareReceipt({
    required Sale sale,
    required Shop shop,
    Uint8List? imageBytes,
    String? shopEmail,
  }) async {
    if (imageBytes != null) {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Invoice_${sale.billNo}.png');
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'बिल / Invoice #${sale.billNo} - ${shop.name}',
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
