class Country {
  const Country({required this.id, required this.code, required this.name});

  final String id;
  final String code;
  final String name;

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
    );
  }
}
