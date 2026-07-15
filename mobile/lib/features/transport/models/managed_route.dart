class ManagedRoute {
  const ManagedRoute({
    required this.id,
    required this.companyId,
    required this.routeCode,
    required this.name,
    required this.originStationId,
    required this.destinationStationId,
    required this.distanceKm,
    required this.estimatedDurationMinutes,
    required this.basePrice,
    required this.currencyId,
  });

  final String id;
  final String companyId;
  final String routeCode;
  final String name;
  final String originStationId;
  final String destinationStationId;
  final double distanceKm;
  final int estimatedDurationMinutes;
  final double basePrice;
  final String currencyId;

  factory ManagedRoute.fromJson(Map<String, dynamic> json) {
    return ManagedRoute(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      routeCode: json['route_code'] as String,
      name: json['name'] as String,
      originStationId: json['origin_station_id'] as String,
      destinationStationId: json['destination_station_id'] as String,
      distanceKm: (json['distance_km'] as num).toDouble(),
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int,
      basePrice: (json['base_price'] as num).toDouble(),
      currencyId: json['currency_id'] as String,
    );
  }
}
