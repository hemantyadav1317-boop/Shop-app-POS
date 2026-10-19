import 'package:flutter/material.dart';
import '../../../../data/models/cart_item.dart';

/// Thermal-style dashed divider line (black dots for thermal printers)
class DashedDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const DashedDivider({
    super.key,
    this.height = 1,
    this.color = Colors.black87,
    this.dashWidth = 4.0,
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

/// A pixel-perfect Thermal Invoice Receipt widget matching the Indian POS receipt format
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

  String _formatBillNo(String no) {
    final cleaned = no.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isNotEmpty && cleaned.length < 6) {
      return cleaned.padLeft(6, '0');
    }
    return no;
  }

  String _formatPaymentMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'online':
        return 'UPI / Online';
      case 'credit':
        return 'उधार (Khata)';
      case 'split':
        return 'Split (नकद + ऑनलाइन)';
      default:
        return 'नकद (Cash)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedBill = _formatBillNo(billNo);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Store Header with Store Icon
          Center(
            child: Column(
              children: [
                const Icon(Icons.storefront, size: 36, color: Colors.black87),
                const SizedBox(height: 4),
                Text(
                  shopName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Colors.black,
                  ),
                ),
                if (shopAddress != null && shopAddress!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      shopAddress!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                  ),
                if (shopPhone != null && shopPhone!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      'Mo. ${shopPhone!}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                if (gstin != null && gstin!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      'GSTIN: $gstin',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Colors.black87),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 6),
          const DashedDivider(),

          // 2. Receipt Type Title: भुगतान रसीद / Payment Receipt
          Center(
            child: Column(
              children: const [
                Text(
                  'भुगतान रसीद',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Payment Receipt',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 3. Receipt Metadata with Aligned Colons
          _buildInfoRow('रसीद नं.', formattedBill),
          _buildInfoRow('दिनांक', dateString),
          if (customerName != null && customerName!.isNotEmpty)
            _buildInfoRow('ग्राहक नाम', customerName!),
          if (customerPhone != null && customerPhone!.isNotEmpty)
            _buildInfoRow('मोबाइल', customerPhone!),

          const DashedDivider(),

          // 4. Items Table (if items are present)
          if (items.isNotEmpty) ...[
            const Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text('सामान (Item)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('मात्रा', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('दर', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('रुपये', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ],
            ),
            const DashedDivider(),
            ...items.map((item) {
              final qtyStr = item.qty % 1 == 0 ? item.qty.toInt().toString() : item.qty.toStringAsFixed(2);
              final rateStr = item.price % 1 == 0 ? item.price.toInt().toString() : item.price.toStringAsFixed(2);
              final totStr = item.total % 1 == 0 ? item.total.toInt().toString() : item.total.toStringAsFixed(2);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        item.name,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '$qtyStr${item.unit}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        rateStr,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        '₹$totStr',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const DashedDivider(),
          ],

          // 5. Billing & Amount Breakdown Block (As per user's reference image)
          if (discount > 0)
            _buildAmountRow('छूट (Discount)', '₹${discount.toStringAsFixed(2)}', isNegative: true),

          _buildAmountRow('कुल राशि (Total)', '₹${total.toStringAsFixed(2)}', isBold: false),
          _buildAmountRow('जमा राशि (Paid)', '₹${paid.toStringAsFixed(2)}', isBold: false),

          const DashedDivider(),

          // 6. Highlighted Balance / Due Line
          _buildAmountRow(
            due > 0 ? 'शेष बकाया (Due)' : 'बकाया राशि',
            '₹${due.toStringAsFixed(2)}',
            isBold: true,
            fontSize: 14,
          ),

          const DashedDivider(),

          // 7. Payment Mode
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Text('भुगतान का तरीका : ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                Expanded(
                  child: Text(
                    _formatPaymentMode(paymentMode),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 8. Classic Centered Footer Ornament & Greetings (Matching Reference Image)
          Center(
            child: Column(
              children: [
                const Text(
                  'धन्यवाद!',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 2),
                Text(
                  footerMessage ?? 'आपका विश्वास ही हमारी पहचान है',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                // Decorative ornament line
                const Text(
                  '—— • ❖ • ——',
                  style: TextStyle(fontSize: 10, color: Colors.black54, letterSpacing: 2),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Thank You!',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const Text(
                  'Visit Again',
                  style: TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          const Text(' :  ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, String value, {bool isBold = false, bool isNegative = false, double fontSize = 12}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          const Text(' :  ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
                color: isNegative ? Colors.red.shade800 : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
