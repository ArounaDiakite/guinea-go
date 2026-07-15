import 'bus.dart';
import 'driver.dart';
import 'trip.dart';
import 'transport_company.dart';
import 'transport_route.dart';

/// Full picture for the trip detail screen - the trip itself plus
/// every reference entity it only carries an id for (route, company,
/// bus, driver) and the resolved origin/destination city names.
class TripDetail {
  const TripDetail({
    required this.trip,
    required this.route,
    required this.company,
    required this.bus,
    required this.driver,
    required this.originStationName,
    required this.originCityName,
    required this.destinationStationName,
    required this.destinationCityName,
  });

  final Trip trip;
  final TransportRoute route;
  final TransportCompany company;
  final Bus bus;
  final Driver driver;
  final String originStationName;
  final String originCityName;
  final String destinationStationName;
  final String destinationCityName;
}
