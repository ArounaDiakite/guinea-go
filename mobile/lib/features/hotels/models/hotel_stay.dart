/// Just the two dates a search was made for - passed via GoRouter's
/// `extra` from results to detail to booking, since none of those
/// routes carry check_in/check_out as a path parameter.
class HotelStay {
  const HotelStay({required this.checkIn, required this.checkOut});

  final DateTime checkIn;
  final DateTime checkOut;

  int get nights => checkOut.difference(checkIn).inDays;
}
