import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/event_repository.dart';
import '../models/event.dart';
import '../models/ticket_type.dart';

final eventDetailProvider = FutureProvider.autoDispose.family<Event, String>((ref, eventId) {
  return ref.watch(eventRepositoryProvider).getEvent(eventId);
});

final eventTicketTypesProvider = FutureProvider.autoDispose.family<List<TicketType>, String>((ref, eventId) {
  return ref.watch(eventRepositoryProvider).getTicketTypes(eventId);
});

final eventReviewSummaryProvider = FutureProvider.autoDispose.family<(double?, int), String>((ref, eventId) {
  return ref.watch(eventRepositoryProvider).getEventReviewSummary(eventId);
});
