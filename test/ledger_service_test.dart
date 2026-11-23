// Tests for the expense / payment / activity / recurring parts of
// GroupService (using the in-memory version; Firestore follows the same
// contract and is checked against the real database separately).
import 'package:flutter_test/flutter_test.dart';

import 'package:bahinko/data/in_memory_group_service.dart';
import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/recurring_bill.dart';
import 'package:bahinko/services/group_service.dart';

void main() {
  late InMemoryGroupService service;

  setUp(() {
    groupMembers.value = people;
    service = InMemoryGroupService();
  });

  Group demo() => service.groups.firstWhere((g) => g.id == demoGroupId);

  GroupExpense pizza({Map<String, int>? shares}) => GroupExpense.create(
    title: 'Pizza',
    paidById: 'me',
    paidByName: 'You',
    amountCents: 60000,
    shares: shares ?? {'me': 20000, 'mia': 20000, 'jun': 20000},
    category: 'Dinner',
  );

  test('GroupExpense.create works out split count and unpaid members', () {
    final e = pizza();
    expect(e.splitWays, 3);
    expect(e.unpaidCount, 2); // everyone except the payer
  });

  test('models survive a save/load round trip (toMap → fromMap)', () {
    final e = pizza();
    final back = GroupExpense.fromMap(e.toMap(), id: 'x');
    expect(back.title, 'Pizza');
    expect(back.shares, {'me': 20000, 'mia': 20000, 'jun': 20000});

    const p = Payment(
      fromId: 'jun',
      fromName: 'Jun',
      toId: 'me',
      toName: 'You',
      amountCents: 20000,
      method: 'gcash',
      expenseId: 'e1',
    );
    final pBack = Payment.fromMap('p1', p.toMap());
    expect(pBack.method, 'gcash');
    expect(pBack.expenseId, 'e1');

    final bill = RecurringBill(
      'WiFi',
      'Every month',
      '₱1,400',
      true,
      amountCents: 140000,
      dayOfMonth: 2,
    );
    expect(RecurringBill.fromMap('b1', bill.toMap()).amountCents, 140000);
  });

  test('addExpense rejects shares that do not add up to the total', () async {
    expect(
      () => service.addExpense(
        demoGroupId,
        pizza(shares: {'me': 20000, 'mia': 20000}),
      ),
      throwsA(
        isA<GroupFailure>().having(
          (f) => f.message,
          'message',
          contains('Shares add up to ₱400.00'),
        ),
      ),
    );
  });

  test('addExpense saves it, updates totals, and logs activity', () async {
    final before = demo();
    final id = await service.addExpense(demoGroupId, pizza());

    final after = demo();
    expect(after.totalCents, before.totalCents + 60000);
    expect(after.expenseCount, before.expenseCount + 1);
    // "N unpaid" is recalculated from balances (setUnpaidCount), not here.
    expect(after.unpaidCount, before.unpaidCount);

    final saved = await service.watchExpense(demoGroupId, id).first;
    expect(saved.title, 'Pizza');

    final feed = await service.watchActivity(demoGroupId).first;
    expect(feed.first.type, 'expense');
    expect(feed.first.text, 'You added Pizza');
  });

  test('a confirmed full payment makes one fewer member unpaid', () async {
    final id = await service.addExpense(demoGroupId, pizza());
    final unpaidBefore = demo().unpaidCount;

    await service.recordPayment(
      demoGroupId,
      Payment(
        fromId: 'jun',
        fromName: 'Jun',
        toId: 'me',
        toName: 'You',
        amountCents: 20000,
        expenseId: id,
      ),
    );
    final pending = (await service.watchPayments(demoGroupId).first).first;
    expect(pending.status, 'pending');

    await service.confirmPayment(demoGroupId, pending);
    final confirmed = (await service.watchPayments(demoGroupId).first).first;
    expect(confirmed.isConfirmed, isTrue);
    expect(demo().unpaidCount, unpaidBefore - 1);

    final expense = await service.watchExpense(demoGroupId, id).first;
    expect(expense.unpaidCount, 1);

    final feed = await service.watchActivity(demoGroupId).first;
    expect(feed.map((e) => e.type), containsAllInOrder(['confirm', 'payment']));
  });

  test('payments to yourself or of ₱0 are rejected', () {
    expect(
      () => service.recordPayment(
        demoGroupId,
        const Payment(
          fromId: 'me',
          fromName: 'You',
          toId: 'me',
          toName: 'You',
          amountCents: 100,
        ),
      ),
      throwsA(isA<GroupFailure>()),
    );
  });

  test('recurring bills are saved, sorted by due day, and toggled', () async {
    await service.addRecurring(
      demoGroupId,
      RecurringBill('Rent', 'Every month', '₱12,000', true, dayOfMonth: 5),
    );
    await service.addRecurring(
      demoGroupId,
      RecurringBill('WiFi', 'Every month', '₱1,400', true, dayOfMonth: 2),
    );
    var bills = await service.watchRecurring(demoGroupId).first;
    expect(bills.map((b) => b.name), ['WiFi', 'Rent']);

    await service.setRecurringEnabled(demoGroupId, bills.first.id, false);
    bills = await service.watchRecurring(demoGroupId).first;
    expect(bills.first.enabled, isFalse);
  });

  test('the sample group has expenses with payers and shares', () async {
    final expenses = await service.watchExpenses(demoGroupId).first;
    final samgyup = expenses.firstWhere((e) => e.id == 'samgyup');
    expect(samgyup.items, isNotEmpty);
    expect(samgyup.shares.values.fold(0, (a, b) => a + b), samgyup.amountCents);
  });
}
