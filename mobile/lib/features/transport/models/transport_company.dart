class TransportCompany {
  const TransportCompany({
    required this.id,
    required this.name,
    required this.phone,
    required this.logoUrl,
  });

  final String id;
  final String name;
  final String phone;
  final String? logoUrl;

  factory TransportCompany.fromJson(Map<String, dynamic> json) {
    return TransportCompany(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      logoUrl: json['logo_url'] as String?,
    );
  }
}
