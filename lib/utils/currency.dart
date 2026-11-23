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
