import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/cart_item.dart';

/// Thermal-style dashed divider line
class DashedDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const DashedDivider({
    super.key,
    this.height = 1,
    this.color = const Color(0x66000000),
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
          padding: const EdgeInsets.symmetric(vertical: 6),
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

/// A pixel-perfect Thermal Invoice Receipt widget matching physical POS printouts
class BillReceiptCard extends StatelessWidget {
  final String shopName;
  final String? shopAddress;
  final String? shopPhone;
  final String? shopEmail;
  final String? gstin;
  final String billNo;
  final String dateString;
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
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    required this.total,
    required this.paid,
    this.due = 0.0,
    required this.paymentMode,
    this.footerMessage,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate total quantity
    double totalQty = 0;
    for (final it in items) {
      totalQty += it.qty;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Store Header
          Center(
            child: Column(
              children: [
                Text(
                  shopName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    height: 1.2,
                  ),
                ),
                if (shopAddress != null && shopAddress!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      shopAddress!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ),
                if (shopPhone != null && shopPhone!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      shopPhone!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ),
                if (shopEmail != null && shopEmail!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      shopEmail!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ),
                if (gstin != null && gstin!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      'GSTIN: $gstin',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ),
                const SizedBox(height: 6),
                const Text(
                  'INVOICE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Date & Invoice Number
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateString,
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
              ),
              Text(
                'Invoice : $billNo',
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
              ),
            ],
          ),

          const DashedDivider(),

          // Table Header: Item | Qty | Rate | Total
          const Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'Item',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Qty',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Rate',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Total',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),

          const DashedDivider(),

          // Line Items
          ...items.map((item) {
            final qtyStr = item.qty % 1 == 0 ? item.qty.toInt().toString() : item.qty.toStringAsFixed(2);
            final rateStr = item.price % 1 == 0 ? item.price.toInt().toString() : item.price.toStringAsFixed(2);
            final totStr = item.total % 1 == 0 ? item.total.toInt().toString() : item.total.toStringAsFixed(2);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      item.name,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '$qtyStr${item.unit}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      rateStr,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      totStr,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
            );
          }),

          const DashedDivider(),

          // Right aligned Subtotal line
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Rs ${subtotal.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ),

          const DashedDivider(),

          // Items Count & Subtotal / Discount Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Items : ${items.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total Qty : ${totalQty % 1 == 0 ? totalQty.toInt() : totalQty.toStringAsFixed(2)} kg',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Sub Total. Rs ${subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                  ),
                  if (discount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Discount − Rs ${discount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const DashedDivider(),

          // Grand Total
          Center(
            child: Text(
              'Total  :  ${total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: Color(0xFF0F172A),
              ),
            ),
          ),

          const DashedDivider(),

          // Payment Mode
          Center(
            child: Column(
              children: [
                const Text(
                  'Payment Mode',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${paymentMode.toUpperCase()} : ${paid.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                ),
                if (due > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Due : Rs ${due.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Footer Greeting
          Center(
            child: Text(
              footerMessage ?? 'Thank you! Visit again 🙏',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}
