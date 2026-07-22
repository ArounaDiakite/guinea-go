class User {
  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.city,
    required this.countryCode,
    required this.preferredLanguage,
    required this.role,
    required this.isActive,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String city;
  final String countryCode;
  final String preferredLanguage;
  final String role;
  final bool isActive;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      city: json['city'] as String,
      countryCode: json['country_code'] as String,
      preferredLanguage: json['preferred_language'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool,
    );
  }
}

/// What a successful login yields: the token to persist and the
/// account it belongs to.
class AuthSession {
  const AuthSession({required this.accessToken, required this.user});

  final String accessToken;
  final User user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
