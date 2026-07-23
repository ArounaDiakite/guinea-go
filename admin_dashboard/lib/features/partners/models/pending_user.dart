/// Mirrors backend/app/admin/schemas.py::AdminUserResponse - the shape
/// returned by both GET /admin/users/pending and PATCH /admin/users/
/// {id}/activate, so activateUser's response can replace a PendingUser
/// in place without a separate GET-by-id endpoint to refetch from.
class PendingUser {
  const PendingUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    required this.city,
    required this.countryCode,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;
  final String city;
  final String countryCode;
  final bool isActive;
  final DateTime createdAt;

  String get fullName => '$firstName $lastName';

  factory PendingUser.fromJson(Map<String, dynamic> json) {
    return PendingUser(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      city: json['city'] as String,
      countryCode: json['country_code'] as String,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Source of truth for role codes: backend/app/core/constants.py::
/// UserRole. Only PARTNER_ROLES (the ones gated behind admin
/// validation) ever show up in the pending-users list, but this covers
/// every role that could theoretically appear so a label never goes
/// missing.
String partnerRoleLabel(String role) => switch (role) {
  'company_owner' => 'Propriétaire de compagnie',
  'hotel_owner' => 'Propriétaire d\'hôtel',
  'event_organizer' => 'Organisateur d\'événements',
  'school_administrator' => 'Administrateur scolaire',
  'store_manager' => 'Gérant de boutique',
  'passenger' => 'Passager',
  'driver' => 'Chauffeur',
  'teacher' => 'Enseignant',
  'student' => 'Élève',
  'system_administrator' => 'Administrateur système',
  _ => role,
};
