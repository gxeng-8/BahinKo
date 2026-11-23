// Unit tests for the Settle Up money math (no Flutter, no Firebase).
import 'package:flutter_test/flutter_test.dart';

import 'package:bahinko/models/group.dart';
import 'package:bahinko/utils/settle_calculator.dart';

GroupExpense bill(String payer, Map<String, int> shares) => GroupExpense.create(
  title: 'Bill',
  paidById: payer,
  paidByName: payer,
  amountCents: shares.values.fold(0, (a, b) => a + b),
  shares: shares,
);

Payment paid(String from, String to, int cents, {bool confirmed = true}) =>
    Payment(
      fromId: from,
      fromName: from,
      toId: to,
      toName: to,
      amountCents: cents,
      status: confirmed ? 'confirmed' : 'pending',
    );

void main() {
  test('balances: shares are owed to the payer and always sum to zero', () {
    final b = computeBalances([
      bill('A', {'A': 100, 'B': 100, 'C': 100}),
      bill('B', {'A': 50, 'B': 50}),
    ], []);
    // A is owed 100 (B) + 100 (C) - 50 (A's share of B's bill) = 150.
    // B owes A 100 but is owed 50 by A: -50. C owes A 100.
    expect(b, {'A': 150, 'B': -50, 'C': -100});
    expect(b.values.fold(0, (a, v) => a + v), 0);
  });

  test('only confirmed payments reduce balances', () {
    final expenses = [
      bill('A', {'A': 100, 'B': 100}),
    ];
    expect(computeBalances(expenses, [paid('B', 'A', 100, confirmed: false)]), {
      'A': 100,
      'B': -100,
    });
    expect(computeBalances(expenses, [paid('B', 'A', 100)]), isEmpty);
  });

  test('smart settle needs fewer transfers than paying each bill', () {
    // A paid for everyone, then B paid for everyone.
    final expenses = [
      bill('A', {'A': 300, 'B': 300, 'C': 300}),
      bill('B', {'A': 300, 'B': 300, 'C': 300}),
    ];
    final transfers = smartSettle(computeBalances(expenses, []));
    expect(naiveTransferCount(expenses), 4); // B→A, C→A, A→B, C→B
    expect(transfers.length, 2); // C pays A 300, C pays B 300
    expect(transfers.every((t) => t.fromId == 'C'), isTrue);
  });

  test('after the smart-settle transfers, everyone is at zero', () {
    final balances = {'A': 500, 'B': -200, 'C': -250, 'D': -50};
    final after = Map.of(balances);
    for (final t in smartSettle(balances)) {
      after[t.fromId] = after[t.fromId]! + t.amountCents;
      after[t.toId] = after[t.toId]! - t.amountCents;
    }
    expect(after.values.every((v) => v == 0), isTrue);
  });

  test('splitEqually always adds up to the exact total', () {
    final s = splitEqually(10000, ['a', 'b', 'c']); // ₱100 ÷ 3
    expect(s, {'a': 3334, 'b': 3333, 'c': 3333});
    expect(s.values.fold(0, (a, b) => a + b), 10000);
    expect(splitEqually(500, const []), isEmpty);
  });

  test('pendingBetween sums only pending payments for that pair', () {
    final payments = [
      paid('B', 'A', 100, confirmed: false),
      paid('B', 'A', 50, confirmed: false),
      paid('B', 'A', 999),
      paid('C', 'A', 70, confirmed: false),
    ];
    expect(pendingBetween(payments, 'B', 'A'), 150);
  });
}
