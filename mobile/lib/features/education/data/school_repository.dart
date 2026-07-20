import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/city.dart';
import '../../../core/models/country.dart';
import '../../../core/network/api_client.dart';
import '../models/academic_unit.dart';
import '../models/institution.dart';
import '../models/student.dart';
import '../models/teacher.dart';

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
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

final schoolRepositoryProvider = Provider<SchoolRepository>((ref) {
  return SchoolRepository(ref.watch(apiClientProvider));
});
