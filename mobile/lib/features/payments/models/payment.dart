enum PaymentProvider { orangeMoney, mtnMomo, stripe }

extension PaymentProviderApiValue on PaymentProvider {
  String get apiValue => switch (this) {
    PaymentProvider.orangeMoney => 'orange_money',
    PaymentProvider.mtnMomo => 'mtn_momo',
    PaymentProvider.stripe => 'stripe',
  };

  String get label => switch (this) {
    PaymentProvider.orangeMoney => 'Orange Money',
    PaymentProvider.mtnMomo => 'MTN Mobile Money',
    PaymentProvider.stripe => 'Carte bancaire',
  };
}

enum PaymentStatus { pending, completed, failed, unknown }

PaymentStatus parsePaymentStatus(String raw) {
  switch (raw) {
    case 'pending':
      return PaymentStatus.pending;
    case 'completed':
      return PaymentStatus.completed;
    case 'failed':
      return PaymentStatus.failed;
    default:
      return PaymentStatus.unknown;
  }
}

class Payment {
  const Payment({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.currency,
    required this.provider,
    required this.status,
  });

  final String id;
  final String bookingId;
  final double amount;
  final String currency;
  final PaymentProvider provider;
  final PaymentStatus status;

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      provider: PaymentProvider.values.firstWhere(
        (value) => value.apiValue == json['provider'],
        orElse: () => PaymentProvider.orangeMoney,
      ),
      status: parsePaymentStatus(json['status'] as String),
    );
  }
}

/// Which domain's booking endpoints to hit - the sandbox payment flow
/// itself (provider choice, confirmation wait, success/failure states)
/// is identical across domains, only the REST paths differ
/// (/bookings/{id}/... vs /hotel-bookings/{id}/...).
enum PaymentBookingType {
  transport,
  hotel,
  event,
  order;

  String get bookingsPathPrefix => switch (this) {
    PaymentBookingType.transport => '/bookings',
    PaymentBookingType.hotel => '/hotel-bookings',
    PaymentBookingType.event => '/event-bookings',
    PaymentBookingType.order => '/orders',
  };
}

/// Everything the shared PaymentScreen needs, passed as a single plain
/// object via GoRouter's `extra` - kept data-only (no callbacks/Refs)
/// so it survives the same way a Booking/TripSeat/BookingSummary
/// already does elsewhere in the route table.
class PaymentRequest {
  const PaymentRequest({
    required this.bookingId,
    required this.pricePaid,
    required this.bookingType,
    required this.confirmedRoute,
  });

  final String bookingId;
  final double pricePaid;
  final PaymentBookingType bookingType;

  /// Where "Voir mes réservations" on the confirmed screen navigates -
  /// the transport and hotel booking-history screens live at different
  /// routes, so this isn't derivable from bookingType alone without
  /// coupling this shared screen to both domains' route paths.
  final String confirmedRoute;
}
