/// A fee an institution charges - either institution-wide
/// (academicUnitId null) or scoped to one class/filière. `period` is
/// free text on purpose, same reasoning as AcademicUnit.level: a
/// primary school's "Trimestriel" and a university's "Semestriel"
/// don't share a common enum without being awkwardly overloaded.
class FeeSchedule {
  const FeeSchedule({
    required this.id,
    required this.institutionId,
    this.academicUnitId,
    required this.name,
    required this.amount,
    required this.currencyId,
    required this.period,
    required this.isActive,
  });

  final String id;
  final String institutionId;
  final String? academicUnitId;
  final String name;
  final double amount;
  final String currencyId;
  final String period;
  final bool isActive;

  factory FeeSchedule.fromJson(Map<String, dynamic> json) {
    return FeeSchedule(
      id: json['id'] as String,
      institutionId: json['institution_id'] as String,
      academicUnitId: json['academic_unit_id'] as String?,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      currencyId: json['currency_id'] as String,
      period: json['period'] as String,
      isActive: json['is_active'] as bool,
    );
  }
}
