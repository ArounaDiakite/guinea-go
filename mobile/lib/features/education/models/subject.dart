class Subject {
  const Subject({
    required this.id,
    required this.institutionId,
    required this.name,
    required this.isActive,
  });

  final String id;
  final String institutionId;
  final String name;
  final bool isActive;

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as String,
      institutionId: json['institution_id'] as String,
      name: json['name'] as String,
      isActive: json['is_active'] as bool,
    );
  }
}
