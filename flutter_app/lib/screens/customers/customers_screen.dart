import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../providers/shop_provider.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  void _showAddCustomerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('नया ग्राहक जोड़ें / Add Customer', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ग्राहक का नाम *')),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'मोबाइल नंबर')),
              const SizedBox(height: 10),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'पता / Address')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final newCust = Customer(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                shopId: 'shop1',
                name: name,
                phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                createdAt: DateTime.now(),
              );

              await context.read<CustomerProvider>().addCustomer(newCust);
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Customer'),
          ),
        ],
      ),
    );
  }

  void _showCustomerLedger(BuildContext context, Customer customer) {
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primarySurface,
              child: Text(customer.name.substring(0, 1).toUpperCase()),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (customer.phone != null) Text(customer.phone!, style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: customer.balance > 0 ? AppColors.error.withOpacity(0.1) : AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: customer.balance > 0 ? AppColors.error.withOpacity(0.3) : AppColors.primary.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      customer.balance > 0 ? 'कुल बकाया उधार (Due Balance)' : 'कोई उधार नहीं (Clear)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: customer.balance > 0 ? AppColors.error : AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(customer.balance),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: customer.balance > 0 ? AppColors.error : AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action: Receive Payment (रुपया जमा करें)
              if (customer.balance > 0) ...[
                const Text('रुपया प्राप्त / Receive Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    hintText: 'जमा राशि दर्ज करें',
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('जमा दर्ज करें (Record Payment)'),
                  onPressed: () async {
                    final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                    if (amt <= 0) return;
                    await context.read<CustomerProvider>().recordPayment(customer.id, amt);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${CurrencyFormatter.format(amt)} जमा हो गए')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),

                // WhatsApp Reminder
                if (customer.phone != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.message, size: 16, color: Colors.green),
                    label: const Text('WhatsApp Reminder भेजें', style: TextStyle(color: Colors.green)),
                    onPressed: () async {
                      final shop = context.read<ShopProvider>().shop;
                      final text = 'नमस्ते ${customer.name} जी, आपके ${shop.name} में ${CurrencyFormatter.format(customer.balance)} रुपये का बकाया है। कृपया भुगतान कर दें। धन्यवाद!';
                      final uri = Uri.parse('https://wa.me/91${customer.phone}?text=${Uri.encodeComponent(text)}');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
            label: const Text('ग्राहक हटाएं (Delete)', style: TextStyle(color: AppColors.error, fontSize: 12)),
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDeleteCustomer(context, customer);
            },
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _confirmDeleteCustomer(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ग्राहक हटाएं / Delete Customer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'क्या आप "${customer.name}" को खाता सूची से डिलीट करना चाहते हैं?',
              style: const TextStyle(fontSize: 14),
            ),
            if (customer.balance > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'सावधान! इस ग्राहक पर ${CurrencyFormatter.format(customer.balance)} का उधार बकाया है। डिलीट करने पर यह खाता हट जाएगा।',
                        style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await context.read<CustomerProvider>().deleteCustomer(customer.id);
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.error,
                    content: Text('${customer.name} को खाता से डिलीट कर दिया गया'),
                  ),
                );
              }
            },
            child: const Text('हाँ, डिलीट करें', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final custProvider = context.watch<CustomerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ग्राहक खाता / Khata Ledger', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Customer',
            onPressed: () => _showAddCustomerDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Total Udhar Summary Banner
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade700, Colors.deepOrange.shade800],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepOrange.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('कुल मार्केट उधार / Total Udhar', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(custProvider.totalUdhar),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${custProvider.customers.length} ग्राहक',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ग्राहक का नाम या फोन नंबर खोजें...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (q) => custProvider.setSearchQuery(q),
            ),
          ),
          const SizedBox(height: 8),

          // Customers List
          Expanded(
            child: custProvider.filteredCustomers.isEmpty
                ? const Center(child: Text('कोई ग्राहक नहीं मिला', style: TextStyle(color: AppColors.lightTextSecondary)))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: custProvider.filteredCustomers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final customer = custProvider.filteredCustomers[i];

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: customer.balance > 0 ? AppColors.error.withOpacity(0.15) : AppColors.primarySurface,
                            child: Text(
                              customer.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: customer.balance > 0 ? AppColors.error : AppColors.primary,
                              ),
                            ),
                          ),
                          title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(customer.phone ?? 'No mobile number'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(customer.balance),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: customer.balance > 0 ? AppColors.error : AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    customer.balance > 0 ? 'उधार बकाया' : 'क्लियर',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: customer.balance > 0 ? AppColors.error : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20, color: AppColors.lightTextSecondary),
                                padding: EdgeInsets.zero,
                                onSelected: (val) {
                                  if (val == 'ledger') {
                                    _showCustomerLedger(context, customer);
                                  } else if (val == 'delete') {
                                    _confirmDeleteCustomer(context, customer);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'ledger',
                                    child: Row(
                                      children: [
                                        Icon(Icons.menu_book, size: 18),
                                        SizedBox(width: 8),
                                        Text('खाता देखें (Ledger)'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                        SizedBox(width: 8),
                                        Text('ग्राहक हटाएं (Delete)', style: TextStyle(color: AppColors.error)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => _showCustomerLedger(context, customer),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
