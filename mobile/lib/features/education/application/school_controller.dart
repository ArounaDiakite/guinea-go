import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/city.dart';
import '../../../core/models/country.dart';
import '../data/school_repository.dart';
import '../models/academic_unit.dart';
import '../models/institution.dart';
import '../models/student.dart';
import '../models/teacher.dart';

final myInstitutionProvider = FutureProvider.autoDispose<Institution?>((ref) {
  return ref.watch(schoolRepositoryProvider).getMyInstitution();
});

final schoolCountriesProvider = FutureProvider.autoDispose<List<Country>>((ref) {
  return ref.watch(schoolRepositoryProvider).getCountries();
});

final schoolCitiesProvider = FutureProvider.autoDispose<List<City>>((ref) {
  return ref.watch(schoolRepositoryProvider).getCities();
});

final academicUnitsProvider = FutureProvider.autoDispose.family<List<AcademicUnit>, String>((
  ref,
  institutionId,
) {
  return ref.watch(schoolRepositoryProvider).getAcademicUnits(institutionId);
});

final academicUnitDetailProvider = FutureProvider.autoDispose.family<AcademicUnit, String>((
  ref,
  academicUnitId,
) {
  return ref.watch(schoolRepositoryProvider).getAcademicUnit(academicUnitId);
});

final teachersProvider = FutureProvider.autoDispose.family<List<Teacher>, String>((ref, institutionId) {
  return ref.watch(schoolRepositoryProvider).getTeachers(institutionId);
});

final teacherDetailProvider = FutureProvider.autoDispose.family<Teacher, String>((ref, teacherId) {
  return ref.watch(schoolRepositoryProvider).getTeacher(teacherId);
});

class StudentListQuery {
  const StudentListQuery({required this.institutionId, this.academicUnitId});

  final String institutionId;
  final String? academicUnitId;

  @override
  bool operator ==(Object other) =>
      other is StudentListQuery &&
      other.institutionId == institutionId &&
      other.academicUnitId == academicUnitId;

  @override
  int get hashCode => Object.hash(institutionId, academicUnitId);
}

final studentsProvider = FutureProvider.autoDispose.family<List<Student>, StudentListQuery>((ref, query) {
  return ref.watch(schoolRepositoryProvider).getStudents(query.institutionId, academicUnitId: query.academicUnitId);
});

final studentDetailProvider = FutureProvider.autoDispose.family<Student, String>((ref, studentId) {
  return ref.watch(schoolRepositoryProvider).getStudent(studentId);
});
