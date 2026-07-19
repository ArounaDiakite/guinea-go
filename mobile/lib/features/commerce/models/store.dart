class Store {
  const Store({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    required this.phone,
    required this.email,
    required this.countryId,
    required this.cityId,
    required this.address,
    this.shippingInfo,
    required this.ownerId,
    required this.isVerified,
    required this.isActive,
  });

  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String phone;
  final String email;
  final String countryId;
  final String cityId;
  final String address;
  final String? shippingInfo;
  final String ownerId;
  final bool isVerified;
  final bool isActive;

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      phone: json['phone'] as String,
      email: json['email'] as String,
      countryId: json['country_id'] as String,
      cityId: json['city_id'] as String,
      address: json['address'] as String,
      shippingInfo: json['shipping_info'] as String?,
      ownerId: json['owner_id'] as String,
      isVerified: json['is_verified'] as bool,
      isActive: json['is_active'] as bool,
    );
  }
}
