class Driver {
  const Driver({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.yearsOfExperience,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final int yearsOfExperience;

  String get fullName => '$firstName $lastName';

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      phone: json['phone'] as String,
      yearsOfExperience: json['years_of_experience'] as int,
    );
  }
}
