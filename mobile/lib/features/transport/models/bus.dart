class Bus {
  const Bus({
    required this.id,
    required this.registrationNumber,
    required this.brand,
    required this.model,
    required this.busType,
    required this.seatCapacity,
    required this.airConditioning,
    required this.wifi,
    required this.usbCharging,
    required this.toilet,
    required this.television,
  });

  final String id;
  final String registrationNumber;
  final String brand;
  final String model;
  final String busType;
  final int seatCapacity;
  final bool airConditioning;
  final bool wifi;
  final bool usbCharging;
  final bool toilet;
  final bool television;

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['id'] as String,
      registrationNumber: json['registration_number'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      busType: json['bus_type'] as String,
      seatCapacity: json['seat_capacity'] as int,
      airConditioning: json['air_conditioning'] as bool,
      wifi: json['wifi'] as bool,
      usbCharging: json['usb_charging'] as bool,
      toilet: json['toilet'] as bool,
      television: json['television'] as bool,
    );
  }
}
