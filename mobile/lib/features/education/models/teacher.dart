class Teacher {
  const Teacher({
    required this.id,
    required this.institutionId,
    required this.firstName,
    required this.lastName,
    this.email,
    required this.phone,
    this.subject,
    required this.academicUnitIds,
    required this.inviteCode,
    this.userId,
    required this.isActive,
  });

  final String id;
  final String institutionId;
  final String firstName;
  final String lastName;
  final String? email;
  final String phone;
  final String? subject;
  final List<String> academicUnitIds;
  // Self-registration code (POST /auth/register-school-member) - stays
  // visible on the profile even once claimed; userId != null is what
  // actually marks it used, not the code disappearing.
  final String inviteCode;
  final String? userId;
  final bool isActive;

  String get fullName => '$firstName $lastName';

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'] as String,
      institutionId: json['institution_id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String,
      subject: json['subject'] as String?,
      academicUnitIds: (json['academic_unit_ids'] as List<dynamic>).cast<String>(),
      inviteCode: json['invite_code'] as String,
      userId: json['user_id'] as String?,
      isActive: json['is_active'] as bool,
    );
  }
}
