List<(String, int)> parseReceiptItems(String text) {
  final items = <(String, int)>[];
  final amountAtEnd = RegExp(
    r'(?:₱|PHP|\$)?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*$',
    caseSensitive: false,
  );
  final excludedNames = RegExp(
    r'^(total|subtotal|sub[- ]?total|tax|vat|service|cash|change|discount|amount due)',
    caseSensitive: false,
  );

  for (final rawLine in text.split(RegExp(r'[\r\n]+'))) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final match = amountAtEnd.firstMatch(line);
    if (match == null) continue;

    var name = line.substring(0, match.start).trim();
    name = name.replaceFirst(RegExp(r'^[-•\d.\s]+'), '').trim();
    if (name.isEmpty || excludedNames.hasMatch(name)) continue;

    final amountParts = match.group(1)!.replaceAll(',', '').split('.');
    final wholePesos = int.tryParse(amountParts.first);
    final centavos = amountParts.length == 1
        ? 0
        : int.tryParse(amountParts.last.padRight(2, '0'));
    if (wholePesos == null || centavos == null) continue;

    final amount = wholePesos * 100 + centavos;
    if (amount > 0) items.add((name, amount));
  }

  return items;
}
