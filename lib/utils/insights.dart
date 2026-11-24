/// Numbers for Statistics (Figma 19) and Personal Ledger (Figma 18),
/// computed from the ledgers of ALL my groups.
///
/// Plain functions (no Flutter / Firebase), unit-tested in
/// test/insights_test.dart. Both screens use the same balances as Home and
/// Settle Up, so every screen agrees.
library;

import 'package:bahinko/models/person.dart';
import 'package:bahinko/utils/settle_calculator.dart';

// ---------------------------------------------------------------------------
// Statistics
// ---------------------------------------------------------------------------

/// One month in the bar chart.
class MonthBar {
  const MonthBar(this.month, this.myShareCents, this.iPaidCents);

  /// First day of the month.
  final DateTime month;

  /// What MY share of that month's expenses was.
  final int myShareCents;

  /// What I paid at the counter (bills I covered for the group).
  final int iPaidCents;
}

/// One row of "Spending by category" (my share only).
class CategorySlice {
  const CategorySlice(this.name, this.cents, this.percent);

  final String name;
  final int cents;
  final int percent;
}

class SpendingStats {
  const SpendingStats({
    required this.owedToYou,
    required this.youOwe,
    required this.collected,
    required this.paidOut,
    required this.months,
    required this.categories,
    required this.totalMyShare,
  });

  final int owedToYou, youOwe;

  /// Confirmed payments I received / sent.
  final int collected, paidOut;
  final List<MonthBar> months;
  final List<CategorySlice> categories;

  /// My share of everything, all time.
  final int totalMyShare;

  bool get isEmpty => totalMyShare == 0 && collected == 0 && paidOut == 0;
}

SpendingStats buildStats(
  List<GroupLedger> ledgers,
  String myId, {
  DateTime? now,
  int monthCount = 6,
}) {
  final today = now ?? DateTime.now();
  // The last [monthCount] months, oldest first, ending with this month.
  final months = [
    for (var i = monthCount - 1; i >= 0; i--)
      DateTime(today.year, today.month - i),
  ];
  final share = {for (final m in months) m: 0};
  final paid = {for (final m in months) m: 0};
  final byCategory = <String, int>{};
  var owed = 0, owe = 0, collected = 0, paidOut = 0, total = 0;

  for (final ledger in ledgers) {
    final mine = ledger.balances[myId] ?? 0;
    if (mine > 0) owed += mine;
    if (mine < 0) owe -= mine;

    for (final e in ledger.expenses) {
      final myShare = e.shares[myId] ?? 0;
      total += myShare;
      if (myShare > 0) {
        byCategory[e.category] = (byCategory[e.category] ?? 0) + myShare;
      }
      final d = e.date;
      if (d == null) continue;
      final m = DateTime(d.year, d.month);
      if (!share.containsKey(m)) continue; // older than the chart
      share[m] = share[m]! + myShare;
      if (e.paidById == myId) paid[m] = paid[m]! + e.amountCents;
    }
    for (final p in ledger.payments.where((p) => p.isConfirmed)) {
      if (p.toId == myId) collected += p.amountCents;
      if (p.fromId == myId) paidOut += p.amountCents;
    }
  }

  // Biggest categories first; everything after the top 3 is "Other".
  final sorted = byCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top = sorted.take(3).toList();
  final rest = sorted.skip(3).fold(0, (a, e) => a + e.value);
  int pct(int c) => total == 0 ? 0 : (c * 100 / total).round();
  final categories = [
    for (final e in top) CategorySlice(e.key, e.value, pct(e.value)),
    if (rest > 0) CategorySlice('Other', rest, pct(rest)),
  ];

  return SpendingStats(
    owedToYou: owed,
    youOwe: owe,
    collected: collected,
    paidOut: paidOut,
    months: [for (final m in months) MonthBar(m, share[m]!, paid[m]!)],
    categories: categories,
    totalMyShare: total,
  );
}

// ---------------------------------------------------------------------------
// Personal Ledger
// ---------------------------------------------------------------------------

/// One person I owe or who owes me, across all shared groups.
class LedgerLine {
  LedgerLine(this.person);

  final Person person;

  /// Positive: they owe me. Negative: I owe them.
  int netCents = 0;

  /// The groups this comes from: groupId → (name, signed cents).
  final Map<String, ({String name, int cents})> groups = {};
}

/// Who owes me and whom I owe, from each group's smart-settle transfers
/// (the same ones Settle Up shows), added up per person. App users are the
/// same person in every group; guests are separate per group.
List<LedgerLine> buildPersonalLedger(List<GroupLedger> ledgers, String myId) {
  final lines = <String, LedgerLine>{};
  for (final ledger in ledgers) {
    final group = ledger.group;
    for (final t in ledger.transfers) {
      final String otherId;
      final int signed;
      if (t.toId == myId) {
        otherId = t.fromId;
        signed = t.amountCents;
      } else if (t.fromId == myId) {
        otherId = t.toId;
        signed = -t.amountCents;
      } else {
        continue; // between two other people
      }
      final person =
          group.memberById(otherId) ??
          personFromName('Former member', id: otherId);
      final line = lines.putIfAbsent(otherId, () => LedgerLine(person));
      line.netCents += signed;
      final before = line.groups[group.id]?.cents ?? 0;
      line.groups[group.id] = (name: group.name, cents: before + signed);
    }
  }
  final list = lines.values.where((l) => l.netCents != 0).toList()
    // People who owe me first (biggest first), then whom I owe.
    ..sort((a, b) => b.netCents.compareTo(a.netCents));
  return list;
}
