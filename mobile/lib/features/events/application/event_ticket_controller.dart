import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/event_repository.dart';
import '../models/event_ticket.dart';

final eventTicketForBookingProvider = FutureProvider.autoDispose.family<EventTicket, String>((ref, bookingId) {
  return ref.watch(eventRepositoryProvider).getTicketForBooking(bookingId);
});
