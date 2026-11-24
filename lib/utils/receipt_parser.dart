/// The basic (rule-based) receipt parser: the fallback when the AI is
/// unavailable. Also home of [looksLikeNonItem], which the AI's answer is
/// checked with too.
///
/// Receipts are full of numbers that are NOT prices: dates, times, OR/SI
/// numbers, TIN, table no., cashier IDs, item counts. So a line only counts
/// as an item when:
///   1. its name has real words (not a label like "OR No." or "Date"),
///   2. the line has no date or time in it,
///   3. the price looks like money: centavos ("125.00") or a ₱/PHP sign,
///   4. it comes BEFORE the total (cash, change, VAT info come after).
library;

/// Labels that start a non-item line. Matched at the start of the name.
final _nonItemLabel = RegExp(
  r'^(sub[- ]?total|total|grand total|amount due|balance|tax|vat|vatable|'
  r'vat[- ]?exempt|zero[- ]?rated|service|svc|cash|change|tendered|'
  r'payment|paid|discount|less|senior|pwd|gcash|maya|card|credit|debit|'
  r'date|time|or\b|o\.r|si\b|s\.i|invoice|receipt|rcpt|ref|reference|'
  r'trans|txn|order|ord|table|tbl|pax|guest|cover|cashier|server|'
  r'waiter|staff|terminal|pos\b|min\b|sn\b|s/n|serial|ptu|accr|permit|'
  r'tin\b|tel|phone|mobile|cp\b|no\.?\s|no\b|#|qty|items?\b|'
  r'no\.? of items|thank|visit|www|http)(?![a-z])',
  caseSensitive: false,
);

/// Dates (11/24/2026, 2026-11-24, Nov 24, 2026) and times (10:45, 7:30PM).
final _dateOrTime = RegExp(
  r'\b\d{1,4}[/-]\d{1,2}[/-]\d{1,4}\b|\b\d{1,2}:\d{2}\b|'
  r'\b(jan(uary)?|feb(ruary)?|mar(ch)?|apr(il)?|may|june?|july?|aug(ust)?|'
  r'sept?(ember)?|oct(ober)?|nov(ember)?|dec(ember)?)\.?\s+\d{1,2}\b',
  caseSensitive: false,
);

/// True for names that aren't something people ordered: labels like
/// "OR No.", "Date", "Total", or names with no real word in them.
bool looksLikeNonItem(String name) {
  final n = name.trim();
  if (n.isEmpty) return true;
  if (!RegExp(r'[A-Za-z]{2,}').hasMatch(n)) return true; // "#0012", "--"
  if (_nonItemLabel.hasMatch(n)) return true;
  return _dateOrTime.hasMatch(n);
}

/// Above this a single line is almost surely an ID number, not a price.
const _maxItemCents = 100000 * 100; // ₱100,000

List<(String, int)> parseReceiptItems(String text) {
  final items = <(String, int)>[];
  // Money at the end of the line: "125.00", "1,250.50", "₱80", "PHP 80".
  final amountAtEnd = RegExp(
    r'((?:₱|PHP|(?<![A-Za-z])P(?=\s?\d)|\$)?)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{2})?|[0-9]+(?:\.[0-9]{2})?)\s*[A-Z]?\s*$',
    caseSensitive: false,
  );
  final totalLine = RegExp(
    r'^\s*(total|grand total|amount due|total due)\b',
    caseSensitive: false,
  );

  for (final rawLine in text.split(RegExp(r'[\r\n]+'))) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    // Everything after the TOTAL is payment info and footer, not items.
    if (totalLine.hasMatch(line) && items.isNotEmpty) break;
    if (_dateOrTime.hasMatch(line)) continue;

    final match = amountAtEnd.firstMatch(line);
    if (match == null) continue;
    final hasCurrency = match.group(1)!.isNotEmpty;
    final number = match.group(2)!;
    // "Table 12" or "OR 000123" end in a plain whole number; real prices
    // on receipts show centavos (".00") or a peso sign.
    if (!hasCurrency && !number.contains('.')) continue;

    var name = line.substring(0, match.start).trim();
    // Drop a leading quantity like "2 ", "2x ", "1 @".
    name = name
        .replaceFirst(
          RegExp(r'^[-•*\s]*\d+\s*(x|@|pcs?)?\s+', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+\d+\s*@\s*[\d.,]+$'), '') // "Rice 5 @ 50.00"
        .trim();
    if (looksLikeNonItem(name)) continue;

    final parts = number.replaceAll(',', '').split('.');
    final pesos = int.tryParse(parts.first);
    final centavos = parts.length == 1 ? 0 : int.tryParse(parts.last);
    if (pesos == null || centavos == null) continue;

    final amount = pesos * 100 + centavos;
    if (amount > 0 && amount <= _maxItemCents) items.add((name, amount));
  }

  return items;
}
