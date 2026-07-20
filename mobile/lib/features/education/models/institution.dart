enum InstitutionType {
  primaryPublic,
  primaryPrivate,
  secondaryPublic,
  secondaryPrivate,
  highSchoolPublic,
  highSchoolPrivate,
  vocationalHighSchool,
  vocationalSchool,
  universityPublic,
  universityPrivate;

  String get apiValue => switch (this) {
    InstitutionType.primaryPublic => 'primary_public',
    InstitutionType.primaryPrivate => 'primary_private',
    InstitutionType.secondaryPublic => 'secondary_public',
    InstitutionType.secondaryPrivate => 'secondary_private',
    InstitutionType.highSchoolPublic => 'high_school_public',
    InstitutionType.highSchoolPrivate => 'high_school_private',
    InstitutionType.vocationalHighSchool => 'vocational_high_school',
    InstitutionType.vocationalSchool => 'vocational_school',
    InstitutionType.universityPublic => 'university_public',
    InstitutionType.universityPrivate => 'university_private',
  };

  String get label => switch (this) {
    InstitutionType.primaryPublic => 'Primaire publique',
    InstitutionType.primaryPrivate => 'Primaire privée',
    InstitutionType.secondaryPublic => 'Collège public',
    InstitutionType.secondaryPrivate => 'Collège privé',
    InstitutionType.highSchoolPublic => 'Lycée public',
    InstitutionType.highSchoolPrivate => 'Lycée privé',
    InstitutionType.vocationalHighSchool => 'Lycée technique',
    InstitutionType.vocationalSchool => 'École professionnelle',
    InstitutionType.universityPublic => 'Université publique',
    InstitutionType.universityPrivate => 'Université privée',
  };

  static InstitutionType fromApiValue(String value) {
    return InstitutionType.values.firstWhere(
      (type) => type.apiValue == value,
      orElse: () => InstitutionType.primaryPrivate,
    );
  }
}

/// Every type a school_administrator can self-serve create via
/// POST /institutions/ - a public institution_type is only ever set up
/// by a system_administrator (backend allows any type through this
/// endpoint given the right permission, but the create-institution
/// form only ever offers this private subset, matching what a
/// school_administrator could otherwise reach through the register-
/// institution self-registration flow). See
/// backend/app/modules/education/institutions/schemas.py::
/// PRIVATE_INSTITUTION_TYPES.
const privateInstitutionTypes = [
  InstitutionType.primaryPrivate,
  InstitutionType.secondaryPrivate,
  InstitutionType.highSchoolPrivate,
  InstitutionType.vocationalHighSchool,
  InstitutionType.vocationalSchool,
  InstitutionType.universityPrivate,
];

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
  final InstitutionType institutionType;
  final String administratorId;
  final bool isActive;

  factory Institution.fromJson(Map<String, dynamic> json) {
    return Institution(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      countryId: json['country_id'] as String,
      cityId: json['city_id'] as String,
      institutionType: InstitutionType.fromApiValue(json['institution_type'] as String),
      administratorId: json['administrator_id'] as String,
      isActive: json['is_active'] as bool,
    );
  }
}
