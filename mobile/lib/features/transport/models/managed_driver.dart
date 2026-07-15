enum DriverGender { male, female, other }

extension DriverGenderApiValue on DriverGender {
  String get apiValue => switch (this) {
    DriverGender.male => 'MALE',
    DriverGender.female => 'FEMALE',
    DriverGender.other => 'OTHER',
  };

  String get label => switch (this) {
    DriverGender.male => 'Homme',
    DriverGender.female => 'Femme',
    DriverGender.other => 'Autre',
  };
}

enum LicenseCategory { a, b, c, d, e }

extension LicenseCategoryApiValue on LicenseCategory {
  String get apiValue => switch (this) {
    LicenseCategory.a => 'A',
    LicenseCategory.b => 'B',
    LicenseCategory.c => 'C',
    LicenseCategory.d => 'D',
    LicenseCategory.e => 'E',
  };
}

enum DriverStatus { available, onTrip, onLeave, suspended, inactive, unknown }

extension DriverStatusLabel on DriverStatus {
  String get label => switch (this) {
    DriverStatus.available => 'Disponible',
    DriverStatus.onTrip => 'En trajet',
    DriverStatus.onLeave => 'En congé',
    DriverStatus.suspended => 'Suspendu',
    DriverStatus.inactive => 'Inactif',
    DriverStatus.unknown => 'Statut inconnu',
  };
}

DriverStatus _parseDriverStatus(String raw) {
  switch (raw) {
    case 'AVAILABLE':
      return DriverStatus.available;
    case 'ON_TRIP':
      return DriverStatus.onTrip;
    case 'ON_LEAVE':
      return DriverStatus.onLeave;
    case 'SUSPENDED':
      return DriverStatus.suspended;
    case 'INACTIVE':
      return DriverStatus.inactive;
    default:
      return DriverStatus.unknown;
  }
}

class ManagedDriver {
  const ManagedDriver({
    required this.id,
    required this.companyId,
    required this.userId,
    required this.employeeNumber,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.licenseNumber,
    required this.licenseExpiryDate,
    required this.status,
  });

  final String id;
  final String companyId;
  final String? userId;
  final String employeeNumber;
  final String firstName;
  final String lastName;
  final String phone;
  final String licenseNumber;
  final DateTime licenseExpiryDate;
  final DriverStatus status;

  String get fullName => '$firstName $lastName';

  factory ManagedDriver.fromJson(Map<String, dynamic> json) {
    return ManagedDriver(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      userId: json['user_id'] as String?,
      employeeNumber: json['employee_number'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      phone: json['phone'] as String,
      licenseNumber: json['license_number'] as String,
      licenseExpiryDate: DateTime.parse(json['license_expiry_date'] as String),
      status: _parseDriverStatus(json['status'] as String),
    );
  }
}
