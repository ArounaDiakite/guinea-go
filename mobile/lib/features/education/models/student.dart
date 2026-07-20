class Student {
  const Student({
    required this.id,
    required this.institutionId,
    required this.academicUnitId,
    required this.firstName,
    required this.lastName,
    this.dateOfBirth,
    this.guardianName,
    this.guardianPhone,
    required this.isActive,
  });

  final String id;
  final String institutionId;
  final String academicUnitId;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String? guardianName;
  final String? guardianPhone;
  final bool isActive;

  String get fullName => '$firstName $lastName';

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      institutionId: json['institution_id'] as String,
      academicUnitId: json['academic_unit_id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      dateOfBirth: json['date_of_birth'] != null ? DateTime.parse(json['date_of_birth'] as String) : null,
      guardianName: json['guardian_name'] as String?,
      guardianPhone: json['guardian_phone'] as String?,
      isActive: json['is_active'] as bool,
    );
  }
}
