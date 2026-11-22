import 'dart:async';

import 'package:bahinko/main.dart';
import 'package:bahinko/models/person.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => groupMembers.value = people);
  tearDown(() => groupMembers.value = people);

  testWidgets('settle up shows every current member except yourself', (
    tester,
  ) async {
    groupMembers.value = [
      ...people,
      const Person('Nina', 'NI', Colors.blue, 'Guest', 'Unpaid'),
    ];

    await tester.pumpWidget(const MaterialApp(home: SettleUp()));

    expect(find.text('You pay Mia'), findsOneWidget);
    expect(find.text('Jun pays you'), findsOneWidget);
    expect(find.text('Ana paid you'), findsOneWidget);
    expect(find.text('Leo pays you'), findsOneWidget);
    expect(find.text('Nina · Unpaid'), findsOneWidget);
    expect(find.text('You pays you'), findsNothing);
  });

  testWidgets('receipt splitting uses the current Members page count', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Members()));

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
}
