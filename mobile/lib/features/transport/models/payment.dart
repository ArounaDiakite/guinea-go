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
