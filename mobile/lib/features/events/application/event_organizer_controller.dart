import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/city.dart';
import '../../../core/models/country.dart';
import '../../../core/models/currency.dart';
import '../../identity/application/auth_controller.dart';
import '../data/event_organizer_repository.dart';
import '../models/event.dart';
import '../models/event_booking.dart';
import '../models/ticket_type.dart';

final myEventsProvider = FutureProvider.autoDispose<List<Event>>((ref) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null) return [];
  return ref.watch(eventOrganizerRepositoryProvider).getMyEvents(user.id);
});

final eventOrganizerCountriesProvider = FutureProvider.autoDispose<List<Country>>((ref) {
  return ref.watch(eventOrganizerRepositoryProvider).getCountries();
});

final eventOrganizerCitiesProvider = FutureProvider.autoDispose<List<City>>((ref) {
  return ref.watch(eventOrganizerRepositoryProvider).getCities();
});

final eventOrganizerCurrenciesProvider = FutureProvider.autoDispose<List<Currency>>((ref) {
  return ref.watch(eventOrganizerRepositoryProvider).getCurrencies();
});

final eventTicketTypesManagedProvider = FutureProvider.autoDispose.family<List<TicketType>, String>((
  ref,
  eventId,
) {
  return ref.watch(eventOrganizerRepositoryProvider).getTicketTypes(eventId);
});

final eventBookingsReceivedProvider = FutureProvider.autoDispose.family<List<EventBooking>, String>((
  ref,
  eventId,
) {
  return ref.watch(eventOrganizerRepositoryProvider).getBookingsForEvent(eventId);
});
