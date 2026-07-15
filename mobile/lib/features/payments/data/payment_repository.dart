import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/booking_status.dart';
import '../../../core/network/api_client.dart';
import '../models/payment.dart';

/// The sandbox payment flow (POST .../payments, then a single re-check
/// of the booking's status once the backend's own confirmation delay
/// has passed) is identical across every booking domain - only the
/// REST path prefix differs (PaymentBookingType.bookingsPathPrefix).
/// Kept separate from TransportRepository/HotelRepository so the
/// payment screen doesn't need to depend on either domain's data layer.
class PaymentRepository {
  PaymentRepository(this._dio);

  final Dio _dio;

  Future<Payment> payForBooking({
    required PaymentBookingType bookingType,
    required String bookingId,
    required PaymentProvider provider,
    required double amount,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${bookingType.bookingsPathPrefix}/$bookingId/payments',
      data: {'provider': provider.apiValue, 'amount': amount},
    );
    return Payment.fromJson(response.data!);
  }

  Future<BookingStatus> getBookingStatus({
    required PaymentBookingType bookingType,
    required String bookingId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${bookingType.bookingsPathPrefix}/$bookingId',
    );
    return parseBookingStatus(response.data!['status'] as String);
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(apiClientProvider));
});
