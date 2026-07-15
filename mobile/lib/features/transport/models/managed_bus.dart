enum BusType { standard, vip, luxury, sleeper, minibus }

extension BusTypeApiValue on BusType {
  String get apiValue => switch (this) {
    BusType.standard => 'STANDARD',
    BusType.vip => 'VIP',
    BusType.luxury => 'LUXURY',
    BusType.sleeper => 'SLEEPER',
    BusType.minibus => 'MINIBUS',
  };

  String get label => switch (this) {
    BusType.standard => 'Standard',
    BusType.vip => 'VIP',
    BusType.luxury => 'Luxe',
    BusType.sleeper => 'Couchettes',
    BusType.minibus => 'Minibus',
  };
}

enum BusStatus { available, inService, maintenance, outOfService, unknown }

extension BusStatusLabel on BusStatus {
  String get label => switch (this) {
    BusStatus.available => 'Disponible',
    BusStatus.inService => 'En service',
    BusStatus.maintenance => 'En maintenance',
    BusStatus.outOfService => 'Hors service',
    BusStatus.unknown => 'Statut inconnu',
  };
}

BusStatus _parseBusStatus(String raw) {
  switch (raw) {
    case 'AVAILABLE':
      return BusStatus.available;
    case 'IN_SERVICE':
      return BusStatus.inService;
    case 'MAINTENANCE':
      return BusStatus.maintenance;
    case 'OUT_OF_SERVICE':
      return BusStatus.outOfService;
    default:
      return BusStatus.unknown;
  }
}

class ManagedBus {
  const ManagedBus({
    required this.id,
    required this.companyId,
    required this.registrationNumber,
    required this.fleetNumber,
    required this.brand,
    required this.model,
    required this.seatCapacity,
    required this.busType,
    required this.status,
  });

  final String id;
  final String companyId;
  final String registrationNumber;
  final String fleetNumber;
  final String brand;
  final String model;
  final int seatCapacity;
  final BusType busType;
  final BusStatus status;

  factory ManagedBus.fromJson(Map<String, dynamic> json) {
    return ManagedBus(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      registrationNumber: json['registration_number'] as String,
      fleetNumber: json['fleet_number'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      seatCapacity: json['seat_capacity'] as int,
      busType: BusType.values.firstWhere(
        (value) => value.apiValue == json['bus_type'],
        orElse: () => BusType.standard,
      ),
      status: _parseBusStatus(json['status'] as String),
    );
  }
}
