import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/customer.dart';
import '../../../../data/models/cart_item.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../providers/customer_provider.dart';
import '../../../../providers/shop_provider.dart';
import '../../../../providers/product_provider.dart';
import 'package:shop_pos/screens/widgets/product_image_view.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/contact_service.dart';
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
                  const Text('Select Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  hintText: 'Search by name or mobile...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (q) => custProvider.setSearchQuery(q),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: const Text('Walk-in Customer'),
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
                              'Due: ${CurrencyFormatter.format(cust.balance)}',
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

  void _showEditRateDialog(BuildContext context, CartItem item, CartProvider cart) {
    SoundService.instance.playButtonClick();
    final rateCtrl = TextEditingController(
      text: item.price % 1 == 0 ? item.price.toInt().toString() : item.price.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: Color(0xFF00875A), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Update Rate',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Current Rate: ₹${item.price} per ${item.unit}  •  Qty: ${item.qty} ${item.unit}',
              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rateCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'New Rate (₹ per ${item.unit}) *',
                prefixIcon: const Icon(Icons.currency_rupee),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00875A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final newRate = double.tryParse(rateCtrl.text.trim());
              if (newRate != null && newRate >= 0) {
                cart.setPrice(item.productId, item.name, newRate);
                SoundService.instance.playSuccess();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF00875A),
                    duration: const Duration(seconds: 2),
                    content: Text('\'${item.name}\' rate updated to ₹$newRate'),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final res = await ContactService.pickContact();
                    if (res != null) {
                      if (res.name.isNotEmpty) nameCtrl.text = res.name;
                      if (res.phone.isNotEmpty) phoneCtrl.text = res.phone;
                    }
                  },
                  icon: const Icon(Icons.perm_contact_calendar_outlined, size: 18),
                  label: const Text('Import from Contacts'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer Name *')),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number (Optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final shop = context.read<ShopProvider>().shop;
              final cust = await context.read<CustomerProvider>().addCustomer(
                    Customer(
                      id: const Uuid().v4(),
                      shopId: shop.id,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Auto-clear discount input if cart is empty and discount is reset
    if (cart.discount == 0 && cart.lines.isEmpty && _discountController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && cart.discount == 0 && cart.lines.isEmpty) {
          _discountController.clear();
        }
      });
    }

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
                        'Cart is empty\nTap items to add to bill',
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
                    final isDark = Theme.of(context).brightness == Brightness.dark;

                    return Dismissible(
                      key: ValueKey('cart_line_${item.productId ?? item.name}_$i'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 22),
                            SizedBox(width: 4),
                            Text(
                              'Remove',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      onDismissed: (_) {
                        SoundService.instance.playDelete();
                        cart.removeLine(item.productId, item.name);
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            duration: const Duration(milliseconds: 900),
                            content: Text('\'${item.name}\' removed from bill'),
                            action: SnackBarAction(
                              label: 'Undo',
                              textColor: Colors.amber,
                              onPressed: () => cart.addLine(item),
                            ),
                          ),
                        );
                      },
                      child: Padding(
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
                                  const SizedBox(height: 2),
                                  // Editable Rate with pencil icon
                                  InkWell(
                                    onTap: () => _showEditRateDialog(context, item, cart),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '₹${item.price.toStringAsFixed(item.price % 1 == 0 ? 0 : 2)}/${item.unit}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF00875A)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Qty buttons with High-Contrast Quantity Pill
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    if (item.qty <= step) {
                                      SoundService.instance.playDelete();
                                    } else {
                                      SoundService.instance.playClick();
                                    }
                                    cart.setQty(item.productId, item.name, item.qty - step);
                                  },
                                ),
                                Container(
                                  constraints: const BoxConstraints(minWidth: 46),
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF10B981) : const Color(0xFF00875A).withValues(alpha: 0.3),
                                      width: isDark ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Text(
                                    item.qty % 1 == 0 ? '${item.qty.toInt()} ${item.unit}' : '${item.qty.toStringAsFixed(2)} ${item.unit}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.5,
                                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF00875A),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    final shop = context.read<ShopProvider>().shop;
                                    final productProv = context.read<ProductProvider>();
                                    final prod = productProv.getProductById(item.productId);
                                    final nextQty = item.qty + step;

                                    if (prod != null && nextQty > prod.stock && !shop.allowNegativeStock) {
                                      SoundService.instance.playError();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppColors.error,
                                          duration: const Duration(seconds: 2),
                                          content: Text('⚠️ Maximum stock limit reached (${prod.stock} ${item.unit})!'),
                                        ),
                                      );
                                      return;
                                    }

                                    SoundService.instance.playProductAdd();
                                    cart.setQty(item.productId, item.name, nextQty);
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
                      ),
                    );
                  },
                ),
        ),

        // Bottom Billing Summary
        SafeArea(
          top: false,
          bottom: true,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
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
                  const Text('Total Items:', style: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary)),
                  Text(
                    '${cart.lines.length} ${cart.lines.length == 1 ? "Item" : "Items"} (${cart.totalQty % 1 == 0 ? cart.totalQty.toInt() : cart.totalQty.toStringAsFixed(2)} qty)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Discount:', style: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary)),
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
                  const Text('Total Payable:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    CurrencyFormatter.format(cart.total),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action Buttons: Clear, Hold, Bill / Print
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    tooltip: 'Clear Cart',
                    onPressed: cart.lines.isEmpty
                        ? null
                        : () {
                            SoundService.instance.playDelete();
                            cart.clear();
                            _discountController.clear();
                          },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Hold', style: TextStyle(fontSize: 12)),
                    onPressed: cart.lines.isEmpty
                        ? null
                        : () {
                            SoundService.instance.playButtonClick();
                            cart.saveCurrentCart();
                            _discountController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Bill saved and held')),
                            );
                          },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.print, size: 18, color: Colors.white),
                      label: Text(
                        'BILL / PRINT · ${CurrencyFormatter.format(cart.total)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                      onPressed: cart.lines.isEmpty
                          ? null
                          : () {
                              SoundService.instance.playButtonClick();
                              showDialog(
                                context: context,
                                builder: (_) => PaymentDialog(
                                  onSaleCompleted: () {
                                    _discountController.clear();
                                    widget.onCompleted?.call();
                                  },
                                ),
                              );
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ],
    );
  }
}
