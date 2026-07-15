import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/city.dart';
import '../models/country.dart';
import '../models/currency.dart';
import '../models/managed_bus.dart';
import '../models/managed_company.dart';
import '../models/managed_driver.dart';
import '../models/managed_route.dart';
import '../models/managed_schedule.dart';
import '../models/station.dart';
import '../models/trip.dart';

/// Everything a company_owner needs to manage their own fleet: the
/// company itself, buses, drivers, routes (against existing, shared
/// stations - a company_owner can't create stations, only
/// system_administrator can), schedules and trips. Kept separate from
/// TransportRepository (passenger/driver reads) since this is a
/// different persona touching different write-heavy endpoints -
/// folding both into one class would make an already-large file
/// unwieldy.
class CompanyRepository {
  CompanyRepository(this._dio);

  final Dio _dio;

  Future<List<Country>> getCountries() async {
    final response = await _dio.get<List<dynamic>>('/countries/');
    return response.data!.map((json) => Country.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<City>> getCities() async {
    final response = await _dio.get<List<dynamic>>('/cities/');
    return response.data!.map((json) => City.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Currency>> getCurrencies() async {
    final response = await _dio.get<List<dynamic>>('/currencies/');
    return response.data!.map((json) => Currency.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Station>> getStations() async {
    final response = await _dio.get<List<dynamic>>('/stations/', queryParameters: {'limit': 100});
    return response.data!.map((json) => Station.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// A company_owner can in principle own more than one company, but
  /// this app only ever manages the first one found for them - a
  /// small-operator assumption consistent with there being no UI
  /// anywhere to switch between several.
  Future<ManagedCompany?> getMyCompany(String ownerId) async {
    final response = await _dio.get<List<dynamic>>('/companies/', queryParameters: {'owner_id': ownerId, 'limit': 1});
    final companies = response.data!;
    if (companies.isEmpty) return null;
    return ManagedCompany.fromJson(companies.first as Map<String, dynamic>);
  }

  Future<ManagedCompany> createCompany({
    required String name,
    required String phone,
    required String email,
    required String address,
    required String countryId,
    required String cityId,
    String? description,
    String? website,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/companies/',
      data: {
        'name': name,
        // This whole management surface is the transport module's -
        // not exposed as a picker, since a bus operator's company IS
        // a BUS company here.
        'company_type': 'BUS',
        'phone': phone,
        'email': email,
        'address': address,
        'country_id': countryId,
        'city_id': cityId,
        if (description != null && description.isNotEmpty) 'description': description,
        if (website != null && website.isNotEmpty) 'website': website,
      },
    );
    return ManagedCompany.fromJson(response.data!);
  }

  Future<List<ManagedBus>> getBuses(String companyId) async {
    final response = await _dio.get<List<dynamic>>(
      '/buses/',
      queryParameters: {'company_id': companyId, 'limit': 100},
    );
    return response.data!.map((json) => ManagedBus.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<ManagedBus> createBus({
    required String companyId,
    required String registrationNumber,
    required String fleetNumber,
    required String brand,
    required String model,
    required int manufactureYear,
    required int seatCapacity,
    required BusType busType,
    bool airConditioning = false,
    bool wifi = false,
    bool usbCharging = false,
    bool toilet = false,
    bool television = false,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/buses/',
      data: {
        'company_id': companyId,
        'registration_number': registrationNumber,
        'fleet_number': fleetNumber,
        'brand': brand,
        'model': model,
        'manufacture_year': manufactureYear,
        'seat_capacity': seatCapacity,
        'bus_type': busType.apiValue,
        'air_conditioning': airConditioning,
        'wifi': wifi,
        'usb_charging': usbCharging,
        'toilet': toilet,
        'television': television,
      },
    );
    return ManagedBus.fromJson(response.data!);
  }

  /// One-shot: 400s if this bus's seats were already generated. Callers
  /// treat that as a harmless "already done" outcome, not a failure.
  Future<void> generateSeatsForBus(String busId) async {
    await _dio.post('/buses/$busId/generate-seats');
  }

  Future<List<ManagedDriver>> getDrivers(String companyId) async {
    final response = await _dio.get<List<dynamic>>(
      '/drivers/',
      queryParameters: {'company_id': companyId, 'limit': 100},
    );
    return response.data!.map((json) => ManagedDriver.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// The atomic account+profile flow (POST /companies/{id}/drivers) -
  /// the resulting driver can actually log in, unlike the standalone
  /// POST /drivers/ path which only records a profile with no linked
  /// account.
  Future<ManagedDriver> createDriverWithAccount({
    required String companyId,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String city,
    required String employeeNumber,
    required DriverGender gender,
    required DateTime dateOfBirth,
    required String licenseNumber,
    required LicenseCategory licenseCategory,
    required DateTime licenseExpiryDate,
    int yearsOfExperience = 0,
  }) async {
    String isoDate(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final response = await _dio.post<Map<String, dynamic>>(
      '/companies/$companyId/drivers',
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'password': password,
        'city': city,
        'country_code': 'GN',
        'preferred_language': 'fr',
        'profile': {
          'employee_number': employeeNumber,
          'gender': gender.apiValue,
          'date_of_birth': isoDate(dateOfBirth),
          'license_number': licenseNumber,
          'license_category': licenseCategory.apiValue,
          'license_expiry_date': isoDate(licenseExpiryDate),
          'years_of_experience': yearsOfExperience,
        },
      },
    );
    return ManagedDriver.fromJson(response.data!['driver'] as Map<String, dynamic>);
  }

  Future<List<ManagedRoute>> getRoutes(String companyId) async {
    final response = await _dio.get<List<dynamic>>(
      '/routes/',
      queryParameters: {'company_id': companyId, 'limit': 100},
    );
    return response.data!.map((json) => ManagedRoute.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<ManagedRoute> createRoute({
    required String companyId,
    required String routeCode,
    required String name,
    required String originStationId,
    required String destinationStationId,
    required double distanceKm,
    required int estimatedDurationMinutes,
    required double basePrice,
    String? currencyId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/routes/',
      data: {
        'company_id': companyId,
        'route_code': routeCode,
        'name': name,
        'origin_station_id': originStationId,
        'destination_station_id': destinationStationId,
        'distance_km': distanceKm,
        'estimated_duration_minutes': estimatedDurationMinutes,
        'base_price': basePrice,
        'currency_id': ?currencyId,
      },
    );
    return ManagedRoute.fromJson(response.data!);
  }

  Future<List<ManagedSchedule>> getSchedules(String companyId) async {
    final response = await _dio.get<List<dynamic>>(
      '/schedules/',
      queryParameters: {'company_id': companyId, 'limit': 100},
    );
    return response.data!.map((json) => ManagedSchedule.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<ManagedSchedule> createSchedule({
    required String companyId,
    required String routeId,
    required String departureTime,
    required List<DayOfWeek> operatingDays,
    String? estimatedArrivalTime,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/schedules/',
      data: {
        'company_id': companyId,
        'route_id': routeId,
        'departure_time': departureTime,
        'estimated_arrival_time': ?estimatedArrivalTime,
        'operating_days': operatingDays.map((day) => day.apiValue).toList(),
      },
    );
    return ManagedSchedule.fromJson(response.data!);
  }

  Future<List<Trip>> getCompanyTrips(String companyId) async {
    final response = await _dio.get<List<dynamic>>(
      '/trips/',
      queryParameters: {'company_id': companyId, 'limit': 100},
    );
    return response.data!.map((json) => Trip.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Trip> createTrip({
    required String companyId,
    required String routeId,
    required String scheduleId,
    required String busId,
    required String driverId,
    required DateTime travelDate,
  }) async {
    final isoDate =
        '${travelDate.year.toString().padLeft(4, '0')}-${travelDate.month.toString().padLeft(2, '0')}-${travelDate.day.toString().padLeft(2, '0')}';

    final response = await _dio.post<Map<String, dynamic>>(
      '/trips/',
      data: {
        'company_id': companyId,
        'route_id': routeId,
        'schedule_id': scheduleId,
        'bus_id': busId,
        'driver_id': driverId,
        'travel_date': isoDate,
      },
    );
    return Trip.fromJson(response.data!);
  }
}

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepository(ref.watch(apiClientProvider));
});
