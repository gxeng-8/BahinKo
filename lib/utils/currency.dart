/// Peso parsing and formatting. Money is stored as integer centavos.
library;

int? parsePesosToCents(String value) {
  final trimmed = value.trim();
  if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(trimmed) ||
      trimmed.isEmpty ||
      trimmed == '.') {
    return null;
  }

  final parts = trimmed.split('.');
  final wholePesos = parts.first.isEmpty ? 0 : int.tryParse(parts.first);
  if (wholePesos == null || wholePesos > 9000000000000) return null;

  final centavos = parts.length == 1 || parts.last.isEmpty
      ? 0
      : int.tryParse(parts.last.padRight(2, '0'));
  if (centavos == null) return null;
  return wholePesos * 100 + centavos;
}

String formatCurrency(int amountInCents) {
  final pesos = amountInCents ~/ 100;
  final centavos = amountInCents % 100;
  return centavos == 0
      ? '₱$pesos'
      : '₱$pesos.${centavos.toString().padLeft(2, '0')}';
}

/// Formats centavos the way the Figma designs show money:
/// thousands separators and always two decimals, e.g. 106000 → "₱1,060.00".
/// Negative amounts get a minus sign in front: -35000 → "-₱350.00".
String formatMoney(int amountInCents) {
  final sign = amountInCents < 0 ? '-' : '';
  final cents = amountInCents.abs();
  final pesos = (cents ~/ 100).toString();
  // Insert a comma every 3 digits from the right: "12000" → "12,000".
  final withCommas = pesos.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final centavos = (cents % 100).toString().padLeft(2, '0');
  return '$sign₱$withCommas.$centavos';
}
