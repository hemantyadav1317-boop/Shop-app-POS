import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../data/models/cart_item.dart';
import '../../../../core/services/printer_settings_service.dart';

class DashedDivider extends StatelessWidget {
  final double height;
  final Color color;

  const DashedDivider({super.key, this.height = 1, this.color = Colors.black});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashSpace = 3.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Flex(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            direction: Axis.horizontal,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

/// A pixel-perfect Thermal Invoice Receipt widget matching the clean Indian POS receipt format
/// Scales cleanly to 384px (58mm) or 576px (80mm) with customizable font scaling and toggles
class BillReceiptCard extends StatelessWidget {
  final String shopName;
  final String? shopAddress;
  final String? shopPhone;
  final String? shopEmail;
  final String? gstin;
  final String billNo;
  final String dateString;
  final String? customerName;
  final String? customerPhone;
  final List<CartItem> items;
  final double subtotal;
  final double discount;
  final double total;
  final double paid;
  final double due;
  final String paymentMode;
  final String? footerMessage;
  final String? quoteLine1;
  final String? quoteLine2;
  final String? upiId;

  // Customizable overrides (if null, fetched from PrinterSettingsService)
  final double? fontScale;
  final double? printWidth;
  final bool? showShopName;
  final bool? showAddress;
  final bool? showPhone;
  final bool? showEmail;
  final bool? showGstin;
  final bool? showInvoiceNo;
  final bool? showCustomer;
  final bool? showQuote;
  final bool? showFooter;
  final bool? showQr;

  const BillReceiptCard({
    super.key,
    required this.shopName,
    this.shopAddress,
    this.shopPhone,
    this.shopEmail,
    this.gstin,
    required this.billNo,
    required this.dateString,
    this.customerName,
    this.customerPhone,
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    required this.total,
    required this.paid,
    this.due = 0.0,
    required this.paymentMode,
    this.footerMessage,
    this.quoteLine1,
    this.quoteLine2,
    this.upiId,
    this.fontScale,
    this.printWidth,
    this.showShopName,
    this.showAddress,
    this.showPhone,
    this.showEmail,
    this.showGstin,
    this.showInvoiceNo,
    this.showCustomer,
    this.showQuote,
    this.showFooter,
    this.showQr,
  });

  String _formatPaymentMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'online':
        return 'Online';
      case 'credit':
        return 'उधार (Credit)';
      case 'split':
        return 'Split';
      default:
        return 'Cash';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ps = PrinterSettingsService.instance;

    final scale = fontScale ?? ps.fontScale;
    final width = printWidth ?? (ps.paperSize == '80mm' ? 576.0 : 384.0);

    final optShopName = showShopName ?? ps.showShopName;
    final optAddress = showAddress ?? ps.showAddress;
    final optPhone = showPhone ?? ps.showPhone;
    final optEmail = showEmail ?? ps.showEmail;
    final optGstin = showGstin ?? ps.showGstin;
    final optInvoiceNo = showInvoiceNo ?? ps.showInvoiceNo;
    final optCustomer = showCustomer ?? ps.showCustomer;
    final optQuote = showQuote ?? ps.showQuote;
    final optFooter = showFooter ?? ps.showFooter;
    final optQr = showQr ?? ps.showQr;

    final cleanBillNo = billNo.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');

    return Container(
      width: width,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Store Header (Centered, Large Bold)
          if (optShopName || optAddress || optPhone || optEmail || optGstin)
            Center(
              child: Column(
                children: [
                  if (optShopName)
                    Text(
                      shopName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22 * scale,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color: Colors.black,
                        height: 1.15,
                      ),
                    ),
                  if (optAddress && shopAddress != null && shopAddress!.trim().isNotEmpty) ...[
                    SizedBox(height: 3 * scale),
                    Text(
                      shopAddress!.trim(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.0 * scale,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                        height: 1.2,
                      ),
                    ),
                  ],
                  if (optPhone && shopPhone != null && shopPhone!.trim().isNotEmpty) ...[
                    SizedBox(height: 2 * scale),
                    Text(
                      'Tel: ${shopPhone!.trim()}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.0 * scale,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                  if (optEmail && shopEmail != null && shopEmail!.trim().isNotEmpty) ...[
                    SizedBox(height: 2 * scale),
                    Text(
                      'Email: ${shopEmail!.trim()}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.0 * scale,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                  if (optGstin && gstin != null && gstin!.trim().isNotEmpty) ...[
                    SizedBox(height: 2 * scale),
                    Text(
                      'GSTIN: ${gstin!.trim()}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.0 * scale,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          SizedBox(height: 6 * scale),

          // 2. INVOICE Title
          Center(
            child: Text(
              'INVOICE',
              style: TextStyle(
                fontSize: 17 * scale,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: Colors.black,
              ),
            ),
          ),

          SizedBox(height: 5 * scale),

          // 3. Date & Invoice No
          if (optInvoiceNo)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateString,
                  style: TextStyle(
                    fontSize: 13.0 * scale,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Invoice $cleanBillNo',
                  style: TextStyle(
                    fontSize: 13.0 * scale,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),

          if (optCustomer && customerName != null && customerName!.trim().isNotEmpty) ...[
            SizedBox(height: 3 * scale),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Customer: ${customerName!.trim()}',
                  style: TextStyle(
                    fontSize: 12.5 * scale,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                if (customerPhone != null && customerPhone!.trim().isNotEmpty)
                  Text(
                    customerPhone!.trim(),
                    style: TextStyle(
                      fontSize: 12.5 * scale,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
              ],
            ),
          ],

          const DashedDivider(),

          // 4. Items Table Header
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'ITEM',
                  style: TextStyle(
                    fontSize: 13.0 * scale,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'QTY',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13.0 * scale,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'PRICE',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13.0 * scale,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'TOTAL',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13.0 * scale,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),

          const DashedDivider(),

          // 5. Item Rows (Name on Line 1, Qty / Rate / Total on Line 2 for maximum readability)
          ...items.map((item) {
            final qtyStr = item.qty % 1 == 0 ? item.qty.toInt().toString() : item.qty.toStringAsFixed(2);
            final priceStr = item.price % 1 == 0 ? item.price.toInt().toString() : item.price.toStringAsFixed(2);
            final totStr = item.total % 1 == 0 ? item.total.toInt().toString() : item.total.toStringAsFixed(2);

            return Padding(
              padding: EdgeInsets.symmetric(vertical: 2.5 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 14.5 * scale,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 1.5 * scale),
                  Row(
                    children: [
                      const Expanded(flex: 3, child: SizedBox()),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '$qtyStr ${item.unit}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13.0 * scale,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          priceStr,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13.0 * scale,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          totStr,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13.5 * scale,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          const DashedDivider(),

          // 6. Subtotal & Items Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items : ${items.length}',
                style: TextStyle(
                  fontSize: 13.5 * scale,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              Text(
                'Sub Total : Rs ${subtotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13.5 * scale,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),

          if (discount > 0) ...[
            SizedBox(height: 2 * scale),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discount :',
                  style: TextStyle(
                    fontSize: 13.0 * scale,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  '- Rs ${discount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13.0 * scale,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ],

          const DashedDivider(),

          // 7. GRAND TOTAL (Huge & Bold)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 3.5 * scale),
            child: Center(
              child: Text(
                'Total : Rs ${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 22.0 * scale,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          const DashedDivider(),

          // 8. Payment Mode
          Center(
            child: Column(
              children: [
                Text(
                  'Payment Mode',
                  style: TextStyle(
                    fontSize: 13.0 * scale,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 2 * scale),
                Text(
                  '${_formatPaymentMode(paymentMode)} : ${paid.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14.5 * scale,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                if (due > 0) ...[
                  SizedBox(height: 3 * scale),
                  Text(
                    'Due : Rs ${due.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14.5 * scale,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Optional UPI QR Code
          if (optQr && upiId != null && upiId!.trim().isNotEmpty && total > 0) ...[
            const DashedDivider(),
            Center(
              child: Column(
                children: [
                  Text(
                    'Scan & Pay (UPI)',
                    style: TextStyle(
                      fontSize: 12.0 * scale,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  QrImageView(
                    data: 'upi://pay?pa=${upiId!.trim()}&pn=${Uri.encodeComponent(shopName)}&am=${total.toStringAsFixed(2)}&cu=INR',
                    version: QrVersions.auto,
                    size: 90 * scale,
                  ),
                  SizedBox(height: 2 * scale),
                  Text(
                    upiId!.trim(),
                    style: TextStyle(
                      fontSize: 10.5 * scale,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const DashedDivider(),

          // 9. Clean Footer Greetings & Dynamic AI Quote
          SizedBox(height: 4 * scale),
          Center(
            child: Column(
              children: [
                if (optQuote && quoteLine1 != null && quoteLine1!.isNotEmpty) ...[
                  Text(
                    quoteLine1!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.0 * scale,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (quoteLine2 != null && quoteLine2!.isNotEmpty) ...[
                    SizedBox(height: 2 * scale),
                    Text(
                      quoteLine2!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5 * scale,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                  SizedBox(height: 5 * scale),
                ],
                if (optFooter) ...[
                  Text(
                    footerMessage ?? 'Thank you! Visit again 🙏',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.0 * scale,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 2 * scale),
                  Text(
                    'धन्यवाद! फिर पधारें',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5 * scale,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 6 * scale),
        ],
      ),
    );
  }
}
