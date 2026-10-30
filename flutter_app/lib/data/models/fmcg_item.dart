class FmcgItem {
  final String barcode;
  final String name;
  final String nameHi;
  final String brand;
  final String category;
  final String unit; // 'pkt', 'pc', 'bottle', 'kg', 'g', 'litre'
  final String packSize; // '70g', '140g', '1L', '500g', etc.
  final double mrp; // 2026 accurate benchmark retail price
  final double defaultCostPrice; // wholesale purchase price for instant margin
  final String icon; // Visual emoji
  final String? imageUrl;
  final List<String> searchKeywords;

  const FmcgItem({
    required this.barcode,
    required this.name,
    required this.nameHi,
    required this.brand,
    required this.category,
    required this.unit,
    required this.packSize,
    required this.mrp,
    required this.defaultCostPrice,
    required this.icon,
    this.imageUrl,
    this.searchKeywords = const [],
  });

  double get marginAmount => mrp - defaultCostPrice;
  double get marginPercentage => mrp > 0 ? ((mrp - defaultCostPrice) / mrp) * 100 : 0.0;
}

