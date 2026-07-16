enum EventCategory { concert, conference, sports, festival, theater, other }

extension EventCategoryApiValue on EventCategory {
  String get apiValue => switch (this) {
    EventCategory.concert => 'CONCERT',
    EventCategory.conference => 'CONFERENCE',
    EventCategory.sports => 'SPORTS',
    EventCategory.festival => 'FESTIVAL',
    EventCategory.theater => 'THEATER',
    EventCategory.other => 'OTHER',
  };

  String get label => switch (this) {
    EventCategory.concert => 'Concert',
    EventCategory.conference => 'Conférence',
    EventCategory.sports => 'Sport',
    EventCategory.festival => 'Festival',
    EventCategory.theater => 'Théâtre',
    EventCategory.other => 'Autre',
  };
}

EventCategory parseEventCategory(String raw) {
  return EventCategory.values.firstWhere((value) => value.apiValue == raw, orElse: () => EventCategory.other);
}

/// Full event record - shared by every screen that needs it (passenger
/// search/detail, event_organizer management) since the backend's
/// EventResponse already returns the same complete shape to everyone.
class Event {
  const Event({
    required this.id,
    required this.name,
    required this.description,
    required this.venue,
    required this.countryId,
    required this.cityId,
    required this.startDatetime,
    required this.endDatetime,
    required this.category,
    required this.organizerId,
    required this.isVerified,
    required this.isActive,
  });

  final String id;
  final String name;
  final String? description;
  final String venue;
  final String countryId;
  final String cityId;
  final DateTime startDatetime;
  final DateTime endDatetime;
  final EventCategory category;
  final String organizerId;
  final bool isVerified;
  final bool isActive;

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      venue: json['venue'] as String,
      countryId: json['country_id'] as String,
      cityId: json['city_id'] as String,
      startDatetime: DateTime.parse(json['start_datetime'] as String),
      endDatetime: DateTime.parse(json['end_datetime'] as String),
      category: parseEventCategory(json['category'] as String),
      organizerId: json['organizer_id'] as String,
      isVerified: json['is_verified'] as bool,
      isActive: json['is_active'] as bool,
    );
  }
}
