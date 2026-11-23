import 'dart:async';

import 'package:bahinko/data/in_memory_group_service.dart';
import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/group.dart';
import 'package:bahinko/screens/bill/manual_receipt_entry_screen.dart';
import 'package:bahinko/screens/group/invite_members_screen.dart';
import 'package:bahinko/screens/group/members_screen.dart';
import 'package:bahinko/screens/history/activity_history_screen.dart';
import 'package:bahinko/screens/history/personal_ledger_screen.dart';
import 'package:bahinko/screens/recurring/recurring_bills_screen.dart';
import 'package:bahinko/screens/settle/settle_up_screen.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    groupMembers.value = people;
    GroupService.instance = InMemoryGroupService(); // fresh sample data
  });
  tearDown(() => groupMembers.value = people);

  testWidgets('settle up shows smart-settle transfers from real balances', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SettleUp(groupId: demoGroupId)),
    );
    await tester.pump(); // let the ledger stream deliver

    // Sample group: Samgyup (₱2,500, you paid) + Milk Tea (₱450, Mia paid).
    expect(
      find.textContaining('Smart settle: 4 transfers instead of 6'),
      findsOneWidget,
    );
    expect(find.text('Pays you'), findsOneWidget);
    expect(find.text('₱845.00'), findsOneWidget); // Jun: 695 + 150
    expect(find.text('₱620.00'), findsOneWidget); // Ana
  });

  testWidgets('"Got cash" records a payment and updates the balances', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: SettleUp(groupId: demoGroupId)),
    );
    await tester.pump();

    await tester.tap(find.text('Got cash').first); // Jun, the biggest debt
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, record it'));
    await tester.pumpAndSettle();

    expect(find.text('₱845.00'), findsNothing); // Jun is settled
    expect(find.textContaining('3 transfers'), findsOneWidget);
  });

  testWidgets('a pending payment to you can be confirmed', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await GroupService.instance.recordPayment(
      demoGroupId,
      const Payment(
        fromId: 'ana',
        fromName: 'Ana',
        toId: 'me',
        toName: 'You',
        amountCents: 62000,
        method: 'gcash',
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(home: SettleUp(groupId: demoGroupId)),
    );
    await tester.pump();
    expect(find.text('Waiting for you to confirm'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for you to confirm'), findsNothing);
    expect(find.text('₱620.00'), findsNothing); // Ana is settled
  });

  testWidgets('a group with no expenses is all settled up', (tester) async {
    final group = await GroupService.instance.createGroup(
      name: 'Empty Trip',
      category: groupCategories.first,
      others: const [],
    );
    await tester.pumpWidget(MaterialApp(home: SettleUp(groupId: group.id)));
    await tester.pump();
    expect(find.text('All settled up!'), findsOneWidget);
  });

  testWidgets('receipt splitting uses the current Members page count', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Members()));
    await tester.pump(); // Members now loads its group from a stream

    expect(find.text('Dinner at Jaro members (5)'), findsOneWidget);
    await tester.tap(find.byTooltip('Add member'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('new-member-name')),
      'Nina',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-add-member')));
    await tester.pumpAndSettle();

    expect(find.text('Dinner at Jaro members (6)'), findsOneWidget);
    expect(find.text('Nina'), findsOneWidget);

    unawaited(
      Navigator.of(tester.element(find.text('Nina')))
          .push(MaterialPageRoute(builder: (_) => const ManualReceiptEntry())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('receipt-sharing-count')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('receipt-item-name-0')),
      'Coffee',
    );
    await tester.enterText(
      find.byKey(const ValueKey('receipt-item-price-0')),
      '125.50',
    );
    await tester.ensureVisible(find.text('Add item'));
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('receipt-item-name-1')),
      'Cake',
    );
    await tester.enterText(
      find.byKey(const ValueKey('receipt-item-price-1')),
      '202.27',
    );
    await tester.tap(find.text('Continue to items'));
    await tester.pumpAndSettle();

    expect(find.text('2 items entered manually'), findsOneWidget);
    expect(find.text('6 people'), findsOneWidget);
    expect(find.text('₱327.77'), findsOneWidget);
    expect(find.text('₱54.62–₱54.63'), findsOneWidget);

    await tester.tap(find.text('Confirm Split'));
    await tester.pumpAndSettle();

    expect(find.text('6 people sharing'), findsOneWidget);
    expect(find.text('Each person pays'), findsOneWidget);
    expect(find.text('Mia'), findsOneWidget);
    expect(find.text('Nina'), findsOneWidget);
    expect(find.text('₱54.63'), findsWidgets);
    expect(find.text('₱54.62'), findsOneWidget);
  });

  testWidgets(
    'batch three screens are reachable and recurring bills can be added',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RecurringBills()));

      expect(find.text('Recurring Bills'), findsWidgets);
      await tester.tap(find.text('+ Add recurring bill'));
      await tester.pumpAndSettle();

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
      expect(find.text('₱999'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: ActivityHistory()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Payments'));
      await tester.pumpAndSettle();
      expect(find.text('You paid ₱320 to Mia'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: PersonalLedger()));
      await tester.pumpAndSettle();
      expect(find.text('Personal Ledger'), findsOneWidget);
      expect(find.text('₱710.00'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: InviteMembers()));
      await tester.pumpAndSettle();
      expect(find.text('Dinner at Jaro'), findsOneWidget);
      expect(find.text('Copy invite link'), findsOneWidget);
    },
  );
}
