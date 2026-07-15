/// Shared across every domain with a payable booking (transport,
/// hotels, ...) - the PENDING_PAYMENT -> CONFIRMED/CANCELLED/EXPIRED
/// state machine is identical everywhere the sandbox payment flow is
/// used, not domain-specific itself.
enum BookingStatus { pendingPayment, confirmed, cancelled, expired, unknown }

BookingStatus parseBookingStatus(String raw) {
  switch (raw) {
    case 'PENDING_PAYMENT':
      return BookingStatus.pendingPayment;
    case 'CONFIRMED':
      return BookingStatus.confirmed;
    case 'CANCELLED':
      return BookingStatus.cancelled;
    case 'EXPIRED':
      return BookingStatus.expired;
    default:
      return BookingStatus.unknown;
  }
}
