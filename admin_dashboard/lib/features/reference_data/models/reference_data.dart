// Fuller counterparts of core/models/currency.dart|country.dart|
// city.dart (which only carry what the institution-creation dropdowns
// need) - this screen manages the records themselves, so it needs
// every field the backend actually stores, including is_active.

class CurrencyRecord {
  const CurrencyRecord({
    required this.id,
    required this.code,
    required this.name,
    required this.symbol,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final String symbol;
  final bool isActive;

  factory CurrencyRecord.fromJson(Map<String, dynamic> json) {
    return CurrencyRecord(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      symbol: json['symbol'] as String,
      isActive: json['is_active'] as bool,
    );
  }
}

class CountryRecord {
  const CountryRecord({
    required this.id,
    required this.code,
    required this.name,
    required this.currencyId,
    required this.timezone,
    required this.languages,
    required this.paymentMethods,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final String currencyId;
  final String timezone;
  final List<String> languages;
  final List<String> paymentMethods;
  final bool isActive;

  factory CountryRecord.fromJson(Map<String, dynamic> json) {
    return CountryRecord(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      currencyId: json['currency_id'] as String,
      timezone: json['timezone'] as String,
      languages: (json['languages'] as List<dynamic>).cast<String>(),
      paymentMethods: (json['payment_methods'] as List<dynamic>).cast<String>(),
      isActive: json['is_active'] as bool,
    );
  }
}

class CityRecord {
  const CityRecord({
    required this.id,
    required this.countryCode,
    required this.name,
    required this.stateOrRegion,
    this.latitude,
    this.longitude,
    required this.isActive,
  });

  final String id;
  final String countryCode;
  final String name;
  final String stateOrRegion;
  final double? latitude;
  final double? longitude;
  final bool isActive;

  factory CityRecord.fromJson(Map<String, dynamic> json) {
    return CityRecord(
      id: json['id'] as String,
      countryCode: json['country_code'] as String,
      name: json['name'] as String,
      stateOrRegion: json['state_or_region'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool,
    );
  }
}
