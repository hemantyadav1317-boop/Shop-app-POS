import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/contact_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/customer.dart';
import '../../data/models/sale.dart';
import '../../data/services/local_db_service.dart';
import '../../data/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/shop_provider.dart';
import '../main_shell.dart';
import 'add_customer_screen.dart';
import 'customer_details_screen.dart';
import '../../providers/locale_provider.dart';

class CustomersScreen extends StatefulWidget {
  final bool isMainTab;

  const CustomersScreen({super.key, this.isMainTab = false});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _sortOption = 'name_asc'; // 'name_asc', 'balance_desc', 'sale_desc'
  Map<String, double> _customerTotalSales = {};

  @override
  void initState() {
    super.initState();
    _loadCustomerSales();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerSales() async {
    try {
      final shop = context.read<ShopProvider>().shop;
      // 1. Instant local DB load (0ms)
      final localSales = await LocalDbService.instance.getSales(shop.id);
      _updateTotalsFromSales(localSales);

      // 2. Multi-device sync: fetch cloud sales so phone/tablet bills reflect in totals
      if (mounted) {
        final cloudSales = await SupabaseService.instance.getSales(shop.id);
        if (mounted && cloudSales.isNotEmpty) {
          _updateTotalsFromSales(cloudSales);
        }
      }
    } catch (_) {}
  }

  void _updateTotalsFromSales(List<Sale> sales) {
    final Map<String, double> totals = {};
    for (final s in sales) {
      if (s.customerId != null && s.customerId!.isNotEmpty) {
        totals[s.customerId!] = (totals[s.customerId!] ?? 0.0) + s.total;
      }
      if (s.customerPhone != null && s.customerPhone!.isNotEmpty) {
        totals[s.customerPhone!] = (totals[s.customerPhone!] ?? 0.0) + s.total;
      }
    }
    if (mounted) {
      setState(() {
        _customerTotalSales = totals;
      });
    }
  }

  double _getCustomerSales(Customer c) {
    if (_customerTotalSales.containsKey(c.id)) {
      return _customerTotalSales[c.id]!;
    }
    if (c.phone != null && _customerTotalSales.containsKey(c.phone!)) {
      return _customerTotalSales[c.phone!]!;
    }
    return 0.0;
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'C';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _loadFromContactsDirectly() async {
    SoundService.instance.playButtonClick();
    final res = await ContactService.pickContact();
    if (!mounted) return;
    if (res != null) {
      if (res.permissionDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('कॉन्टैक्ट चुनने के लिए कृपया सेटिंग्स में Contacts परमिशन चालू करें।'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddCustomerScreen(
            initialName: res.name,
            initialPhone: res.phone,
          ),
        ),
      ).then((added) {
        if (added == true) {
          final shop = context.read<ShopProvider>().shop;
          context.read<CustomerProvider>().loadCustomers(shop.id);
          _loadCustomerSales();
        }
      });
    }
  }

  void _showAddCustomerChoice(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'नया ग्राहक जोड़ें',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.perm_contact_calendar_rounded, color: Color(0xFF0284C7), size: 20),
              ),
              title: const Text(
                'Phone Contacts से जोड़ें',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'मोबाइल की फोनबुक से 1-टैप में चुनें',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              onTap: () {
                Navigator.pop(ctx);
                _loadFromContactsDirectly();
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
              ),
              title: const Text(
                'नया ग्राहक खुद लिखें',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'नाम, मोबाइल नंबर और उधारी दर्ज करें',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
                ).then((added) {
                  if (added == true) {
                    final shop = context.read<ShopProvider>().shop;
                    context.read<CustomerProvider>().loadCustomers(shop.id);
                    _loadCustomerSales();
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCustomerReport(List<Customer> list) async {
    SoundService.instance.playButtonClick();
    if (list.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('Customer Khata Report - ${DateTime.now().toLocal()}');
    buffer.writeln('--------------------------------------------------');
    double totalDue = 0.0;
    for (final c in list) {
      final saleAmt = _getCustomerSales(c);
      totalDue += c.balance;
      buffer.writeln('${c.name} | Phone: ${c.phone ?? "N/A"} | Due: ₹${c.balance.toStringAsFixed(2)} | Total Sales: ₹${saleAmt.toStringAsFixed(2)}');
    }
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('Total Customers: ${list.length} | Total Due: ₹${totalDue.toStringAsFixed(2)}');

    try {
      await Share.share(buffer.toString(), subject: 'Customer Khata Report');
    } catch (_) {}
  }

  Future<void> _sendWhatsAppReminder(BuildContext context, Customer customer) async {
    final phone = customer.phone;
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${customer.name} का कोई फ़ोन नंबर दर्ज नहीं है।')),
      );
      return;
    }

    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length == 10) clean = '91$clean';

    final shop = context.read<ShopProvider>().shop;
    final dueAmt = customer.balance.toStringAsFixed(2);
    final shopName = shop.name;
    final upiId = (shop.upiId != null && shop.upiId!.trim().isNotEmpty) ? shop.upiId!.trim() : null;
    final upiPayee = (shop.upiPayeeName != null && shop.upiPayeeName!.trim().isNotEmpty)
        ? shop.upiPayeeName!.trim()
        : shopName;

    String upiPaymentBlock = '';
    if (upiId != null) {
      final upiUri = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(upiPayee)}&am=$dueAmt&cu=INR&tn=${Uri.encodeComponent("Khata Payment $shopName")}';
      upiPaymentBlock = '\n\n💳 *UPI ID:* $upiId\n\n⚡ *PhonePe/GPay/Paytm से चुकाने के लिए यहाँ टैप करें:*\n👉 $upiUri';
    }

    final phoneLine = (shop.phone != null && shop.phone!.isNotEmpty) ? '📞 ${shop.phone!}\n' : '';
    final msg = '🏪 *$shopName*\n'
        '$phoneLine'
        '----------------------------------\n'
        'नमस्ते *${customer.name}* जी 🙏,\n\n'
        'आपकी दुकान का खाता विवरण:\n'
        '💰 *कुल बकाया (Due Balance): ₹$dueAmt*'
        '$upiPaymentBlock\n\n'
        'कृपया समय पर भुगतान करने में सहयोग करें।\n'
        'धन्यवाद! 🙏';

    final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openRapidFireReminderDialog(BuildContext context, List<Customer> dueCustomers) {
    SoundService.instance.playButtonClick();
    final Set<String> sentIds = {};
    String filterMode = 'all'; // 'all', 'unsent', 'sent'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final totalDue = dueCustomers.fold<double>(0.0, (sum, c) => sum + c.balance);
          final unsent = dueCustomers.where((c) => !sentIds.contains(c.id)).toList();
          final progressPercent = dueCustomers.isEmpty ? 0.0 : (sentIds.length / dueCustomers.length);

          final displayedCustomers = dueCustomers.where((c) {
            if (filterMode == 'unsent') return !sentIds.contains(c.id);
            if (filterMode == 'sent') return sentIds.contains(c.id);
            return true;
          }).toList();

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.82,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -6)),
              ],
            ),
            child: Column(
              children: [
                // Header bar handle
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Top Header Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 12, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  'उधारी वसूली रिमाइंडर',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'WhatsApp',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${dueCustomers.length} ग्राहक • कुल बकाया: ${CurrencyFormatter.format(totalDue)}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Progress Indicator Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            sentIds.length == dueCustomers.length
                                ? Icons.check_circle_rounded
                                : Icons.pending_actions_rounded,
                            color: sentIds.length == dueCustomers.length
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF2563EB),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'प्रोग्रेस: ${sentIds.length} / ${dueCustomers.length} भेजे गए (${(progressPercent * 100).toInt()}%)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          const Spacer(),
                          if (unsent.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${unsent.length} बाकी',
                                style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          minHeight: 6,
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            sentIds.length == dueCustomers.length ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Reassurance Mini Info Note
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.flash_on_rounded, color: Color(0xFF16A34A), size: 14),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '1-टैप में ग्राहक का नाम, बकाया राशि और सीधे UPI पेमेंट लिंक WhatsApp पर लोड हो जाता है।',
                          style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

                // Filter Chips Row (सभी | बाकी | भेजे गए)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('सभी (${dueCustomers.length})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        selected: filterMode == 'all',
                        onSelected: (_) => setSheetState(() => filterMode = 'all'),
                        selectedColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('बाकी (${unsent.length})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        selected: filterMode == 'unsent',
                        onSelected: (_) => setSheetState(() => filterMode = 'unsent'),
                        selectedColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: filterMode == 'unsent' ? const Color(0xFFDC2626) : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('भेजे गए (${sentIds.length})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        selected: filterMode == 'sent',
                        onSelected: (_) => setSheetState(() => filterMode = 'sent'),
                        selectedColor: const Color(0xFF16A34A).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: filterMode == 'sent' ? const Color(0xFF15803D) : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1),

                // Customer List
                Expanded(
                  child: displayedCustomers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                filterMode == 'sent' ? Icons.mark_chat_read_rounded : Icons.check_circle_outline_rounded,
                                size: 40,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                filterMode == 'sent'
                                    ? 'अभी तक किसी को नहीं भेजा गया'
                                    : 'इस फ़िल्टर में कोई ग्राहक नहीं है',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          itemCount: displayedCustomers.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (cContext, i) {
                            final c = displayedCustomers[i];
                            final isSent = sentIds.contains(c.id);

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSent
                                    ? (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC))
                                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSent
                                      ? Colors.transparent
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                boxShadow: isSent
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Row(
                                children: [
                                  // Initials Avatar
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isSent
                                        ? Colors.grey.shade400
                                        : const Color(0xFFEF4444).withValues(alpha: 0.15),
                                    child: Text(
                                      c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isSent ? Colors.white : const Color(0xFFDC2626),
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isSent ? Colors.grey : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          c.phone ?? 'फ़ोन नंबर नहीं है',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isSent ? Colors.grey.shade400 : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormatter.format(c.balance),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: isSent ? Colors.grey : const Color(0xFFDC2626),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      if (isSent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 13),
                                              SizedBox(width: 3),
                                              Text(
                                                'भेजा गया',
                                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF16A34A),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            elevation: 1,
                                          ),
                                          icon: const Icon(Icons.chat_bubble_rounded, size: 12),
                                          label: const Text('तगादा भेजें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                          onPressed: () async {
                                            SoundService.instance.playButtonClick();
                                            await _sendWhatsAppReminder(context, c);
                                            setSheetState(() {
                                              sentIds.add(c.id);
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Bottom Floating Action Button: Send Next Unsent
                if (unsent.isNotEmpty)
                  SafeArea(
                    top: false,
                    bottom: true,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.fast_forward_rounded, size: 20),
                          label: Text(
                            'अगले ग्राहक को भेजें: ${unsent.first.name} (${CurrencyFormatter.format(unsent.first.balance)})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () async {
                            final nextCust = unsent.first;
                            SoundService.instance.playButtonClick();
                            await _sendWhatsAppReminder(context, nextCust);
                            setSheetState(() {
                              sentIds.add(nextCust.id);
                            });
                          },
                        ),
                      ),
                    ),
                  )
                else
                  SafeArea(
                    top: false,
                    bottom: true,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'सभी उधारी ग्राहकों को रिमाइंडर भेजा जा चुका है! ✓',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A), fontSize: 13.5),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteCustomer(BuildContext context, Customer customer) {
    final auth = context.read<AuthProvider>();
    if (auth.isStaffSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('सुरक्षा नियम: केवल दुकान मालिक ग्राहक को डिलीट कर सकते हैं।'),
        ),
      );
      return;
    }
    if (customer.balance > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.error, size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text('खाता नहीं हटाया जा सकता', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ग्राहक "${customer.name}" के खाते में ${CurrencyFormatter.format(customer.balance)} का बकाया (उधार) शेष है।',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'खाता हटाने से पहले कृपया पूरा बकाया शून्य (₹0) करें। उधार शेष रहते खाता डिलीट नहीं किया जा सकता।',
                        style: TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('समझ गया (OK)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete Customer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${customer.name}" from customer records?',
          style: const TextStyle(fontSize: 14),
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
                    content: Text('${customer.name} deleted'),
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final custProvider = context.watch<CustomerProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHindi = context.watch<LocaleProvider>().localeCode == 'hi';

    final dueCustomers = custProvider.customers.where((c) => c.balance > 0).toList();
    dueCustomers.sort((a, b) => b.balance.compareTo(a.balance));
    final totalDueAmount = dueCustomers.fold<double>(0.0, (sum, c) => sum + c.balance);

    List<Customer> list = List.from(custProvider.filteredCustomers);
    if (_sortOption == 'name_asc') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sortOption == 'balance_desc') {
      list.sort((a, b) => b.balance.compareTo(a.balance));
    } else if (_sortOption == 'sale_desc') {
      list.sort((a, b) => _getCustomerSales(b).compareTo(_getCustomerSales(a)));
    }

    final canPop = !widget.isMainTab && Navigator.canPop(context);

    // Color palette for customer initials squircles
    final pastelColors = [
      {'bg': const Color(0xFFFFEDD5), 'text': const Color(0xFFC2410C)}, // Peach / Orange
      {'bg': const Color(0xFFDBEAFE), 'text': const Color(0xFF1D4ED8)}, // Blue
      {'bg': const Color(0xFFDCFCE7), 'text': const Color(0xFF15803D)}, // Green
      {'bg': const Color(0xFFF3E8FF), 'text': const Color(0xFF7E22CE)}, // Purple
      {'bg': const Color(0xFFCCFBF1), 'text': const Color(0xFF0F766E)}, // Teal
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isHindi ? 'ग्राहक खाता' : 'Customer Management',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white, letterSpacing: 0.3),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFF5722),
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () {
                  SoundService.instance.playButtonClick();
                  Navigator.pop(context);
                },
              )
            : IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                tooltip: 'मेन्यू',
                onPressed: () {
                  SoundService.instance.playButtonClick();
                  MainShell.openDrawer(context);
                },
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () async {
              SoundService.instance.playButtonClick();
              final shop = context.read<ShopProvider>().shop;
              await context.read<CustomerProvider>().loadCustomers(shop.id);
              await _loadCustomerSales();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 850;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 850 : double.infinity),
              child: Column(
                children: [
                  // Top Search & Filter Bar matching Image 2
                  Container(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        // Rounded Pill Search Box
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              decoration: InputDecoration(
                                hintText: isHindi ? 'नाम या मोबाइल नंबर खोजें...' : 'Contact/Name...',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                              ),
                              onChanged: (q) => custProvider.setSearchQuery(q),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Sort Button
                        PopupMenuButton<String>(
                          tooltip: 'Sort Customers',
                          offset: const Offset(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          elevation: 6,
                          icon: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.sort_rounded, size: 20, color: Color(0xFF475569)),
                          ),
                          initialValue: _sortOption,
                          onSelected: (val) {
                            SoundService.instance.playButtonClick();
                            setState(() => _sortOption = val);
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'name_asc',
                              height: 42,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      isHindi ? 'नाम अनुसार (A-Z)' : 'Sort by Name',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: _sortOption == 'name_asc' ? FontWeight.bold : FontWeight.w500,
                                        color: _sortOption == 'name_asc' ? const Color(0xFFFF5722) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                  if (_sortOption == 'name_asc')
                                    const Icon(Icons.check_rounded, color: Color(0xFFFF5722), size: 18),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(height: 1),
                            PopupMenuItem(
                              value: 'balance_desc',
                              height: 42,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      isHindi ? 'उधारी अनुसार (अधिक से कम)' : 'Sort by Credit',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: _sortOption == 'balance_desc' ? FontWeight.bold : FontWeight.w500,
                                        color: _sortOption == 'balance_desc' ? const Color(0xFFFF5722) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                  if (_sortOption == 'balance_desc')
                                    const Icon(Icons.check_rounded, color: Color(0xFFFF5722), size: 18),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(height: 1),
                            PopupMenuItem(
                              value: 'sale_desc',
                              height: 42,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      isHindi ? 'बिक्री अनुसार (अधिक से कम)' : 'Sort by Sales',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: _sortOption == 'sale_desc' ? FontWeight.bold : FontWeight.w500,
                                        color: _sortOption == 'sale_desc' ? const Color(0xFFFF5722) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                  if (_sortOption == 'sale_desc')
                                    const Icon(Icons.check_rounded, color: Color(0xFFFF5722), size: 18),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Load from Phone Contacts Quick Button
                        IconButton(
                          icon: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5722).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person_add_alt_1_rounded, size: 20, color: Color(0xFFFF5722)),
                          ),
                          tooltip: isHindi ? 'फोनबुक से ग्राहक जोड़ें' : 'Load from Contacts',
                          onPressed: _loadFromContactsDirectly,
                        ),

                        // Export Report Button
                        IconButton(
                          icon: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.download_rounded, size: 20, color: Color(0xFF475569)),
                          ),
                          tooltip: isHindi ? 'रिपोर्ट डाउनलोड करें' : 'Export List',
                          onPressed: () => _exportCustomerReport(list),
                        ),
                      ],
                    ),
                  ),

                  // Smart Due Reminder Banner matching Image 2
                  if (dueCustomers.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2E1010) : const Color(0xFFFFF3ED),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFFD7C4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Bell with Red Dot
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEDD5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFEA580C), size: 20),
                              ),
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDC2626),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isHindi
                                      ? '${dueCustomers.length} ग्राहकों पर उधारी बाकी है'
                                      : '${dueCustomers.length} Customers have pending due',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                    ),
                                    children: [
                                      TextSpan(text: isHindi ? 'कुल बकाया: ' : 'Total Due: '),
                                      TextSpan(
                                        text: CurrencyFormatter.format(totalDueAmount),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 1,
                              ),
                              icon: const Icon(Icons.send_rounded, size: 13),
                              label: Text(
                                isHindi ? 'मागा भेजें' : 'Send Reminder',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                              onPressed: () {
                                SoundService.instance.playButtonClick();
                                _openRapidFireReminderDialog(context, dueCustomers);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Customers List matching Image 2
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        final shop = context.read<ShopProvider>().shop;
                        await context.read<CustomerProvider>().loadCustomers(shop.id);
                        await _loadCustomerSales();
                      },
                      child: list.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 120),
                                Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.4)),
                                      const SizedBox(height: 8),
                                      Text(
                                        isHindi ? 'कोई ग्राहक नहीं मिला' : 'No customers found',
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
                              itemCount: list.length,
                              itemBuilder: (context, i) {
                                final customer = list[i];
                                final initials = _getInitials(customer.name);
                                final totalSale = _getCustomerSales(customer);
                                final hasDue = customer.balance > 0.009;
                                final colorIndex = i % pastelColors.length;
                                final colorScheme = pastelColors[colorIndex];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () {
                                        SoundService.instance.playButtonClick();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CustomerDetailsScreen(customer: customer),
                                          ),
                                        ).then((_) {
                                          if (!mounted) return;
                                          final shop = context.read<ShopProvider>().shop;
                                          context.read<CustomerProvider>().loadCustomers(shop.id);
                                          _loadCustomerSales();
                                        });
                                      },
                                      onLongPress: () {
                                        SoundService.instance.playButtonClick();
                                        _confirmDeleteCustomer(context, customer);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            // 1. Left Initials Box
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: isDark ? colorScheme['bg']!.withValues(alpha: 0.2) : colorScheme['bg'],
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                initials,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: colorScheme['text'],
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),

                                            // 2. Middle Info Column: Name, Phone, Total Sale
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    customer.name,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF64748B)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        customer.phone ?? '--',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Color(0xFF64748B),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.monetization_on_rounded, size: 12, color: Color(0xFFD97706)),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          'Total Sale: ₹${totalSale.toStringAsFixed(2)}',
                                                          style: const TextStyle(
                                                            fontSize: 11.5,
                                                            color: Color(0xFF64748B),
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // 3. Right Credit Amount Pill & Arrow
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Text(
                                                  'Credit Amount',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    color: Color(0xFF94A3B8),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: hasDue
                                                        ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEE2E2))
                                                        : (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFFEF3C7)),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    '₹ ${customer.balance.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: hasDue ? const Color(0xFFDC2626) : const Color(0xFF92400E),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      // Central Floating Action Button (+) with Orange Glow
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            SoundService.instance.playButtonClick();
            _showAddCustomerChoice(context);
          },
          backgroundColor: const Color(0xFFFF5722),
          elevation: 2,
          child: const Icon(Icons.add, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}
