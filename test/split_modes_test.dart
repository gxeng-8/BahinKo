// Unit tests for the Add Expense split math (utils/split_modes.dart).
import 'package:flutter_test/flutter_test.dart';

import 'package:bahinko/models/group.dart';
import 'package:bahinko/utils/split_modes.dart';

int sum(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);

void main() {
  test('splitByWeights is proportional and adds up exactly', () {
    final s = splitByWeights(10000, {'a': 2, 'b': 1});
    expect(s, {'a': 6667, 'b': 3333});
    expect(sum(s), 10000);
    // Weight 0 = not included.
    expect(splitByWeights(900, {'a': 1, 'b': 0, 'c': 2}), {'a': 300, 'c': 600});
    expect(splitByWeights(900, {'a': 0}), isEmpty);
  });

  test('leftover centavos go to the biggest remainders, never lost', () {
    for (final total in [1, 7, 100, 99999, 250000]) {
      final s = splitByWeights(total, {'a': 1, 'b': 1, 'c': 1});
      expect(sum(s), total, reason: 'total $total');
      final values = s.values.toList()..sort();
      expect(values.last - values.first, lessThanOrEqualTo(1));
    }
  });

  test('percent split: 33.33 / 33.33 / 33.34 of ₱100', () {
    final s = splitByPercent(10000, {'a': 3333, 'b': 3333, 'c': 3334});
    expect(s, {'a': 3333, 'b': 3333, 'c': 3334});
  });

  test('by item: each item is shared only by who had it', () {
    final s = splitByItems(
      const [
        ExpenseItem(name: 'Soju', amountCents: 300, assignedTo: ['a', 'b']),
        ExpenseItem(name: 'Rice', amountCents: 100), // nobody picked = all
      ],
      ['a', 'b', 'c'],
    );
    expect(s, {'a': 184, 'b': 183, 'c': 33});
    expect(sum(s), 400);
  });

  test('parsePercent reads typed percents as basis points', () {
    expect(parsePercent('25'), 2500);
    expect(parsePercent('12.5'), 1250);
    expect(parsePercent(''), 0);
    expect(parsePercent('101'), isNull);
    expect(parsePercent('abc'), isNull);
  });

  group('buildShares explains what is wrong', () {
    const ids = ['a', 'b'];

    test('exact: money left or over', () {
      expect(
        buildShares(
          mode: SplitMode.exact,
          totalCents: 1000,
          memberIds: ids,
          exact: {'a': 300, 'b': 200},
        ).error,
        '₱5.00 left to assign',
      );
      expect(
        buildShares(
          mode: SplitMode.exact,
          totalCents: 1000,
          memberIds: ids,
          exact: {'a': 800, 'b': 300},
        ).error,
        '₱1.00 over the total',
      );
      final ok = buildShares(
        mode: SplitMode.exact,
        totalCents: 1000,
        memberIds: ids,
        exact: {'a': 1000, 'b': 0},
      );
      expect(ok.shares, {'a': 1000}); // zero shares are left out
    });

    test('percent must add up to 100%', () {
      expect(
        buildShares(
          mode: SplitMode.percent,
          totalCents: 1000,
          memberIds: ids,
          percent: {'a': 5000, 'b': 2550},
        ).error,
        'Percents add up to 75.50%, not 100%',
      );
    });

    test('equal needs someone; by item must match the amount', () {
      expect(
        buildShares(
          mode: SplitMode.equal,
          totalCents: 1000,
          memberIds: ids,
        ).error,
        'Choose at least one person.',
      );
      expect(
        buildShares(
          mode: SplitMode.byItem,
          totalCents: 1000,
          memberIds: ids,
          items: const [ExpenseItem(name: 'X', amountCents: 900)],
        ).error,
        'Items add up to ₱9.00, not ₱10.00',
      );
      expect(
        buildShares(
          mode: SplitMode.shares,
          totalCents: 0,
          memberIds: ids,
        ).error,
        'Enter the amount first.',
      );
    });
  });

  test('split mode and date survive a save/load round trip', () {
    final e = GroupExpense.create(
      title: 'Samgyup House',
      paidById: 'a',
      paidByName: 'A',
      amountCents: 250000,
      shares: const {'a': 125000, 'b': 125000},
      splitMode: 'percent',
      spentOn: DateTime(2026, 10, 28),
    );
    final map = e.toMap();
    expect(map['spentOn'], '2026-10-28');
    final back = GroupExpense.fromMap(map);
    expect(back.splitMode, 'percent');
    expect(back.spentOn, DateTime(2026, 10, 28));
    expect(SplitMode.fromName(back.splitMode), SplitMode.percent);
    expect(SplitMode.fromName('nonsense'), SplitMode.equal);
  });
}
