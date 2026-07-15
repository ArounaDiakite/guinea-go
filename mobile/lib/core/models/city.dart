class City {
  const City({
    required this.id,
    required this.countryCode,
    required this.name,
    required this.stateOrRegion,
  });

  final String id;
  final String countryCode;
  final String name;
  final String stateOrRegion;

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] as String,
      countryCode: json['country_code'] as String,
      name: json['name'] as String,
      stateOrRegion: json['state_or_region'] as String,
    );
  }
}
