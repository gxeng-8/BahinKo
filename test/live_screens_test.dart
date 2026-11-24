// Statistics, Personal Ledger, Activity History, Recurring Bills, Delete my
// data and the payment reference: all on real (in-memory) data now.
//
// Sample group "Dinner at Jaro": Samgyup House ₱2,500 (you paid) and Milk
// Tea Run ₱450 (Mia paid). So Jun owes you ₱845, Ana ₱620, Leo ₱395 and
// Mia ₱20: ₱1,880 in total.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bahinko/data/in_memory_group_service.dart';
import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/recurring_bill.dart';
import 'package:bahinko/screens/history/activity_history_screen.dart';
import 'package:bahinko/screens/history/personal_ledger_screen.dart';
import 'package:bahinko/screens/recurring/recurring_bills_screen.dart';
import 'package:bahinko/screens/settings/privacy_screen.dart';
import 'package:bahinko/screens/settle/widgets/payment_proof_dialog.dart';
import 'package:bahinko/screens/stats/statistics_screen.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/services/settings_service.dart';
import 'package:bahinko/utils/insights.dart';
import 'package:bahinko/utils/settle_calculator.dart';

void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> show(WidgetTester tester, Widget screen) async {
  tallScreen(tester);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pump();
  await tester.pump();
}

GroupService get service => GroupService.instance;

void main() {
  setUp(() {
    groupMembers.value = people;
    GroupService.instance = InMemoryGroupService();
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance = SettingsService();
  });

  group('insights math', () {
    test('stats: owed, monthly share, categories', () async {
      await service.recordPayment(
        demoGroupId,
        const Payment(
          fromId: 'ana',
          fromName: 'Ana',
          toId: 'me',
          toName: 'You',
          amountCents: 62000,
          status: 'confirmed',
        ),
      );
      final s = buildStats(
        await service.watchAllLedgers().first,
        'me',
        now: DateTime(2026, 11, 5),
      );
      expect(s.owedToYou, 188000 - 62000); // Ana paid
      expect(s.youOwe, 0);
      expect(s.collected, 62000);
      expect(s.months.length, 6);
      final oct = s.months.firstWhere((m) => m.month == DateTime(2026, 10));
      expect(oct.myShareCents, 47000 + 15000);
      expect(oct.iPaidCents, 250000);
      expect(s.categories.single.name, 'Dinner');
      expect(s.categories.single.percent, 100);
    });

    test('categories after the top 3 are grouped as Other', () {
      const g = Group(
        id: 'g',
        name: 'G',
        category: GroupCategory('Bills', Icons.abc, ''),
        members: [],
        inviteCode: 'X',
      );
      GroupExpense e(String cat, int cents) => GroupExpense.create(
        title: cat,
        paidById: 'x',
        paidByName: 'X',
        amountCents: cents,
        shares: {'me': cents},
        category: cat,
      );
      final s = buildStats([
        GroupLedger(g, [
          e('Dinner', 5000),
          e('Trips', 3000),
          e('Bills', 1000),
          e('Groceries', 600),
          e('Utilities', 400),
        ], []),
      ], 'me');
      expect(s.categories.map((c) => c.name), [
        'Dinner',
        'Trips',
        'Bills',
        'Other',
      ]);
      expect(s.categories.last.cents, 1000);
      expect(s.categories.first.percent, 50);
    });

    test('personal ledger adds up transfers per person', () async {
      final lines = buildPersonalLedger(
        await service.watchAllLedgers().first,
        'me',
      );
      expect(
        {for (final l in lines) l.person.name: l.netCents},
        {'Jun': 84500, 'Ana': 62000, 'Leo': 39500, 'Mia': 2000},
      );
      expect(lines.first.person.name, 'Jun'); // biggest first
      expect(lines.first.groups.values.single.name, 'Dinner at Jaro');
    });

    test('recurring bills: next due date and ordinals', () {
      final rent = RecurringBill.create(
        name: 'Rent',
        amountCents: 200000,
        dayOfMonth: 31,
      );
      expect(rent.schedule, 'Every month on the 31st');
      expect(rent.amount, '₱2,000.00');
      expect(rent.nextDue(DateTime(2026, 2, 10)), DateTime(2026, 2, 28));
      expect(rent.nextDue(DateTime(2026, 3, 31)), DateTime(2026, 3, 31));
      final wifi = RecurringBill.create(
        name: 'WiFi',
        amountCents: 150000,
        dayOfMonth: 5,
        varies: true,
      );
      expect(wifi.amount, '≈₱1,500.00');
      expect(wifi.nextDue(DateTime(2026, 12, 20)), DateTime(2027, 1, 5));
      expect(RecurringBill.ordinal(12), '12th');
      expect(RecurringBill.ordinal(22), '22nd');
    });

    test('payment reference numbers are cleaned and checked', () {
      expect(normalizeReference('1009 876 543 210'), '1009876543210');
      expect(normalizeReference('ab-12cd34'), 'AB12CD34');
      expect(normalizeReference('12'), isNull);
      expect(normalizeReference('12345!!'), isNull);
    });
  });

  testWidgets('Statistics shows real totals and categories', (tester) async {
    await show(tester, const Statistics());
    expect(find.text('₱1,880.00'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Open Personal Ledger'), findsOneWidget);
  });

  testWidgets('Personal Ledger lists who owes you', (tester) async {
    await show(tester, const PersonalLedger());
    expect(find.byKey(const ValueKey('ledger-net')), findsOneWidget);
    expect(find.text('₱1,880.00'), findsWidgets);
    expect(find.text('+₱845.00'), findsOneWidget); // Jun
    expect(find.text('+₱20.00'), findsOneWidget); // Mia
    expect(find.text('Owes you · Dinner at Jaro'), findsNWidgets(4));
  });

  testWidgets('Activity History: real events, filters and search', (
    tester,
  ) async {
    await service.addExpense(
      demoGroupId,
      GroupExpense.create(
        title: 'Taxi',
        paidById: 'me',
        paidByName: 'You',
        amountCents: 30000,
        shares: const {'me': 15000, 'jun': 15000},
      ),
    );
    await service.recordPayment(
      demoGroupId,
      const Payment(
        fromId: 'jun',
        fromName: 'Jun',
        toId: 'me',
        toName: 'You',
        amountCents: 15000,
        status: 'confirmed',
      ),
    );
    await service.logActivity(
      demoGroupId,
      const ActivityEvent(type: 'reminder', text: 'Reminder sent to Leo'),
    );
    await show(tester, const ActivityHistory());
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('You added Taxi'), findsOneWidget);
    expect(find.text('Jun paid You'), findsOneWidget);
    expect(find.text('Reminder sent to Leo'), findsOneWidget);

    await tester.tap(find.text('Payments'));
    await tester.pump();
    expect(find.text('Jun paid You'), findsOneWidget);
    expect(find.text('You added Taxi'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('activity-search')),
      'leo',
    );
    await tester.pump();
    expect(find.text('Reminder sent to Leo'), findsOneWidget);
    expect(find.text('Jun paid You'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('activity-search')),
      'zzz',
    );
    await tester.pump();
    expect(find.text('Nothing matches.'), findsOneWidget);
  });

  testWidgets('Activity History shows edits as old → new price', (
    tester,
  ) async {
    final milk = await service.watchExpense(demoGroupId, 'milktea').first;
    await service.updateExpense(
      demoGroupId,
      milk,
      GroupExpense.create(
        title: 'Milk Tea Run',
        paidById: 'mia',
        paidByName: 'Mia',
        amountCents: 60000,
        shares: const {'mia': 20000, 'me': 20000, 'jun': 20000},
      ),
    );
    await show(tester, const ActivityHistory(groupId: demoGroupId));
    await tester.tap(find.text('Edits'));
    await tester.pump();
    expect(find.text('You edited Milk Tea Run'), findsOneWidget);
    expect(find.text('₱450.00'), findsOneWidget);
    expect(find.text('₱600.00'), findsOneWidget);
  });

  testWidgets('Recurring Bills: validated add, pause, saved to the group', (
    tester,
  ) async {
    await show(tester, const RecurringBills(groupId: demoGroupId));
    expect(find.textContaining('No recurring bills yet'), findsOneWidget);

    await tester.tap(find.text('+ Add recurring bill'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('recurring-day')), '40');
    await tester.tap(find.byKey(const ValueKey('recurring-save')));
    await tester.pump();
    expect(find.text('Enter a name, like Rent or WiFi'), findsOneWidget);
    expect(find.text('Enter the amount'), findsOneWidget);
    expect(find.text('A day from 1 to 31'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('recurring-name')),
      'Internet',
    );
    await tester.enterText(
      find.byKey(const ValueKey('recurring-amount')),
      '999',
    );
    await tester.enterText(find.byKey(const ValueKey('recurring-day')), '20');
    await tester.tap(find.byKey(const ValueKey('recurring-save')));
    await tester.pumpAndSettle();

    expect(find.text('Internet'), findsOneWidget);
    expect(find.text('₱999.00'), findsOneWidget);
    expect(find.text('₱999.00 monthly · 5 members'), findsOneWidget);
    final saved = await service.watchRecurring(demoGroupId).first;
    expect(saved.single.dayOfMonth, 20);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('₱0.00 monthly · 5 members'), findsOneWidget);
  });

  testWidgets('Delete my data needs a tick before it can run', (tester) async {
    await show(tester, const Privacy());
    expect(find.text('Receipts stay on your phone'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('delete-my-data')));
    await tester.tap(find.byKey(const ValueKey('delete-my-data')));
    await tester.pumpAndSettle();
    FilledButton confirm() =>
        tester.widget(find.byKey(const ValueKey('delete-confirm')));
    expect(confirm().onPressed, isNull); // disabled
    await tester.tap(find.byKey(const ValueKey('delete-understood')));
    await tester.pump();
    expect(confirm().onPressed, isNotNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete my data?'), findsNothing);
  });

  testWidgets('payment proof returns the reference number', (tester) async {
    String? result = 'not set';
    tallScreen(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showDialog<String>(
              context: context,
              builder: (_) => PaymentProofDialog(
                member: people.last,
                payer: people.first,
                provider: 'GCash',
                amountInCents: 84500,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('₱845.00'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('payment-proof-reference')),
      '12',
    );
    await tester.tap(find.byKey(const ValueKey('payment-proof-confirm')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('submit-payment-proof')));
    await tester.pump();
    expect(find.text('Use 6–20 letters or numbers'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('payment-proof-reference')),
      '1009 876 543 210',
    );
    await tester.tap(find.byKey(const ValueKey('submit-payment-proof')));
    await tester.pumpAndSettle();
    expect(result, '1009876543210');
  });
}
