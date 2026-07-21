import '../../payments/models/payment.dart';

enum StudentFeeStatus { unpaid, partial, paid }

StudentFeeStatus parseStudentFeeStatus(String raw) {
  switch (raw) {
    case 'partial':
      return StudentFeeStatus.partial;
    case 'paid':
      return StudentFeeStatus.paid;
    default:
      return StudentFeeStatus.unpaid;
  }
}

extension StudentFeeStatusLabel on StudentFeeStatus {
  String get label => switch (this) {
    StudentFeeStatus.unpaid => 'Impayé',
    StudentFeeStatus.partial => 'Partiellement payé',
    StudentFeeStatus.paid => 'Payé',
  };
}

/// One payment already recorded against a StudentFee - several of
/// these accumulate onto the same fee (see StudentFeeRepository.
/// apply_payment on the backend), unlike a transport/hotel booking's
/// single confirming payment.
class FeePayment {
  const FeePayment({
    required this.id,
    required this.amount,
    required this.provider,
    required this.status,
    this.createdAt,
  });

  final String id;
  final double amount;
  final PaymentProvider provider;
  final PaymentStatus status;
  final DateTime? createdAt;

  factory FeePayment.fromJson(Map<String, dynamic> json) {
    return FeePayment(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      provider: PaymentProvider.values.firstWhere(
        (value) => value.apiValue == json['provider'],
        orElse: () => PaymentProvider.orangeMoney,
      ),
      status: parsePaymentStatus(json['status'] as String),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }
}

/// A FeeSchedule applied to one student - amount_due is snapshotted at
/// apply time (a later edit to the FeeSchedule's own amount doesn't
/// retroactively change it), and never expires (no due-date/timeout
/// logic on the backend, unlike a transport booking's payment window).
class StudentFee {
  const StudentFee({
    required this.id,
    required this.studentId,
    required this.feeScheduleId,
    required this.feeScheduleName,
    required this.period,
    required this.amountDue,
    required this.amountPaid,
    required this.amountRemaining,
    required this.currencyId,
    required this.status,
    required this.payments,
    required this.isActive,
  });

  final String id;
  final String studentId;
  final String feeScheduleId;
  final String feeScheduleName;
  final String period;
  final double amountDue;
  final double amountPaid;
  final double amountRemaining;
  final String currencyId;
  final StudentFeeStatus status;
  final List<FeePayment> payments;
  final bool isActive;

  factory StudentFee.fromJson(Map<String, dynamic> json) {
    return StudentFee(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      feeScheduleId: json['fee_schedule_id'] as String,
      feeScheduleName: json['fee_schedule_name'] as String,
      period: json['period'] as String,
      amountDue: (json['amount_due'] as num).toDouble(),
      amountPaid: (json['amount_paid'] as num).toDouble(),
      amountRemaining: (json['amount_remaining'] as num).toDouble(),
      currencyId: json['currency_id'] as String,
      status: parseStudentFeeStatus(json['status'] as String),
      payments: (json['payments'] as List<dynamic>)
          .map((item) => FeePayment.fromJson(item as Map<String, dynamic>))
          .toList(),
      isActive: json['is_active'] as bool,
    );
  }
}
