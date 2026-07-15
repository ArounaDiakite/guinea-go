enum SeatType { window, aisle, standard }

enum SeatStatus { available, reserved, maintenance }

SeatType _parseSeatType(String raw) {
  switch (raw) {
    case 'WINDOW':
      return SeatType.window;
    case 'AISLE':
      return SeatType.aisle;
    default:
      return SeatType.standard;
  }
}

SeatStatus _parseSeatStatus(String raw) {
  switch (raw) {
    case 'AVAILABLE':
      return SeatStatus.available;
    case 'MAINTENANCE':
      return SeatStatus.maintenance;
    default:
      // The backend only ever returns AVAILABLE/RESERVED/MAINTENANCE -
      // anything else is treated as taken, the safer default for a
      // seat picker (never let an unrecognized status look bookable).
      return SeatStatus.reserved;
  }
}

class TripSeat {
  const TripSeat({
    required this.seatId,
    required this.seatNumber,
    required this.seatType,
    required this.status,
  });

  final String seatId;
  final String seatNumber;
  final SeatType seatType;
  final SeatStatus status;

  /// Seat numbers come back as strings ("1", "2", ... "30") - parsed
  /// once here so the seat map can lay them out in true numeric order
  /// instead of lexical ("10" before "2") order.
  int get numericOrder => int.tryParse(seatNumber) ?? 0;

  factory TripSeat.fromJson(Map<String, dynamic> json) {
    return TripSeat(
      seatId: json['seat_id'] as String,
      seatNumber: json['seat_number'] as String,
      seatType: _parseSeatType(json['seat_type'] as String),
      status: _parseSeatStatus(json['status'] as String),
    );
  }
}
