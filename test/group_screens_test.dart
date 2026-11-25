// Widget tests for the M1 screens: App Lock, Create Group, Members, Invite.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/screens/auth/app_lock_screen.dart';
import 'package:bahinko/screens/group/create_group_screen.dart';
import 'package:bahinko/screens/group/invite_members_screen.dart';
import 'package:bahinko/screens/group/members_screen.dart';
import 'package:bahinko/screens/shell.dart';
import 'package:bahinko/utils/currency.dart';

Widget _app(Widget home) => MaterialApp(home: home);

/// Phone-sized test window so long forms fit like on a real device.
void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _typePin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.text(d));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // Reset shared sample data so tests don't affect each other.
    groupMembers.value = people;
    groups.value = groups.value.take(2).toList();
  });

  test('formatMoney adds commas and two decimals', () {
    expect(formatMoney(106000), '₱1,060.00');
    expect(formatMoney(1200000), '₱12,000.00');
    expect(formatMoney(5), '₱0.05');
    expect(formatMoney(-35000), '-₱350.00');
  });

  testWidgets('app lock: mismatched PIN shows error, matching PIN opens app', (
    tester,
  ) async {
    _phoneSize(tester);
    await tester.pumpWidget(_app(const AppLockScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Create a PIN'), findsOneWidget);

    await _typePin(tester, '1234');
    expect(find.text('Confirm your PIN'), findsOneWidget);
    await _typePin(tester, '9999');
    expect(find.text("PINs don't match. Try again."), findsOneWidget);

    await _typePin(tester, '1234');
    await _typePin(tester, '1234');
    expect(find.byType(Shell), findsOneWidget);
  });

  testWidgets('create group: shows errors, then creates a valid group', (
    tester,
  ) async {
    _phoneSize(tester);
    await tester.pumpWidget(_app(const CreateGroup()));

    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle();
    expect(find.text('Give your group a name'), findsOneWidget);
    expect(find.text('Add at least one other member'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('group-name')), 'Ba');
    await tester.pumpAndSettle();
    expect(find.text('Name must be at least 3 characters'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('group-name')),
      'Baguio Trip',
    );
    await tester.tap(find.text('MI')); // select Mia's avatar
    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle();

    expect(groups.value.last.name, 'Baguio Trip');
    expect(groups.value.last.members.value.length, 2);
    expect(
      find.text('No expenses yet. Add one or scan a receipt.'),
      findsOneWidget,
    );
  });

  testWidgets('members: search filters the list and shows an empty state', (
    tester,
  ) async {
    _phoneSize(tester);
    await tester.pumpWidget(_app(const Members()));

    await tester.enterText(find.byKey(const ValueKey('member-search')), 'mi');
    await tester.pump();
    expect(find.text('Mia'), findsOneWidget);
    expect(find.text('Jun'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('member-search')), 'zzz');
    await tester.pump();
    expect(find.text('No members match "zzz"'), findsOneWidget);
  });

  testWidgets('invite: guest form validates and adds a guest', (tester) async {
    _phoneSize(tester);
    await tester.pumpWidget(_app(const InviteMembers()));

    await tester.ensureVisible(find.text('Add guest'));
    await tester.tap(find.text('Add guest'));
    await tester.pumpAndSettle();
    expect(find.text("Enter the guest's name"), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('guest-name')), 'Mia');
    await tester.tap(find.text('Add guest'));
    await tester.pumpAndSettle();
    expect(find.text('Mia is already in this group'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('guest-name')), 'Rico');
    await tester.tap(find.text('Add guest'));
    await tester.pumpAndSettle();
    expect(groupMembers.value.last.name, 'Rico');
    expect(find.text('6 members', findRichText: true), findsNothing);
    expect(find.text('Scan to join · 6 members'), findsOneWidget);
  });
}
