enum Period { t1, t2, t3 }

extension PeriodApiValue on Period {
  String get apiValue => switch (this) {
    Period.t1 => 'T1',
    Period.t2 => 'T2',
    Period.t3 => 'T3',
  };

  String get label => switch (this) {
    Period.t1 => 'Trimestre 1',
    Period.t2 => 'Trimestre 2',
    Period.t3 => 'Trimestre 3',
  };

  static Period fromApiValue(String raw) {
    return Period.values.firstWhere((value) => value.apiValue == raw, orElse: () => Period.t1);
  }
}

class Grade {
  const Grade({
    required this.id,
    required this.studentId,
    required this.subjectId,
    required this.value,
    required this.coefficient,
    required this.period,
    required this.isActive,
  });

  final String id;
  final String studentId;
  final String subjectId;
  final double value;
  final double coefficient;
  final Period period;
  final bool isActive;

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      subjectId: json['subject_id'] as String,
      value: (json['value'] as num).toDouble(),
      coefficient: (json['coefficient'] as num).toDouble(),
      period: PeriodApiValue.fromApiValue(json['period'] as String),
      isActive: json['is_active'] as bool,
    );
  }
}

/// Part of ReportCard - always computed by the backend on the fly from
/// that period's grades, never stored on its own.
class SubjectAverage {
  const SubjectAverage({
    required this.subjectId,
    required this.subjectName,
    required this.average,
    required this.gradeCount,
  });

  final String subjectId;
  final String subjectName;
  final double average;
  final int gradeCount;

  factory SubjectAverage.fromJson(Map<String, dynamic> json) {
    return SubjectAverage(
      subjectId: json['subject_id'] as String,
      subjectName: json['subject_name'] as String,
      average: (json['average'] as num).toDouble(),
      gradeCount: json['grade_count'] as int,
    );
  }
}

/// GET /students/{id}/report-card - computed on demand from that
/// period's grades, not a stored document. overallAverage is weighted
/// by each subject's total coefficient mass for the period (equivalent
/// to a straight coefficient-weighted average across every individual
/// grade, not an average of the per-subject averages); null only when
/// the student has zero grades that period.
class ReportCard {
  const ReportCard({
    required this.studentId,
    required this.period,
    required this.subjectAverages,
    required this.overallAverage,
  });

  final String studentId;
  final Period period;
  final List<SubjectAverage> subjectAverages;
  final double? overallAverage;

  factory ReportCard.fromJson(Map<String, dynamic> json) {
    return ReportCard(
      studentId: json['student_id'] as String,
      period: PeriodApiValue.fromApiValue(json['period'] as String),
      subjectAverages: (json['subject_averages'] as List<dynamic>)
          .map((item) => SubjectAverage.fromJson(item as Map<String, dynamic>))
          .toList(),
      overallAverage: json['overall_average'] != null ? (json['overall_average'] as num).toDouble() : null,
    );
  }
}
