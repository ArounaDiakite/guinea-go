class ManagedCompany {
  const ManagedCompany({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.countryId,
    required this.cityId,
    required this.ownerId,
    required this.isVerified,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String countryId;
  final String cityId;
  final String ownerId;
  final bool isVerified;

  factory ManagedCompany.fromJson(Map<String, dynamic> json) {
    return ManagedCompany(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String,
      address: json['address'] as String,
      countryId: json['country_id'] as String,
      cityId: json['city_id'] as String,
      ownerId: json['owner_id'] as String,
      isVerified: json['is_verified'] as bool,
    );
  }
}
