class AcademicUnit {
  const AcademicUnit({
    required this.id,
    required this.institutionId,
    required this.name,
    required this.level,
    required this.isActive,
  });

  final String id;
  final String institutionId;
  final String name;
  final String level;
  final bool isActive;

  factory AcademicUnit.fromJson(Map<String, dynamic> json) {
    return AcademicUnit(
      id: json['id'] as String,
      institutionId: json['institution_id'] as String,
      name: json['name'] as String,
      level: json['level'] as String,
      isActive: json['is_active'] as bool,
    );
  }
}
