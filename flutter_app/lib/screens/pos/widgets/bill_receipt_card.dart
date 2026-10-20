import 'package:flutter/material.dart';
import '../../../../data/models/cart_item.dart';

/// Clean thermal dashed divider line
class DashedDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const DashedDivider({
    super.key,
    this.height = 1.2,
    this.color = Colors.black,
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
/// Fixed at 384px width to utilize 100% of standard 58mm thermal printer roll width
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
    final cleanBillNo = billNo.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');

    return Container(
      width: 384, // Exact 58mm POS thermal dot width
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Store Header (Centered, Large Bold)
          Center(
            child: Column(
              children: [
                Text(
                  shopName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    color: Colors.black,
                    height: 1.15,
                  ),
                ),
                if (shopAddress != null && shopAddress!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    shopAddress!.trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                      height: 1.2,
                    ),
                  ),
                ],
                if (shopPhone != null && shopPhone!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Tel: ${shopPhone!.trim()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
                if (shopEmail != null && shopEmail!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Email: ${shopEmail!.trim()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ],
                if (gstin != null && gstin!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'GSTIN: ${gstin!.trim()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 2. INVOICE Title
          const Center(
            child: Text(
              'INVOICE',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: Colors.black,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // 3. Date & Invoice No
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateString,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                'Invoice $cleanBillNo',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          if (customerName != null && customerName!.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Customer: ${customerName!.trim()}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black),
                ),
                if (customerPhone != null && customerPhone!.trim().isNotEmpty)
                  Text(
                    customerPhone!.trim(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black),
                  ),
              ],
            ),
          ],

          const DashedDivider(),

          // 4. Items Table Header
          const Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'ITEM',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.black),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'QTY',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.black),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'PRICE',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.black),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'TOTAL',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.black),
                ),
              ),
            ],
          ),

          const DashedDivider(),

          // 5. Item Rows (Matching lower clean receipt: Name on line 1, Qty/Rate/Total on line 2)
          ...items.map((item) {
            final qtyStr = item.qty % 1 == 0 ? item.qty.toInt().toString() : item.qty.toStringAsFixed(2);
            final priceStr = item.price % 1 == 0 ? item.price.toInt().toString() : item.price.toStringAsFixed(2);
            final totStr = item.total % 1 == 0 ? item.total.toInt().toString() : item.total.toStringAsFixed(2);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 1.5),
                  Row(
                    children: [
                      const Expanded(flex: 3, child: SizedBox()),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '$qtyStr${item.unit}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          priceStr,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          totStr,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black),
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
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              Text(
                'Sub Total : Rs ${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black),
              ),
            ],
          ),

          if (discount > 0) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Discount :',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black),
                ),
                Text(
                  '- Rs ${discount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.black),
                ),
              ],
            ),
          ],

          const DashedDivider(),

          // 7. GRAND TOTAL (Huge & Bold, matching user photo)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: Text(
                'Total : Rs ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 23,
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
                const Text(
                  'Payment Mode',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatPaymentMode(paymentMode)} : ${paid.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black),
                ),
                if (due > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Due : Rs ${due.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                ],
              ],
            ),
          ),

          const DashedDivider(),

          // 9. Clean Footer Greetings
          const SizedBox(height: 4),
          Center(
            child: Column(
              children: [
                Text(
                  footerMessage ?? 'Thank you! Visit again 🙏',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black),
                ),
                const SizedBox(height: 2),
                const Text(
                  'धन्यवाद! फिर पधारें',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
