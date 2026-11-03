import 'package:flutter/foundation.dart';
import '../data/models/customer.dart';
import '../data/services/supabase_service.dart';

class CustomerProvider extends ChangeNotifier {
  List<Customer> _customers = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  double get totalUdhar => _customers.fold(0.0, (sum, c) => sum + (c.balance > 0 ? c.balance : 0.0));

  List<Customer> get filteredCustomers {
    if (_searchQuery.trim().isEmpty) return _customers;
    final term = _searchQuery.trim().toLowerCase();
    return _customers.where((c) {
      return c.name.toLowerCase().contains(term) || (c.phone != null && c.phone!.contains(term));
    }).toList();
  }

  Future<void> loadCustomers(String shopId) async {
    _isLoading = true;
    notifyListeners();

    _customers = await SupabaseService.instance.getCustomers(shopId);
    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  Future<Customer> addCustomer(Customer c) async {
    final created = await SupabaseService.instance.addCustomer(c);
    _customers.add(created);
    notifyListeners();
    return created;
  }

  Future<void> recordPayment(String customerId, double amountPaid, {String shopId = '', String mode = 'cash', String? note}) async {
    final idx = _customers.indexWhere((c) => c.id == customerId);
    if (idx != -1) {
      final current = _customers[idx];
      final newBalance = current.balance - amountPaid;
      final updated = current.copyWith(balance: newBalance > 0 ? newBalance : 0.0);
      _customers[idx] = updated;
      notifyListeners();
      await SupabaseService.instance.recordCustomerPayment(
        shopId: shopId.isNotEmpty ? shopId : current.shopId,
        customerId: customerId,
        amount: amountPaid,
        mode: mode,
        note: note,
      );
    }
  }

  Future<void> setCreditLimit(String customerId, double limit) async {
    final idx = _customers.indexWhere((c) => c.id == customerId);
    if (idx != -1) {
      final current = _customers[idx];
      final updated = current.copyWith(creditLimit: limit);
      _customers[idx] = updated;
      notifyListeners();
      await SupabaseService.instance.updateCustomerCreditLimit(customerId, limit);
    }
  }

  Future<void> addCredit(String customerId, double creditAmount) async {
    final idx = _customers.indexWhere((c) => c.id == customerId);
    if (idx != -1) {
      final current = _customers[idx];
      final newBalance = current.balance + creditAmount;
      final updated = current.copyWith(balance: newBalance);
      _customers[idx] = updated;
      notifyListeners();
      await SupabaseService.instance.updateCustomerBalance(customerId, updated.balance);
    }
  }

  Future<void> updateCustomer(Customer updated) async {
    final idx = _customers.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      _customers[idx] = updated;
      notifyListeners();
      await SupabaseService.instance.updateCustomer(updated);
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    _customers.removeWhere((c) => c.id == customerId);
    notifyListeners();
    await SupabaseService.instance.deleteCustomer(customerId);
  }
}
