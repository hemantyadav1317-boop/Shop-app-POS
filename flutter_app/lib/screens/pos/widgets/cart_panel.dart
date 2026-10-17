import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/customer.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../providers/customer_provider.dart';
import 'package:shop_pos/screens/widgets/product_image_view.dart';
import 'payment_dialog.dart';

class CartPanel extends StatefulWidget {
  final VoidCallback? onCompleted;

  const CartPanel({super.key, this.onCompleted});

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  final TextEditingController _discountController = TextEditingController();

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  void _showCustomerPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final custProvider = ctx.watch<CustomerProvider>();
        final cart = ctx.read<CartProvider>();

        return Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 450),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ग्राहक चुनें / Select Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton.icon(
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('New'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAddCustomerDialog(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'नाम या मोबाइल नंबर से खोजें...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (q) => custProvider.setSearchQuery(q),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: const Text('Walk-in Customer (नकद ग्राहक)'),
                selected: cart.customer == null,
                onTap: () {
                  cart.setCustomer(null);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: custProvider.filteredCustomers.length,
                  itemBuilder: (context, i) {
                    final cust = custProvider.filteredCustomers[i];
                    final isSelected = cart.customer?.id == cust.id;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected ? AppColors.primary : AppColors.lightMuted,
                        child: Text(cust.name.substring(0, 1).toUpperCase()),
                      ),
                      title: Text(cust.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(cust.phone ?? 'No phone'),
                      trailing: cust.balance > 0
                          ? Text(
                              'उधार: ${CurrencyFormatter.format(cust.balance)}',
                              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12),
                            )
                          : null,
                      onTap: () {
                        cart.setCustomer(cust);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('नया ग्राहक जोड़ें / New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'नाम / Name')),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'मोबाइल नंबर / Phone')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final cust = await context.read<CustomerProvider>().addCustomer(
                    Customer(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      shopId: 'shop1',
                      name: name,
                      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      createdAt: DateTime.now(),
                    ),
                  );
              if (context.mounted) {
                context.read<CartProvider>().setCustomer(cust);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save & Select'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Customer Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showCustomerPicker(context),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: cart.customer != null ? AppColors.primarySurface : AppColors.lightMuted,
                        child: Icon(
                          cart.customer != null ? Icons.person : Icons.person_outline,
                          size: 18,
                          color: cart.customer != null ? AppColors.primary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cart.customer?.name ?? 'Walk-in Customer',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              cart.customer?.phone ?? 'Click to select customer',
                              style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz, size: 14),
                label: const Text('Change', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _showCustomerPicker(context),
              ),
            ],
          ),
        ),

        // Cart Line Items List
        Expanded(
          child: cart.lines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 48, color: AppColors.lightTextSecondary.withOpacity(0.5)),
                      const SizedBox(height: 8),
                      const Text(
                        'कार्ट खाली है\nसामान पर टैप करके बिल में जोड़ें',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.lines.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = cart.lines[i];
                    final step = item.unit.toLowerCase() == 'kg' ? 0.25 : 1.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          ProductImageView(
                            imageUrl: item.imageUrl,
                            fallbackIcon: item.icon,
                            size: 38,
                            borderRadius: 6,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${CurrencyFormatter.format(item.price)} / ${item.unit}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                                ),
                              ],
                            ),
                          ),
                          // Qty buttons
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  cart.setQty(item.productId, item.name, item.qty - step);
                                },
                              ),
                              Container(
                                constraints: const BoxConstraints(minWidth: 36),
                                alignment: Alignment.center,
                                child: Text(
                                  item.qty % 1 == 0 ? item.qty.toInt().toString() : item.qty.toStringAsFixed(2),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  cart.setQty(item.productId, item.name, item.qty + step);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormatter.format(item.total),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Bottom Billing Summary
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                offset: const Offset(0, -2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:', style: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary)),
                  Text(CurrencyFormatter.format(cart.subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Discount (छूट):', style: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary)),
                  SizedBox(
                    width: 90,
                    height: 32,
                    child: TextField(
                      controller: _discountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.end,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        prefixText: '₹ ',
                        hintText: '0',
                      ),
                      onChanged: (val) {
                        final d = double.tryParse(val) ?? 0.0;
                        cart.setDiscount(d);
                      },
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payable / कुल राशि:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    CurrencyFormatter.format(cart.total),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action Buttons: Clear, Hold, Pay
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    tooltip: 'Clear Cart',
                    onPressed: cart.lines.isEmpty ? null : cart.clear,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Hold Bill', style: TextStyle(fontSize: 12)),
                    onPressed: cart.lines.isEmpty
                        ? null
                        : () {
                            cart.saveCurrentCart();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('बिल सेव (Park) कर दिया गया')),
                            );
                          },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: cart.lines.isEmpty
                          ? null
                          : () {
                              showDialog(
                                context: context,
                                builder: (_) => PaymentDialog(
                                  onSaleCompleted: () {
                                    widget.onCompleted?.call();
                                  },
                                ),
                              );
                            },
                      child: Text(
                        'BILL · ${CurrencyFormatter.format(cart.total)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
