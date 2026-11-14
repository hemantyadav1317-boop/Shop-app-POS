class Category {
  final String id;
  final String shopId;
  final String name;
  final String? imageUrl;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Category({
    required this.id,
    required this.shopId,
    required this.name,
    this.imageUrl,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String? ?? '',
      shopId: json['shop_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'name': name,
      'image_url': imageUrl,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabaseJson() {
    final isValidUuid = RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(id);
    return {
      if (isValidUuid) 'id': id,
      'shop_id': shopId,
      'name': name.trim(),
      if (imageUrl != null && imageUrl!.trim().isNotEmpty)
        'image_url': imageUrl!.trim(),
      'is_active': isActive,
    };
  }

  Category copyWith({
    String? id,
    String? shopId,
    String? name,
    String? imageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          shopId == other.shopId &&
          name.toLowerCase() == other.name.toLowerCase();

  @override
  int get hashCode => id.hashCode ^ shopId.hashCode ^ name.toLowerCase().hashCode;
}
