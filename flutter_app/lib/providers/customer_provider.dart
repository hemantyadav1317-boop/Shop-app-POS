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

  Future<void> recordPayment(String customerId, double amountPaid) async {
    final idx = _customers.indexWhere((c) => c.id == customerId);
    if (idx != -1) {
      final current = _customers[idx];
      final newBalance = current.balance - amountPaid;
      final updated = current.copyWith(balance: newBalance > 0 ? newBalance : 0.0);
      _customers[idx] = updated;
      notifyListeners();
      await SupabaseService.instance.updateCustomerBalance(customerId, updated.balance);
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    _customers.removeWhere((c) => c.id == customerId);
    notifyListeners();
    await SupabaseService.instance.deleteCustomer(customerId);
  }
}
