import 'transport_company.dart';
import 'transport_route.dart';

enum TripStatus { scheduled, boarding, inProgress, completed, cancelled, delayed, unknown }

TripStatus _parseTripStatus(String raw) {
  switch (raw) {
    case 'SCHEDULED':
      return TripStatus.scheduled;
    case 'BOARDING':
      return TripStatus.boarding;
    case 'IN_PROGRESS':
      return TripStatus.inProgress;
    case 'COMPLETED':
      return TripStatus.completed;
    case 'CANCELLED':
      return TripStatus.cancelled;
    case 'DELAYED':
      return TripStatus.delayed;
    default:
      return TripStatus.unknown;
  }
}

class Trip {
  const Trip({
    required this.id,
    required this.companyId,
    required this.routeId,
    required this.busId,
    required this.driverId,
    required this.departureDatetime,
    required this.estimatedArrivalDatetime,
    required this.availableSeats,
    required this.bookedSeats,
    required this.price,
    required this.status,
  });

  final String id;
  final String companyId;
  final String routeId;
  final String busId;
  final String driverId;
  final DateTime departureDatetime;
  final DateTime? estimatedArrivalDatetime;
  final int availableSeats;
  final int bookedSeats;
  final double price;
  final TripStatus status;

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      routeId: json['route_id'] as String,
      busId: json['bus_id'] as String,
      driverId: json['driver_id'] as String,
      departureDatetime: DateTime.parse(json['departure_datetime'] as String),
      estimatedArrivalDatetime: json['estimated_arrival_datetime'] != null
          ? DateTime.parse(json['estimated_arrival_datetime'] as String)
          : null,
      availableSeats: json['available_seats'] as int,
      bookedSeats: json['booked_seats'] as int,
      price: (json['price'] as num).toDouble(),
      status: _parseTripStatus(json['status'] as String),
    );
  }
}

/// A trip stitched together with the reference data needed to show it
/// in a results list - the backend's TripResponse only carries bare
/// ids (company_id, route_id, ...), so the repository resolves and
/// attaches the display data once per trip.
class TripSearchResult {
  const TripSearchResult({
    required this.trip,
    required this.route,
    required this.company,
    required this.originCityName,
    required this.destinationCityName,
  });

  final Trip trip;
  final TransportRoute route;
  final TransportCompany company;
  final String originCityName;
  final String destinationCityName;
}
