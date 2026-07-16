enum TicketCategory { standard, vip, earlyBird, student }

extension TicketCategoryApiValue on TicketCategory {
  String get apiValue => switch (this) {
    TicketCategory.standard => 'STANDARD',
    TicketCategory.vip => 'VIP',
    TicketCategory.earlyBird => 'EARLY_BIRD',
    TicketCategory.student => 'STUDENT',
  };

  String get label => switch (this) {
    TicketCategory.standard => 'Standard',
    TicketCategory.vip => 'VIP',
    TicketCategory.earlyBird => 'Early bird',
    TicketCategory.student => 'Étudiant',
  };
}

TicketCategory parseTicketCategory(String raw) {
  return TicketCategory.values.firstWhere((value) => value.apiValue == raw, orElse: () => TicketCategory.standard);
}

class TicketType {
  const TicketType({
    required this.id,
    required this.eventId,
    required this.category,
    required this.basePrice,
    required this.currencyId,
    required this.quantityTotal,
    required this.quantityAvailable,
    required this.description,
    required this.isActive,
  });

  final String id;
  final String eventId;
  final TicketCategory category;
  final double basePrice;
  final String currencyId;
  final int quantityTotal;
  final int quantityAvailable;
  final String? description;
  final bool isActive;

  factory TicketType.fromJson(Map<String, dynamic> json) {
    return TicketType(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      category: parseTicketCategory(json['category'] as String),
      basePrice: (json['base_price'] as num).toDouble(),
      currencyId: json['currency_id'] as String,
      quantityTotal: json['quantity_total'] as int,
      quantityAvailable: json['quantity_available'] as int,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool,
    );
  }
}
