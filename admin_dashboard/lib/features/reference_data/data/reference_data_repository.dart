import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/reference_data.dart';

/// Countries/cities/currencies - readable by anyone (GET), writable
/// only by a system_administrator (POST), no PUT/DELETE yet on the
/// backend - see CLAUDE.md's "Données de référence" section.
class ReferenceDataRepository {
  ReferenceDataRepository(this._dio);

  final Dio _dio;

  Future<List<CurrencyRecord>> getCurrencies() async {
    final response = await _dio.get<List<dynamic>>('/currencies/');
    return response.data!.map((json) => CurrencyRecord.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<CurrencyRecord> createCurrency({
    required String code,
    required String name,
    required String symbol,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/currencies/',
      data: {'code': code, 'name': name, 'symbol': symbol, 'is_active': true},
    );
    return CurrencyRecord.fromJson(response.data!);
  }

  Future<List<CountryRecord>> getCountries() async {
    final response = await _dio.get<List<dynamic>>('/countries/');
    return response.data!.map((json) => CountryRecord.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// currency_code is resolved server-side to an existing Currency's id
  /// - 400s if no such currency has been created yet (see
  /// CountryCreate's own doc comment on the backend).
  Future<CountryRecord> createCountry({
    required String code,
    required String name,
    required String currencyCode,
    required String timezone,
    required List<String> languages,
    required List<String> paymentMethods,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/countries/',
      data: {
        'code': code,
        'name': name,
        'currency_code': currencyCode,
        'timezone': timezone,
        'languages': languages,
        'payment_methods': paymentMethods,
        'is_active': true,
      },
    );
    return CountryRecord.fromJson(response.data!);
  }

  Future<List<CityRecord>> getCities() async {
    final response = await _dio.get<List<dynamic>>('/cities/');
    return response.data!.map((json) => CityRecord.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<CityRecord> createCity({
    required String countryCode,
    required String name,
    required String stateOrRegion,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/cities/',
      data: {
        'country_code': countryCode,
        'name': name,
        'state_or_region': stateOrRegion,
        'is_active': true,
      },
    );
    return CityRecord.fromJson(response.data!);
  }
}

final referenceDataRepositoryProvider = Provider<ReferenceDataRepository>((ref) {
  return ReferenceDataRepository(ref.watch(apiClientProvider));
});
