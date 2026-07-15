enum DayOfWeek { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

extension DayOfWeekApiValue on DayOfWeek {
  String get apiValue => switch (this) {
    DayOfWeek.monday => 'MONDAY',
    DayOfWeek.tuesday => 'TUESDAY',
    DayOfWeek.wednesday => 'WEDNESDAY',
    DayOfWeek.thursday => 'THURSDAY',
    DayOfWeek.friday => 'FRIDAY',
    DayOfWeek.saturday => 'SATURDAY',
    DayOfWeek.sunday => 'SUNDAY',
  };

  String get shortLabel => switch (this) {
    DayOfWeek.monday => 'Lun',
    DayOfWeek.tuesday => 'Mar',
    DayOfWeek.wednesday => 'Mer',
    DayOfWeek.thursday => 'Jeu',
    DayOfWeek.friday => 'Ven',
    DayOfWeek.saturday => 'Sam',
    DayOfWeek.sunday => 'Dim',
  };

  static DayOfWeek fromApiValue(String raw) {
    return DayOfWeek.values.firstWhere((value) => value.apiValue == raw, orElse: () => DayOfWeek.monday);
  }
}

enum ScheduleStatus { active, inactive, unknown }

extension ScheduleStatusLabel on ScheduleStatus {
  String get label => switch (this) {
    ScheduleStatus.active => 'Actif',
    ScheduleStatus.inactive => 'Inactif',
    ScheduleStatus.unknown => 'Statut inconnu',
  };
}

ScheduleStatus _parseScheduleStatus(String raw) {
  switch (raw) {
    case 'ACTIVE':
      return ScheduleStatus.active;
    case 'INACTIVE':
      return ScheduleStatus.inactive;
    default:
      return ScheduleStatus.unknown;
  }
}

class ManagedSchedule {
  const ManagedSchedule({
    required this.id,
    required this.companyId,
    required this.routeId,
    required this.departureTime,
    required this.estimatedArrivalTime,
    required this.operatingDays,
    required this.status,
  });

  final String id;
  final String companyId;
  final String routeId;
  // Bare "HH:MM:SS" strings - the backend schedule has no date/timezone
  // component, only trips (which combine a schedule with a travel_date)
  // do.
  final String departureTime;
  final String? estimatedArrivalTime;
  final List<DayOfWeek> operatingDays;
  final ScheduleStatus status;

  factory ManagedSchedule.fromJson(Map<String, dynamic> json) {
    return ManagedSchedule(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      routeId: json['route_id'] as String,
      departureTime: json['departure_time'] as String,
      estimatedArrivalTime: json['estimated_arrival_time'] as String?,
      operatingDays: (json['operating_days'] as List<dynamic>)
          .map((day) => DayOfWeekApiValue.fromApiValue(day as String))
          .toList(),
      status: _parseScheduleStatus(json['status'] as String),
    );
  }
}
