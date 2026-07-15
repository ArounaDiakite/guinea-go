class Currency {
  const Currency({required this.id, required this.code, required this.name, required this.symbol});

  final String id;
  final String code;
  final String name;
  final String symbol;

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      symbol: json['symbol'] as String,
    );
  }
}
