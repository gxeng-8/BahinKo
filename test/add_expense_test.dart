// Widget tests for Add Expense (Figma 6) and partial payments on Settle Up.
// Uses the in-memory sample data: the "Dinner at Jaro" group with
// Mia, Jun, Ana, Leo and You (id 'me').
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bahinko/data/in_memory_group_service.dart';
import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/group.dart';
import 'package:bahinko/screens/bill/add_expense_screen.dart';
import 'package:bahinko/screens/settle/settle_up_screen.dart';
import 'package:bahinko/services/group_service.dart';

/// A tall screen so the whole form fits without scrolling.
void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> openForm(WidgetTester tester, {List<ExpenseItem>? items}) async {
  tallScreen(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: AddExpense(groupId: demoGroupId, title: 'Hotpot', items: items),
    ),
  );
  await tester.pump(); // groups load
}

/// The newest saved expense in the sample group.
Future<GroupExpense> newestExpense() async =>
    (await GroupService.instance.watchExpenses(demoGroupId).first).first;

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('save-expense')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    groupMembers.value = people;
    GroupService.instance = InMemoryGroupService();
  });

  testWidgets('the form checks the name and amount', (tester) async {
    await openForm(tester);
    await tester.enterText(find.byKey(const ValueKey('expense-name')), '');
    await save(tester);
    expect(find.text('Enter what the expense was for'), findsOneWidget);
    expect(find.text('Enter the amount'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '0');
    await save(tester);
    expect(find.text('The amount must be more than ₱0'), findsOneWidget);
  });

  testWidgets('equal split among the people who are ticked', (tester) async {
    await openForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('expense-amount')),
      '2000',
    );
    await tester.tap(find.byKey(const ValueKey('include-leo'))); // untick Leo
    await tester.pump();
    expect(find.text('₱500.00'), findsNWidgets(4));

    await save(tester);
    final e = await newestExpense();
    expect(e.title, 'Hotpot');
    expect(e.splitMode, 'equal');
    expect(e.paidById, 'me'); // default payer: you
    expect(e.shares, {'mia': 50000, 'jun': 50000, 'ana': 50000, 'me': 50000});
    expect(find.text('Saved to Dinner at Jaro'), findsOneWidget);
  });

  testWidgets('exact amounts must add up before saving', (tester) async {
    await openForm(tester);
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '500');
    await tester.tap(find.byKey(const ValueKey('mode-exact')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('exact-jun')), '200');
    await tester.pump();
    expect(find.text('₱300.00 left to assign'), findsOneWidget);

    final before =
        (await GroupService.instance.watchExpenses(demoGroupId).first).length;
    await save(tester);
    expect(
      (await GroupService.instance.watchExpenses(demoGroupId).first).length,
      before, // not saved
    );

    await tester.enterText(find.byKey(const ValueKey('exact-me')), '300');
    await tester.pump();
    expect(find.byKey(const ValueKey('split-error')), findsNothing);
    await save(tester);
    expect((await newestExpense()).shares, {'jun': 20000, 'me': 30000});
  });

  testWidgets('percent: "Fill in evenly" makes it add up to 100%', (
    tester,
  ) async {
    await openForm(tester);
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '100');
    await tester.tap(find.byKey(const ValueKey('mode-percent')));
    await tester.pump();
    expect(find.text('Percents add up to 0%, not 100%'), findsOneWidget);
    await tester.tap(find.text('Fill in evenly'));
    await tester.pump();
    await save(tester);
    final e = await newestExpense();
    expect(e.splitMode, 'percent');
    expect(e.shares.values.every((s) => s == 2000), isTrue); // 5 × ₱20
  });

  testWidgets('shares: someone with 2 shares pays double', (tester) async {
    await openForm(tester);
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '600');
    await tester.tap(find.byKey(const ValueKey('mode-shares')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('more-jun')));
    await tester.pump();
    expect(find.text('₱200.00'), findsOneWidget); // Jun: 2 of 6 shares
    await save(tester);
    expect((await newestExpense()).shares['jun'], 20000);
  });

  testWidgets('by item: assign an item to one person', (tester) async {
    await openForm(
      tester,
      items: const [
        ExpenseItem(name: 'Soju', amountCents: 30000),
        ExpenseItem(name: 'Rice', amountCents: 5000),
      ],
    );
    // Starts in By item mode with the amount = items total.
    expect(find.text('350'), findsOneWidget);
    expect(find.text('Everyone'), findsNWidgets(2));

    await tester.tap(find.text('Soju'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-jun')));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await save(tester);

    final e = await newestExpense();
    expect(e.splitMode, 'byItem');
    expect(e.items.first.assignedTo, ['jun']);
    expect(e.shares['jun'], 30000 + 1000); // all the Soju + ⅕ of the Rice
    expect(e.shares['mia'], 1000);
  });

  group('partial payments', () {
    Future<void> openSettle(WidgetTester tester) async {
      tallScreen(tester);
      await tester.pumpWidget(
        const MaterialApp(home: SettleUp(groupId: demoGroupId)),
      );
      await tester.pump();
    }

    testWidgets('"Got part of it" lowers the debt by that much', (
      tester,
    ) async {
      await openSettle(tester);
      expect(find.text('₱845.00'), findsOneWidget); // Jun owes you
      await tester.tap(find.byKey(const ValueKey('partial-jun-me')));
      await tester.pumpAndSettle();

      // Can't record more than is owed.
      await tester.enterText(
        find.byKey(const ValueKey('partial-amount')),
        '900',
      );
      await tester.tap(find.byKey(const ValueKey('partial-submit')));
      await tester.pump();
      expect(find.text('Only ₱845.00 is owed'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('partial-amount')),
        '300',
      );
      await tester.tap(find.byKey(const ValueKey('partial-submit')));
      await tester.pumpAndSettle();
      expect(find.text('₱845.00'), findsNothing);
      expect(find.text('₱545.00'), findsOneWidget); // what's left
    });

    testWidgets('a pending partial payment leaves the rest payable', (
      tester,
    ) async {
      // In the sample, others owe you. A big bill Mia paid flips that, so
      // YOU owe Mia.
      await GroupService.instance.addExpense(
        demoGroupId,
        GroupExpense.create(
          title: 'Taxi',
          paidById: 'mia',
          paidByName: 'Mia',
          amountCents: 1000000,
          shares: const {'mia': 500000, 'me': 500000},
        ),
      );
      // You already sent part of it (Mia has the app → pending).
      await GroupService.instance.recordPayment(
        demoGroupId,
        const Payment(
          fromId: 'me',
          fromName: 'You',
          toId: 'mia',
          toName: 'Mia',
          amountCents: 1000,
          method: 'gcash',
        ),
      );
      await openSettle(tester);
      expect(find.text('You pay'), findsOneWidget);
      expect(find.textContaining('waiting for confirmation'), findsOneWidget);
      expect(find.textContaining('left to pay'), findsOneWidget);
      expect(find.text('Pay part of it'), findsOneWidget);
    });
  });
}
