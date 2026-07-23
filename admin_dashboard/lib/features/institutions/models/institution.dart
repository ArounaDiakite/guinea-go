/// Only the public subset (backend/app/modules/education/institutions/
/// schemas.py::PUBLIC_INSTITUTION_TYPES) - a private institution_type
/// is only ever set up by a school_administrator self-registering
/// (POST /auth/register-institution, pending validation through the
/// Partenaires tab), never directly by a system_administrator.
enum PublicInstitutionType {
  primaryPublic,
  secondaryPublic,
  highSchoolPublic,
  universityPublic;

  String get apiValue => switch (this) {
    PublicInstitutionType.primaryPublic => 'primary_public',
    PublicInstitutionType.secondaryPublic => 'secondary_public',
    PublicInstitutionType.highSchoolPublic => 'high_school_public',
    PublicInstitutionType.universityPublic => 'university_public',
  };

  String get label => switch (this) {
    PublicInstitutionType.primaryPublic => 'Primaire publique',
    PublicInstitutionType.secondaryPublic => 'Collège public',
    PublicInstitutionType.highSchoolPublic => 'Lycée public',
    PublicInstitutionType.universityPublic => 'Université publique',
  };
}

class Institution {
  const Institution({
    required this.id,
    required this.name,
    required this.address,
    required this.countryId,
    required this.cityId,
    required this.institutionType,
    required this.administratorId,
    required this.isActive,
  });

  final String id;
  final String name;
  final String address;
  final String countryId;
  final String cityId;
  final String institutionType;
  final String administratorId;
  final bool isActive;

  factory Institution.fromJson(Map<String, dynamic> json) {
    return Institution(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      countryId: json['country_id'] as String,
      cityId: json['city_id'] as String,
      institutionType: json['institution_type'] as String,
      administratorId: json['administrator_id'] as String,
      isActive: json['is_active'] as bool,
    );
  }
}

/// The account created together with the institution
/// (InstitutionWithAccountResponse.account - a UserResponse).
class InstitutionAdministrator {
  const InstitutionAdministrator({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;

  factory InstitutionAdministrator.fromJson(Map<String, dynamic> json) {
    return InstitutionAdministrator(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
    );
  }
}

class InstitutionWithAccount {
  const InstitutionWithAccount({required this.institution, required this.account});

  final Institution institution;
  final InstitutionAdministrator account;

  factory InstitutionWithAccount.fromJson(Map<String, dynamic> json) {
    return InstitutionWithAccount(
      institution: Institution.fromJson(json['institution'] as Map<String, dynamic>),
      account: InstitutionAdministrator.fromJson(json['account'] as Map<String, dynamic>),
    );
  }
}
