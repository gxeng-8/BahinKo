/// The money math for Settle Up (Figma 12). Plain functions, no Flutter or
/// Firebase, so they're easy to unit-test and explain.
///
/// 1. [computeBalances]: for each member, how much they are owed (+) or
///    owe (−) across ALL of the group's expenses, minus confirmed payments.
/// 2. [smartSettle]: the fewest transfers that make every balance zero
///    ("Smart settle: 3 transfers instead of 6").
///
/// Money is in centavos (int), so there are no rounding errors.
library;

import 'package:bahinko/models/group.dart';

/// "[fromId] pays [toId] [amountCents]".
class Transfer {
  const Transfer(this.fromId, this.toId, this.amountCents);

  final String fromId, toId;
  final int amountCents;

  @override
  String toString() => '$fromId → $toId: $amountCents';
}

/// Net balance per member ID: positive = others owe them, negative = they
/// owe. Only CONFIRMED payments count; pending ones are still "on the way".
Map<String, int> computeBalances(
  Iterable<GroupExpense> expenses,
  Iterable<Payment> payments,
) {
  final balances = <String, int>{};
  void add(String id, int cents) => balances[id] = (balances[id] ?? 0) + cents;

  for (final e in expenses) {
    for (final share in e.shares.entries) {
      // The payer's own share is already "paid" by them.
      if (share.key == e.paidById || share.value <= 0) continue;
      add(share.key, -share.value); // this member owes their share…
      add(e.paidById, share.value); // …to the person who paid the bill
    }
  }
  for (final p in payments.where((p) => p.isConfirmed)) {
    add(p.fromId, p.amountCents); // paying reduces what you owe
    add(p.toId, -p.amountCents); // receiving reduces what you're owed
  }
  balances.removeWhere((_, cents) => cents == 0);
  return balances;
}

/// The fewest transfers that settle everyone (greedy algorithm):
/// repeatedly let the person who owes the MOST pay the person who is owed
/// the MOST, as much as possible. Each step settles at least one person,
/// so there are at most (people − 1) transfers.
List<Transfer> smartSettle(Map<String, int> balances) {
  // Sort biggest first; ties by ID so the result is always the same.
  int byAmount(MapEntry<String, int> a, MapEntry<String, int> b) {
    final c = b.value.abs().compareTo(a.value.abs());
    return c != 0 ? c : a.key.compareTo(b.key);
  }

  final debtors = [
    for (final e in balances.entries)
      if (e.value < 0) MapEntry(e.key, -e.value),
  ]..sort(byAmount);
  final creditors = [
    for (final e in balances.entries)
      if (e.value > 0) e,
  ]..sort(byAmount);

  final transfers = <Transfer>[];
  var d = 0, c = 0;
  var owe = debtors.isEmpty ? 0 : debtors[0].value;
  var owed = creditors.isEmpty ? 0 : creditors[0].value;
  while (d < debtors.length && c < creditors.length) {
    final amount = owe < owed ? owe : owed;
    transfers.add(Transfer(debtors[d].key, creditors[c].key, amount));
    owe -= amount;
    owed -= amount;
    if (owe == 0 && ++d < debtors.length) owe = debtors[d].value;
    if (owed == 0 && ++c < creditors.length) owed = creditors[c].value;
  }
  return transfers;
}

/// How many transfers there would be WITHOUT smart settle: everyone pays
/// each bill's payer separately (one per member per payer). Used for the
/// "N transfers instead of M" banner.
int naiveTransferCount(Iterable<GroupExpense> expenses) => {
  for (final e in expenses)
    for (final share in e.shares.entries)
      if (share.key != e.paidById && share.value > 0)
        '${share.key}→${e.paidById}',
}.length;

/// Splits [totalCents] equally among [memberIds]. Leftover centavos go to
/// the first members, so the shares always add up to exactly the total
/// (₱100 ÷ 3 = 33.34 + 33.33 + 33.33).
Map<String, int> splitEqually(int totalCents, List<String> memberIds) {
  if (memberIds.isEmpty) return const {};
  final base = totalCents ~/ memberIds.length;
  final extra = totalCents % memberIds.length;
  return {
    for (var i = 0; i < memberIds.length; i++)
      memberIds[i]: base + (i < extra ? 1 : 0),
  };
}

/// Total of pending (not yet confirmed) payments from [fromId] to [toId].
int pendingBetween(Iterable<Payment> payments, String fromId, String toId) =>
    payments
        .where((p) => !p.isConfirmed && p.fromId == fromId && p.toId == toId)
        .fold(0, (sum, p) => sum + p.amountCents);

/// Everything Settle Up needs about one group, loaded together.
class GroupLedger {
  GroupLedger(this.group, this.expenses, this.payments);

  final Group group;
  final List<GroupExpense> expenses;
  final List<Payment> payments;

  late final Map<String, int> balances = computeBalances(expenses, payments);
  late final List<Transfer> transfers = smartSettle(balances);
  late final int naiveTransfers = naiveTransferCount(expenses);

  /// Members who still owe money (shown as "N unpaid").
  int get debtorCount => balances.values.where((b) => b < 0).length;

  bool get settled => transfers.isEmpty;
}
