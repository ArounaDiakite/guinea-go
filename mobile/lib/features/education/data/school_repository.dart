import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/city.dart';
import '../../../core/models/country.dart';
import '../../../core/network/api_client.dart';
import '../../payments/models/payment.dart';
import '../models/academic_unit.dart';
import '../models/attendance.dart';
import '../models/fee_schedule.dart';
import '../models/grade.dart';
import '../models/institution.dart';
import '../models/student.dart';
import '../models/student_fee.dart';
import '../models/subject.dart';
import '../models/teacher.dart';
import '../models/timeslot.dart';

/// Everything a school_administrator needs to run their own
/// institution: the institution itself (one per administrator - see
/// InstitutionService's uniqueness guard), its academic units,
/// teachers and students today; subjects/timeslots/attendance/grades/
/// fees join this same repository in later steps rather than splitting
/// by entity, since every one of them is reached by the exact same
/// single actor (unlike Commerce, where passenger reads and
/// store_manager writes were genuinely different actors needing
/// separate repositories).
class SchoolRepository {
  SchoolRepository(this._dio);

  final Dio _dio;

  Future<List<Country>> getCountries() async {
    final response = await _dio.get<List<dynamic>>('/countries/');
    return response.data!.map((json) => Country.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<City>> getCities() async {
    final response = await _dio.get<List<dynamic>>('/cities/');
    return response.data!.map((json) => City.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// null means "no institution yet" (backend 404s GET /institutions/me
  /// for that case) - not an error state, the create-institution form
  /// is the expected next step, same shape as HotelOwnerRepository.
  /// getMyHotel.
  Future<Institution?> getMyInstitution() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/institutions/me');
      return Institution.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Institution> createInstitution({
    required String name,
    required String address,
    required String countryId,
    required String cityId,
    required InstitutionType institutionType,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/institutions/',
      data: {
        'name': name,
        'address': address,
        'country_id': countryId,
        'city_id': cityId,
        'institution_type': institutionType.apiValue,
      },
    );
    return Institution.fromJson(response.data!);
  }

  Future<List<AcademicUnit>> getAcademicUnits(String institutionId) async {
    final response = await _dio.get<List<dynamic>>(
      '/academic-units/',
      queryParameters: {'institution_id': institutionId, 'limit': 200},
    );
    return response.data!.map((json) => AcademicUnit.fromJson(json as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<AcademicUnit> getAcademicUnit(String academicUnitId) async {
    final response = await _dio.get<Map<String, dynamic>>('/academic-units/$academicUnitId');
    return AcademicUnit.fromJson(response.data!);
  }

  Future<AcademicUnit> createAcademicUnit({
    required String institutionId,
    required String name,
    required String level,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/academic-units/',
      data: {'institution_id': institutionId, 'name': name, 'level': level},
    );
    return AcademicUnit.fromJson(response.data!);
  }

  Future<AcademicUnit> updateAcademicUnit({
    required String academicUnitId,
    required String institutionId,
    required String name,
    required String level,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/academic-units/$academicUnitId',
      data: {'institution_id': institutionId, 'name': name, 'level': level},
    );
    return AcademicUnit.fromJson(response.data!);
  }

  Future<List<Teacher>> getTeachers(String institutionId) async {
    final response = await _dio.get<List<dynamic>>(
      '/teachers/',
      queryParameters: {'institution_id': institutionId, 'limit': 200},
    );
    return response.data!.map((json) => Teacher.fromJson(json as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  Future<Teacher> getTeacher(String teacherId) async {
    final response = await _dio.get<Map<String, dynamic>>('/teachers/$teacherId');
    return Teacher.fromJson(response.data!);
  }

  /// The logged-in teacher's own profile (GET /teachers/me) - resolves
  /// their institution_id/academic_unit_ids for the teacher hub, same
  /// way getMyInstitution resolves a school_administrator's institution.
  Future<Teacher> getMyTeacherProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/teachers/me');
    return Teacher.fromJson(response.data!);
  }

  Future<Teacher> createTeacher({
    required String institutionId,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    String? subject,
    List<String> academicUnitIds = const [],
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/teachers/',
      data: {
        'institution_id': institutionId,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        'academic_unit_ids': academicUnitIds,
      },
    );
    return Teacher.fromJson(response.data!);
  }

  Future<Teacher> updateTeacher({
    required String teacherId,
    required String institutionId,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    String? subject,
    List<String> academicUnitIds = const [],
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/teachers/$teacherId',
      data: {
        'institution_id': institutionId,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        'academic_unit_ids': academicUnitIds,
      },
    );
    return Teacher.fromJson(response.data!);
  }

  Future<List<Student>> getStudents(String institutionId, {String? academicUnitId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/students/',
      queryParameters: {
        'institution_id': institutionId,
        'academic_unit_id': ?academicUnitId,
        'limit': 200,
      },
    );
    return response.data!.map((json) => Student.fromJson(json as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  Future<Student> getStudent(String studentId) async {
    final response = await _dio.get<Map<String, dynamic>>('/students/$studentId');
    return Student.fromJson(response.data!);
  }

  /// The logged-in student's own profile (GET /students/me) - same
  /// role as getMyTeacherProfile, for the student hub.
  Future<Student> getMyStudentProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/students/me');
    return Student.fromJson(response.data!);
  }

  Future<Student> createStudent({
    required String institutionId,
    required String academicUnitId,
    required String firstName,
    required String lastName,
    DateTime? dateOfBirth,
    String? guardianName,
    String? guardianPhone,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/students/',
      data: {
        'institution_id': institutionId,
        'academic_unit_id': academicUnitId,
        'first_name': firstName,
        'last_name': lastName,
        if (dateOfBirth != null) 'date_of_birth': _isoDate(dateOfBirth),
        if (guardianName != null && guardianName.isNotEmpty) 'guardian_name': guardianName,
        if (guardianPhone != null && guardianPhone.isNotEmpty) 'guardian_phone': guardianPhone,
      },
    );
    return Student.fromJson(response.data!);
  }

  Future<Student> updateStudent({
    required String studentId,
    required String institutionId,
    required String academicUnitId,
    required String firstName,
    required String lastName,
    DateTime? dateOfBirth,
    String? guardianName,
    String? guardianPhone,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/students/$studentId',
      data: {
        'institution_id': institutionId,
        'academic_unit_id': academicUnitId,
        'first_name': firstName,
        'last_name': lastName,
        if (dateOfBirth != null) 'date_of_birth': _isoDate(dateOfBirth),
        if (guardianName != null && guardianName.isNotEmpty) 'guardian_name': guardianName,
        if (guardianPhone != null && guardianPhone.isNotEmpty) 'guardian_phone': guardianPhone,
      },
    );
    return Student.fromJson(response.data!);
  }

  Future<List<Subject>> getSubjects(String institutionId) async {
    final response = await _dio.get<List<dynamic>>(
      '/subjects/',
      queryParameters: {'institution_id': institutionId, 'limit': 200},
    );
    return response.data!.map((json) => Subject.fromJson(json as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<Subject> getSubject(String subjectId) async {
    final response = await _dio.get<Map<String, dynamic>>('/subjects/$subjectId');
    return Subject.fromJson(response.data!);
  }

  Future<Subject> createSubject({required String institutionId, required String name}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/subjects/',
      data: {'institution_id': institutionId, 'name': name},
    );
    return Subject.fromJson(response.data!);
  }

  Future<Subject> updateSubject({
    required String subjectId,
    required String institutionId,
    required String name,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/subjects/$subjectId',
      data: {'institution_id': institutionId, 'name': name},
    );
    return Subject.fromJson(response.data!);
  }

  Future<List<ScheduleItem>> getSchedule(String academicUnitId) async {
    final response = await _dio.get<List<dynamic>>('/academic-units/$academicUnitId/schedule');
    return response.data!.map((json) => ScheduleItem.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<TimeSlot> getTimeSlot(String timeSlotId) async {
    final response = await _dio.get<Map<String, dynamic>>('/timeslots/$timeSlotId');
    return TimeSlot.fromJson(response.data!);
  }

  Future<TimeSlot> createTimeSlot({
    required String academicUnitId,
    required String subjectId,
    required String teacherId,
    required DayOfWeek dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/timeslots/',
      data: {
        'academic_unit_id': academicUnitId,
        'subject_id': subjectId,
        'teacher_id': teacherId,
        'day_of_week': dayOfWeek.apiValue,
        'start_time': formatApiTime(startTime),
        'end_time': formatApiTime(endTime),
      },
    );
    return TimeSlot.fromJson(response.data!);
  }

  Future<TimeSlot> updateTimeSlot({
    required String timeSlotId,
    required String academicUnitId,
    required String subjectId,
    required String teacherId,
    required DayOfWeek dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/timeslots/$timeSlotId',
      data: {
        'academic_unit_id': academicUnitId,
        'subject_id': subjectId,
        'teacher_id': teacherId,
        'day_of_week': dayOfWeek.apiValue,
        'start_time': formatApiTime(startTime),
        'end_time': formatApiTime(endTime),
      },
    );
    return TimeSlot.fromJson(response.data!);
  }

  Future<void> deleteTimeSlot(String timeSlotId) {
    return _dio.delete<void>('/timeslots/$timeSlotId');
  }

  /// Whole-class-at-once, matching AttendanceSubmit's shape exactly -
  /// one call records every student's status for this time slot and
  /// date together, not one call per student.
  Future<List<AttendanceRecord>> submitAttendance({
    required String timeSlotId,
    required DateTime date,
    required Map<String, AttendanceStatus> statuses,
  }) async {
    final response = await _dio.post<List<dynamic>>(
      '/timeslots/$timeSlotId/attendance',
      data: {'date': _isoDate(date), 'entries': _attendanceEntries(statuses)},
    );
    return response.data!.map((json) => AttendanceRecord.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// PUT counterpart of submitAttendance - the backend requires this
  /// once a day has already been recorded (POST 409s in that case).
  Future<List<AttendanceRecord>> correctAttendance({
    required String timeSlotId,
    required DateTime date,
    required Map<String, AttendanceStatus> statuses,
  }) async {
    final response = await _dio.put<List<dynamic>>(
      '/timeslots/$timeSlotId/attendance',
      data: {'date': _isoDate(date), 'entries': _attendanceEntries(statuses)},
    );
    return response.data!.map((json) => AttendanceRecord.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// A student's (or, for school_administrator/teacher, a given
  /// student's) recorded attendance history - GET /students/{id}/
  /// attendance, most recent first (see backend's get_by_student sort).
  Future<List<AttendanceRecord>> getStudentAttendance(String studentId) async {
    final response = await _dio.get<List<dynamic>>('/students/$studentId/attendance', queryParameters: {'limit': 200});
    return response.data!.map((json) => AttendanceRecord.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Grade> addGrade({
    required String studentId,
    required String subjectId,
    required double value,
    required double coefficient,
    required Period period,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/students/$studentId/grades',
      data: {'subject_id': subjectId, 'value': value, 'coefficient': coefficient, 'period': period.apiValue},
    );
    return Grade.fromJson(response.data!);
  }

  Future<List<Grade>> getGrades(String studentId, {Period? period}) async {
    final response = await _dio.get<List<dynamic>>(
      '/students/$studentId/grades',
      queryParameters: {'period': ?period?.apiValue},
    );
    return response.data!.map((json) => Grade.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// A full replace, same body shape as addGrade - there is no partial
  /// PATCH on the backend.
  Future<Grade> updateGrade({
    required String studentId,
    required String gradeId,
    required String subjectId,
    required double value,
    required double coefficient,
    required Period period,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/students/$studentId/grades/$gradeId',
      data: {'subject_id': subjectId, 'value': value, 'coefficient': coefficient, 'period': period.apiValue},
    );
    return Grade.fromJson(response.data!);
  }

  Future<ReportCard> getReportCard(String studentId, Period period) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/students/$studentId/report-card',
      queryParameters: {'period': period.apiValue},
    );
    return ReportCard.fromJson(response.data!);
  }

  Future<List<FeeSchedule>> getFeeSchedules(String institutionId) async {
    final response = await _dio.get<List<dynamic>>(
      '/fee-schedules/',
      queryParameters: {'institution_id': institutionId, 'limit': 200},
    );
    return response.data!.map((json) => FeeSchedule.fromJson(json as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<FeeSchedule> getFeeSchedule(String feeScheduleId) async {
    final response = await _dio.get<Map<String, dynamic>>('/fee-schedules/$feeScheduleId');
    return FeeSchedule.fromJson(response.data!);
  }

  Future<FeeSchedule> createFeeSchedule({
    required String institutionId,
    String? academicUnitId,
    required String name,
    required double amount,
    required String period,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/fee-schedules/',
      data: {
        'institution_id': institutionId,
        'academic_unit_id': ?academicUnitId,
        'name': name,
        'amount': amount,
        'period': period,
      },
    );
    return FeeSchedule.fromJson(response.data!);
  }

  Future<FeeSchedule> updateFeeSchedule({
    required String feeScheduleId,
    required String institutionId,
    String? academicUnitId,
    required String name,
    required double amount,
    required String period,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/fee-schedules/$feeScheduleId',
      data: {
        'institution_id': institutionId,
        'academic_unit_id': ?academicUnitId,
        'name': name,
        'amount': amount,
        'period': period,
      },
    );
    return FeeSchedule.fromJson(response.data!);
  }

  Future<void> deleteFeeSchedule(String feeScheduleId) {
    return _dio.delete<void>('/fee-schedules/$feeScheduleId');
  }

  Future<StudentFee> applyFeeSchedule({required String studentId, required String feeScheduleId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/students/$studentId/fees',
      data: {'fee_schedule_id': feeScheduleId},
    );
    return StudentFee.fromJson(response.data!);
  }

  Future<List<StudentFee>> getStudentFees(String studentId) async {
    final response = await _dio.get<List<dynamic>>('/students/$studentId/fees');
    return response.data!.map((json) => StudentFee.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Cumulative/partial by design - several of these can accumulate
  /// onto the same StudentFee (see StudentFeeRepository.apply_payment
  /// on the backend). Returns immediately with status "pending"; the
  /// backend confirms it ~2s later via a background task, same sandbox
  /// shape as every other payment flow in this app.
  Future<Payment> payStudentFee({
    required String studentId,
    required String studentFeeId,
    required PaymentProvider provider,
    required double amount,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/students/$studentId/fees/payments',
      data: {'student_fee_id': studentFeeId, 'provider': provider.apiValue, 'amount': amount},
    );
    return Payment.fromJson(response.data!);
  }
}

List<Map<String, String>> _attendanceEntries(Map<String, AttendanceStatus> statuses) => [
  for (final entry in statuses.entries) {'student_id': entry.key, 'status': entry.value.apiValue},
];

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

final schoolRepositoryProvider = Provider<SchoolRepository>((ref) {
  return SchoolRepository(ref.watch(apiClientProvider));
});
