/// The backend hardcodes every payment's currency to GNF (see
/// PaymentService) regardless of what a route's currency_id points at,
/// so there's only ever one currency to format for right now. Shared
/// across every domain that shows a price (transport, hotels, ...) -
/// not domain-specific itself.
String formatGnf(num amount) {
  final rounded = amount.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(digits[i]);
  }

  return '${rounded < 0 ? '-' : ''}$buffer FG';
}
