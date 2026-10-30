import 'package:flutter/foundation.dart';
import '../data/models/cart_item.dart';
import '../data/models/customer.dart';
import '../core/services/sound_service.dart';

class SavedCart {
  final String id;
  final String time;
  final Customer? customer;
  final List<CartItem> items;
  final double discount;

  SavedCart({
    required this.id,
    required this.time,
    this.customer,
    required this.items,
    this.discount = 0.0,
  });
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _lines = [];
  Customer? _customer;
  double _discount = 0.0;
  final List<SavedCart> _savedCarts = [];

  List<CartItem> get lines => List.unmodifiable(_lines);
  Customer? get customer => _customer;
  double get discount => _discount;
  List<SavedCart> get savedCarts => List.unmodifiable(_savedCarts);

  int get itemCount => _lines.length;

  double get totalQty => _lines.fold(0.0, (sum, item) => sum + item.qty);

  double get subtotal => _lines.fold(0.0, (sum, item) => sum + item.total);

  double get total {
    final t = subtotal - _discount;
    return t > 0 ? t : 0.0;
  }

  void addLine(CartItem item) {
    final index = _lines.indexWhere(
      (line) => (line.productId != null && line.productId == item.productId) ||
          (line.productId == null && line.name.toLowerCase() == item.name.toLowerCase()),
    );

    if (index != -1) {
      // Update existing item quantity
      final existing = _lines[index];
      _lines[index] = existing.copyWith(
        qty: item.qty,
        price: item.price,
      );
    } else {
      _lines.add(item);
    }
    SoundService.instance.playProductAdd();
    notifyListeners();
  }

  /// Fast add or increment (+1) for barcode gun or Kirana item tap
  void incrementOrAdd(dynamic productOrItem, [double delta = 1.0]) {
    final String prodId = productOrItem.id as String;
    final String prodName = productOrItem.name as String;
    final double prodPrice = (productOrItem.price as num).toDouble();
    final String prodUnit = productOrItem.unit as String;
    final String? prodIcon = productOrItem.icon as String?;

    final index = _lines.indexWhere((line) => line.productId == prodId);
    if (index != -1) {
      final existing = _lines[index];
      _lines[index] = existing.copyWith(qty: existing.qty + delta);
    } else {
      _lines.add(CartItem(
        productId: prodId,
        name: prodName,
        price: prodPrice,
        qty: delta,
        unit: prodUnit,
        icon: prodIcon,
      ));
    }
    SoundService.instance.playProductAdd();
    notifyListeners();
  }

  void removeLine(String? productId, String name) {
    _lines.removeWhere(
      (line) => (line.productId != null && line.productId == productId) ||
          (line.productId == null && line.name.toLowerCase() == name.toLowerCase()),
    );
    SoundService.instance.playDelete();
    notifyListeners();
  }

  void setQty(String? productId, String name, double newQty) {
    if (newQty <= 0) {
      removeLine(productId, name);
      return;
    }

    final index = _lines.indexWhere(
      (line) => (line.productId != null && line.productId == productId) ||
          (line.productId == null && line.name.toLowerCase() == name.toLowerCase()),
    );

    if (index != -1) {
      _lines[index] = _lines[index].copyWith(qty: newQty);
      SoundService.instance.playButtonClick();
      notifyListeners();
    }
  }

  void setPrice(String? productId, String name, double newPrice) {
    if (newPrice < 0) return;

    final index = _lines.indexWhere(
      (line) => (line.productId != null && line.productId == productId) ||
          (line.productId == null && line.name.toLowerCase() == name.toLowerCase()),
    );

    if (index != -1) {
      _lines[index] = _lines[index].copyWith(price: newPrice);
      SoundService.instance.playButtonClick();
      notifyListeners();
    }
  }

  void setDiscount(double value) {
    _discount = value < 0 ? 0.0 : value;
    notifyListeners();
  }

  void setCustomer(Customer? cust) {
    _customer = cust;
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _customer = null;
    _discount = 0.0;
    notifyListeners();
  }

  // Hold / Save bill for queue management
  void saveCurrentCart() {
    if (_lines.isEmpty) return;
    _savedCarts.add(SavedCart(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      time: DateTime.now().toLocal().toString().substring(11, 16),
      customer: _customer,
      items: List.from(_lines),
      discount: _discount,
    ));
    clear();
  }

  void recallCart(SavedCart saved) {
    _lines.clear();
    _lines.addAll(saved.items);
    _customer = saved.customer;
    _discount = saved.discount;
    _savedCarts.removeWhere((c) => c.id == saved.id);
    notifyListeners();
  }

  void removeSavedCart(String id) {
    _savedCarts.removeWhere((c) => c.id == id);
    notifyListeners();
  }
}
