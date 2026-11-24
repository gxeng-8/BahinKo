// Widget tests for the M1 screens: App Lock, Create Group, Members, Invite.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bahinko/data/in_memory_group_service.dart';
import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/screens/group/group_detail_screen.dart';
import 'package:bahinko/screens/auth/app_lock_screen.dart';
import 'package:bahinko/screens/group/create_group_screen.dart';
import 'package:bahinko/screens/group/invite_members_screen.dart';
import 'package:bahinko/screens/group/join_group_screen.dart';
import 'package:bahinko/screens/group/members_screen.dart';
import 'package:bahinko/screens/shell.dart';
import 'package:bahinko/services/app_lock_service.dart';
import 'package:bahinko/services/auth_service.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/utils/currency.dart';

import 'fakes.dart';

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
  late InMemoryGroupService service;

  setUp(() {
    // Fresh sample data for every test so they don't affect each other.
    groupMembers.value = people;
    service = InMemoryGroupService();
    GroupService.instance = service;
    AuthService.instance = FakeAuthService(name: 'Renz');
    AppLockService.instance = AppLockService(); // fresh, no PIN yet
  });

  test('parseInviteCode accepts codes and links, rejects junk', () {
    expect(parseInviteCode('dj7q2'), 'DJ7Q2');
    expect(parseInviteCode('  https://bahinko.app/j/DJ7Q2 '), 'DJ7Q2');
    expect(parseInviteCode('bahinko.app/j/bh4k9/'), 'BH4K9');
    expect(parseInviteCode('https://bahinko-303f2.web.app/j/NX3NP'), 'NX3NP');
    expect(parseInviteCode('bahinko://join/nx3np'), 'NX3NP');
    expect(parseInviteCode('DJ7Q'), isNull); // too short
    expect(parseInviteCode('DJ0Q2'), isNull); // 0 isn't used in codes
    expect(parseInviteCode('hello world'), isNull);
  });

  testWidgets('join: validates the code, reports unknown codes, joins', (
    tester,
  ) async {
    _phoneSize(tester);
    await tester.pumpWidget(_app(const JoinGroupScreen()));
    expect(find.text('Renz'), findsOneWidget); // name pre-filled

    await tester.enterText(find.byKey(const ValueKey('invite-code')), 'abc');
    await tester.tap(find.text('Join group'));
    await tester.pumpAndSettle();
    expect(
      find.text('Codes are 5 letters/numbers, like DJ7Q2'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const ValueKey('invite-code')), 'ZZZZZ');
    await tester.tap(find.text('Join group'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No group found with code ZZZZZ. Check the code and try again.',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('invite-code')),
      'bahinko.app/j/bh4k9',
    );
    await tester.tap(find.text('Join group'));
    await tester.pumpAndSettle();
    expect(find.text('Boarding House Bills'), findsOneWidget); // its page
    final boarding = service.groups.firstWhere((g) => g.id == 'boarding-house');
    expect(boarding.members.last.name, 'Renz');
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

    await _typePin(tester, '482915');
    expect(find.text('Confirm your PIN'), findsOneWidget);
    await _typePin(tester, '999111');
    expect(find.text("PINs don't match. Try again."), findsOneWidget);

    await _typePin(tester, '482915');
    await _typePin(tester, '482915');
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

    expect(service.groups.first.name, 'Baguio Trip'); // newest first
    expect(service.groups.first.members.length, 2); // You + Mia
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
    await tester.pump(); // let the group stream deliver its data

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
    await tester.pump(); // let the group stream deliver its data

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

  testWidgets('group detail: loading first, then error with Retry', (
    tester,
  ) async {
    _phoneSize(tester);
    GroupService.instance = _OfflineService();
    await tester.pumpWidget(_app(const GroupDetail(groupId: 'x')));

    // Loading state: the stream hasn't delivered anything yet.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump();
    expect(find.text("Can't reach the server."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

/// A service whose every stream fails, like a phone with no internet.
class _OfflineService extends InMemoryGroupService {
  Stream<T> _fail<T>() =>
      Stream.error(const GroupFailure("Can't reach the server."));

  @override
  Stream<List<Group>> watchMyGroups() => _fail();
  @override
  Stream<Group> watchGroup(String groupId) => _fail();
  @override
  Stream<List<GroupExpense>> watchExpenses(String groupId) => _fail();
  @override
  Future<Group> createGroup({
    required String name,
    required GroupCategory category,
    required List<Person> others,
  }) => Future.error(const GroupFailure("Can't reach the server."));
  @override
  Future<void> addGuest(String groupId, String name) =>
      Future.error(const GroupFailure("Can't reach the server."));

  @override
  Future<String> joinGroup(String code, String yourName) =>
      Future.error(const GroupFailure("Can't reach the server."));
  @override
  Future<void> ensureInvite(Group group) async {}
}
