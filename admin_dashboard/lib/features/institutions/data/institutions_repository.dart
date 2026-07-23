import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/city.dart';
import '../../../core/models/country.dart';
import '../../../core/network/api_client.dart';
import '../models/institution.dart';

class InstitutionsRepository {
  InstitutionsRepository(this._dio);

  final Dio _dio;

  Future<List<Country>> getCountries() async {
    final response = await _dio.get<List<dynamic>>('/countries/');
    return response.data!.map((json) => Country.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<City>> getCities() async {
    final response = await _dio.get<List<dynamic>>('/cities/');
    return response.data!.map((json) => City.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// POST /admin/institutions: creates the school_administrator account
  /// and the public Institution together, active immediately - already
  /// vetted by the system_administrator submitting this form, unlike a
  /// self-registered private institution (see PartnersListScreen for
  /// that path instead).
  Future<InstitutionWithAccount> createPublicInstitution({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String city,
    required String name,
    required String address,
    required String countryId,
    required String cityId,
    required PublicInstitutionType institutionType,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/institutions',
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'password': password,
        'city': city,
        'country_code': 'GN',
        'preferred_language': 'fr',
        'institution': {
          'name': name,
          'address': address,
          'country_id': countryId,
          'city_id': cityId,
          'institution_type': institutionType.apiValue,
        },
      },
    );
    return InstitutionWithAccount.fromJson(response.data!);
  }
}

final institutionsRepositoryProvider = Provider<InstitutionsRepository>((ref) {
  return InstitutionsRepository(ref.watch(apiClientProvider));
});
