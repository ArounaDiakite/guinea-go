import 'package:flutter/material.dart';

enum DayOfWeek { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

extension DayOfWeekApiValue on DayOfWeek {
  String get apiValue => switch (this) {
    DayOfWeek.monday => 'MONDAY',
    DayOfWeek.tuesday => 'TUESDAY',
    DayOfWeek.wednesday => 'WEDNESDAY',
    DayOfWeek.thursday => 'THURSDAY',
    DayOfWeek.friday => 'FRIDAY',
    DayOfWeek.saturday => 'SATURDAY',
    DayOfWeek.sunday => 'SUNDAY',
  };

  String get label => switch (this) {
    DayOfWeek.monday => 'Lundi',
    DayOfWeek.tuesday => 'Mardi',
    DayOfWeek.wednesday => 'Mercredi',
    DayOfWeek.thursday => 'Jeudi',
    DayOfWeek.friday => 'Vendredi',
    DayOfWeek.saturday => 'Samedi',
    DayOfWeek.sunday => 'Dimanche',
  };

  static DayOfWeek fromApiValue(String raw) {
    return DayOfWeek.values.firstWhere((value) => value.apiValue == raw, orElse: () => DayOfWeek.monday);
  }
}

/// Backend Pydantic `time` fields serialize as "HH:MM:SS" - parsed into
/// a plain TimeOfDay (date-less) since that's all a weekly recurring
/// time slot needs, and formatted back the same way on write.
TimeOfDay parseApiTime(String raw) {
  final parts = raw.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String formatApiTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

class TimeSlot {
  const TimeSlot({
    required this.id,
    required this.academicUnitId,
    required this.subjectId,
    required this.teacherId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.isActive,
  });

  final String id;
  final String academicUnitId;
  final String subjectId;
  final String teacherId;
  final DayOfWeek dayOfWeek;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isActive;

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      id: json['id'] as String,
      academicUnitId: json['academic_unit_id'] as String,
      subjectId: json['subject_id'] as String,
      teacherId: json['teacher_id'] as String,
      dayOfWeek: DayOfWeekApiValue.fromApiValue(json['day_of_week'] as String),
      startTime: parseApiTime(json['start_time'] as String),
      endTime: parseApiTime(json['end_time'] as String),
      isActive: json['is_active'] as bool,
    );
  }
}

/// GET /academic-units/{id}/schedule's enriched view - subject/teacher
/// names already resolved server-side, so the timetable screen doesn't
/// need N+1 lookups to render something human-readable.
class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.teacherId,
    required this.teacherName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final String subjectId;
  final String subjectName;
  final String teacherId;
  final String teacherName;
  final DayOfWeek dayOfWeek;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      subjectName: json['subject_name'] as String,
      teacherId: json['teacher_id'] as String,
      teacherName: json['teacher_name'] as String,
      dayOfWeek: DayOfWeekApiValue.fromApiValue(json['day_of_week'] as String),
      startTime: parseApiTime(json['start_time'] as String),
      endTime: parseApiTime(json['end_time'] as String),
    );
  }
}
