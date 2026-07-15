/// Full hotel record - shared by every screen that needs it (passenger
/// search/detail, hotel_owner management) since the backend's
/// HotelResponse already returns the same complete shape to everyone;
/// there's no lean "public" projection worth a separate model here.
class Hotel {
  const Hotel({
    required this.id,
    required this.name,
    required this.description,
    required this.phone,
    required this.email,
    required this.website,
    required this.countryId,
    required this.cityId,
    required this.address,
    required this.amenities,
    required this.ownerId,
    required this.isVerified,
    required this.isActive,
  });

  final String id;
  final String name;
  final String? description;
  final String phone;
  final String email;
  final String? website;
  final String countryId;
  final String cityId;
  final String address;
  final List<String> amenities;
  final String ownerId;
  final bool isVerified;
  final bool isActive;

  factory Hotel.fromJson(Map<String, dynamic> json) {
    return Hotel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      phone: json['phone'] as String,
      email: json['email'] as String,
      website: json['website'] as String?,
      countryId: json['country_id'] as String,
      cityId: json['city_id'] as String,
      address: json['address'] as String,
      amenities: (json['amenities'] as List<dynamic>? ?? []).cast<String>(),
      ownerId: json['owner_id'] as String,
      isVerified: json['is_verified'] as bool,
      isActive: json['is_active'] as bool,
    );
  }
}
