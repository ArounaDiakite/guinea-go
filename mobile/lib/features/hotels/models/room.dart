enum RoomType { simple, double, suite, family }

extension RoomTypeApiValue on RoomType {
  String get apiValue => switch (this) {
    RoomType.simple => 'SIMPLE',
    RoomType.double => 'DOUBLE',
    RoomType.suite => 'SUITE',
    RoomType.family => 'FAMILY',
  };

  String get label => switch (this) {
    RoomType.simple => 'Simple',
    RoomType.double => 'Double',
    RoomType.suite => 'Suite',
    RoomType.family => 'Familiale',
  };
}

RoomType _parseRoomType(String raw) {
  return RoomType.values.firstWhere((value) => value.apiValue == raw, orElse: () => RoomType.simple);
}

enum RoomStatus { available, maintenance }

extension RoomStatusApiValue on RoomStatus {
  String get apiValue => switch (this) {
    RoomStatus.available => 'AVAILABLE',
    RoomStatus.maintenance => 'MAINTENANCE',
  };

  String get label => switch (this) {
    RoomStatus.available => 'Disponible',
    RoomStatus.maintenance => 'En maintenance',
  };
}

RoomStatus _parseRoomStatus(String raw) {
  return RoomStatus.values.firstWhere((value) => value.apiValue == raw, orElse: () => RoomStatus.available);
}

class Room {
  const Room({
    required this.id,
    required this.hotelId,
    required this.roomNumber,
    required this.roomType,
    required this.capacity,
    required this.basePrice,
    required this.currencyId,
    required this.description,
    required this.status,
    required this.isActive,
  });

  final String id;
  final String hotelId;
  final String roomNumber;
  final RoomType roomType;
  final int capacity;
  final double basePrice;
  final String currencyId;
  final String? description;
  final RoomStatus status;
  final bool isActive;

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      hotelId: json['hotel_id'] as String,
      roomNumber: json['room_number'] as String,
      roomType: _parseRoomType(json['room_type'] as String),
      capacity: json['capacity'] as int,
      basePrice: (json['base_price'] as num).toDouble(),
      currencyId: json['currency_id'] as String,
      description: json['description'] as String?,
      status: _parseRoomStatus(json['status'] as String),
      isActive: json['is_active'] as bool,
    );
  }
}
