/// The five ways to split an expense on Add Expense (Figma Frame 6):
/// Equal · By item · Exact · Percent · Shares.
///
/// Plain functions, no Flutter or Firebase, so they are unit-tested
/// (test/split_modes_test.dart). Every function returns shares in whole
/// centavos that add up EXACTLY to the total: leftover centavos from
/// rounding go to the members with the biggest remainders (the "largest
/// remainder" method), so nobody is ever charged a centavo too much or the
/// payer left a centavo short.
library;

import 'package:bahinko/models/expense.dart';
import 'package:bahinko/utils/currency.dart';

enum SplitMode {
  equal('Equal'),
  byItem('By item'),
  exact('Exact'),
  percent('Percent'),
  shares('Shares');

  const SplitMode(this.label);

  /// Text on the segmented control.
  final String label;

  /// Stored on the expense as `splitMode` (e.g. 'byItem').
  static SplitMode fromName(String? name) => SplitMode.values.firstWhere(
    (m) => m.name == name,
    orElse: () => SplitMode.equal,
  );
}

/// Splits [totalCents] in proportion to [weights] (memberId → weight).
/// Members with weight 0 get nothing. Example: ₱100 with weights
/// {a: 2, b: 1} → {a: 6667, b: 3333}.
Map<String, int> splitByWeights(int totalCents, Map<String, int> weights) {
  final active = {
    for (final w in weights.entries)
      if (w.value > 0) w.key: w.value,
  };
  final weightSum = active.values.fold(0, (a, b) => a + b);
  if (weightSum == 0 || totalCents <= 0) return {};

  final shares = <String, int>{};
  final remainders = <String, int>{};
  var given = 0;
  for (final w in active.entries) {
    final exact = totalCents * w.value; // share × weightSum, kept as int
    shares[w.key] = exact ~/ weightSum;
    remainders[w.key] = exact % weightSum;
    given += shares[w.key]!;
  }
  // Hand out the leftover centavos: biggest remainder first, then by the
  // order members were listed (so the result never changes between runs).
  final order = active.keys.toList();
  final byRemainder = order.toList()
    ..sort((a, b) {
      final c = remainders[b]!.compareTo(remainders[a]!);
      return c != 0 ? c : order.indexOf(a).compareTo(order.indexOf(b));
    });
  for (var i = 0; i < totalCents - given; i++) {
    shares[byRemainder[i]] = shares[byRemainder[i]]! + 1;
  }
  return shares;
}

/// Splits by percent. [basisPoints] are hundredths of a percent
/// (12.5% = 1250) and must add up to 10000 (100%).
Map<String, int> splitByPercent(int totalCents, Map<String, int> basisPoints) =>
    splitByWeights(totalCents, basisPoints);

/// Splits receipt items: each item is shared equally by the members it is
/// assigned to (or by [everyone] if nobody was picked), then each member's
/// item shares are added up.
Map<String, int> splitByItems(List<ExpenseItem> items, List<String> everyone) {
  final shares = <String, int>{};
  for (final item in items) {
    final who = item.assignedTo.isEmpty ? everyone : item.assignedTo;
    final part = splitByWeights(item.amountCents, {
      for (final id in who) id: 1,
    });
    for (final p in part.entries) {
      shares[p.key] = (shares[p.key] ?? 0) + p.value;
    }
  }
  return shares;
}

/// Reads a percent typed by the user ("25", "12.5", "33.33") as basis
/// points (2500, 1250, 3333). Null if it isn't a valid percent.
int? parsePercent(String text) {
  final t = text.trim();
  if (t.isEmpty) return 0;
  // Same format as money (up to 2 decimals), so reuse the peso parser.
  final bp = parsePesosToCents(t);
  if (bp == null || bp > 10000) return null;
  return bp;
}

/// Everything the user entered on the form, turned into shares.
/// Returns the shares, or an error message to show under the split list.
({Map<String, int>? shares, String? error}) buildShares({
  required SplitMode mode,
  required int totalCents,
  required List<String> memberIds,

  /// Equal: who is included.
  Set<String> included = const {},

  /// Exact: memberId → centavos.
  Map<String, int> exact = const {},

  /// Percent: memberId → basis points.
  Map<String, int> percent = const {},

  /// Shares: memberId → number of shares (e.g. 2 for someone who ate more).
  Map<String, int> weights = const {},

  /// By item: the receipt items with their assignees.
  List<ExpenseItem> items = const [],
}) {
  if (totalCents <= 0) return (shares: null, error: 'Enter the amount first.');
  Map<String, int> ok(Map<String, int> s) => {
    for (final e in s.entries)
      if (e.value > 0) e.key: e.value,
  };

  switch (mode) {
    case SplitMode.equal:
      final who = [
        for (final id in memberIds)
          if (included.contains(id)) id,
      ];
      if (who.isEmpty) {
        return (shares: null, error: 'Choose at least one person.');
      }
      return (
        shares: splitByWeights(totalCents, {for (final id in who) id: 1}),
        error: null,
      );

    case SplitMode.exact:
      final sum = exact.values.fold(0, (a, b) => a + b);
      if (sum != totalCents) {
        final diff = totalCents - sum;
        return (
          shares: null,
          error: diff > 0
              ? '${formatMoney(diff)} left to assign'
              : '${formatMoney(-diff)} over the total',
        );
      }
      return (shares: ok(exact), error: null);

    case SplitMode.percent:
      final sum = percent.values.fold(0, (a, b) => a + b);
      if (sum != 10000) {
        return (
          shares: null,
          error: 'Percents add up to ${_percentText(sum)}, not 100%',
        );
      }
      return (shares: splitByPercent(totalCents, percent), error: null);

    case SplitMode.shares:
      if (weights.values.every((w) => w <= 0)) {
        return (shares: null, error: 'Give at least one person a share.');
      }
      return (shares: splitByWeights(totalCents, weights), error: null);

    case SplitMode.byItem:
      if (items.isEmpty) return (shares: null, error: 'Add at least one item.');
      final itemsTotal = items.fold(0, (a, i) => a + i.amountCents);
      if (itemsTotal != totalCents) {
        return (
          shares: null,
          error:
              'Items add up to ${formatMoney(itemsTotal)}, '
              'not ${formatMoney(totalCents)}',
        );
      }
      return (shares: ok(splitByItems(items, memberIds)), error: null);
  }
}

/// 3333 → "33.33%", 10000 → "100%".
String _percentText(int bp) =>
    bp % 100 == 0 ? '${bp ~/ 100}%' : '${(bp / 100).toStringAsFixed(2)}%';
