import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transport_repository.dart';
import '../models/ticket.dart';

final ticketForBookingProvider = FutureProvider.autoDispose.family<Ticket, String>((ref, bookingId) {
  return ref.watch(transportRepositoryProvider).getTicketForBooking(bookingId);
});
