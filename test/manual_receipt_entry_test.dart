import 'dart:async';

import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/receipt_line_item.dart';
import 'package:bahinko/screens/bill/manual_receipt_entry_screen.dart';
import 'package:bahinko/screens/bill/split_summary_screen.dart';
import 'package:bahinko/screens/group/invite_members_screen.dart';
import 'package:bahinko/screens/group/members_screen.dart';
import 'package:bahinko/screens/history/activity_history_screen.dart';
import 'package:bahinko/screens/history/personal_ledger_screen.dart';
import 'package:bahinko/screens/recurring/recurring_bills_screen.dart';
import 'package:bahinko/screens/settle/settle_up_screen.dart';
import 'package:bahinko/models/person.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => groupMembers.value = people);
  tearDown(() => groupMembers.value = people);

  testWidgets('settle up shows every current member and current headcount', (
    tester,
  ) async {
    groupMembers.value = [
      ...people,
      const Person('Nina', 'NI', Colors.blue, 'Guest', 'Unpaid'),
    ];

    await tester.pumpWidget(const MaterialApp(home: SettleUp()));

    expect(find.text('6 people'), findsOneWidget);
    expect(find.text('5 payments to Mia'), findsOneWidget);
    expect(find.text('Jun pays Mia'), findsOneWidget);
    expect(find.text('Ana pays Mia'), findsOneWidget);
    expect(find.text('Leo pays Mia'), findsOneWidget);
    expect(find.text('You pays Mia'), findsOneWidget);
    expect(find.text('Nina pays Mia'), findsOneWidget);
  });

  testWidgets('settle up uses the receipt total and marks payments paid', (
    tester,
  ) async {
    groupMembers.value = [
      ...people,
      const Person('Nina', 'NI', Colors.blue, 'Guest', 'Unpaid'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SplitSummary(
          receiptItems: const [
            ReceiptLineItem('Coffee', 12550),
            ReceiptLineItem('Cake', 20227),
          ],
          storeName: 'Cafe',
        ),
      ),
    );
    await tester.tap(find.text('Settle Up'));
    await tester.pumpAndSettle();

    expect(find.text('Cafe'), findsOneWidget);
    expect(find.text('6 people'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('₱327.77'), findsOneWidget);
    expect(find.text('5 payments to Mia'), findsOneWidget);
    expect(find.text('Jun pays Mia'), findsOneWidget);
    expect(find.text('Nina pays Mia'), findsOneWidget);
    expect(find.text('₱54.63'), findsNWidgets(4));
    expect(find.text('₱54.62'), findsOneWidget);

    final ninaPaymentButton = find.byKey(const ValueKey('settle-payment-5'));
    await tester.ensureVisible(ninaPaymentButton);
    await tester.tap(ninaPaymentButton);
    await tester.pump();

    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
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
