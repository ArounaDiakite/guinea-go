enum AttendanceStatus { present, absent, late, excused }

extension AttendanceStatusApiValue on AttendanceStatus {
  String get apiValue => switch (this) {
    AttendanceStatus.present => 'present',
    AttendanceStatus.absent => 'absent',
    AttendanceStatus.late => 'late',
    AttendanceStatus.excused => 'excused',
  };

  String get label => switch (this) {
    AttendanceStatus.present => 'Présent',
    AttendanceStatus.absent => 'Absent',
    AttendanceStatus.late => 'En retard',
    AttendanceStatus.excused => 'Excusé',
  };

  static AttendanceStatus fromApiValue(String raw) {
    return AttendanceStatus.values.firstWhere(
      (value) => value.apiValue == raw,
      orElse: () => AttendanceStatus.present,
    );
  }
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.timeSlotId,
    required this.studentId,
    required this.date,
    required this.status,
    required this.isActive,
  });

  final String id;
  final String timeSlotId;
  final String studentId;
  final DateTime date;
  final AttendanceStatus status;
  final bool isActive;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      timeSlotId: json['timeslot_id'] as String,
      studentId: json['student_id'] as String,
      date: DateTime.parse(json['date'] as String),
      status: AttendanceStatusApiValue.fromApiValue(json['status'] as String),
      isActive: json['is_active'] as bool,
    );
  }
}
