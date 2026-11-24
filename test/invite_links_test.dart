import 'package:flutter_test/flutter_test.dart';

import 'package:bahinko/app.dart';
import 'package:bahinko/models/group.dart';
import 'package:bahinko/screens/group/join_group_screen.dart';
import 'package:bahinko/services/auth_service.dart';
import 'package:bahinko/services/invite_links.dart';

import 'fakes.dart';

void main() {
  setUp(() => AuthService.instance = FakeAuthService(name: 'Renz'));

  test('invite links point to the hosted page, not bahinko.app', () {
    expect(Group.inviteLinkBase, 'https://bahinko-303f2.web.app/j/');
  });

  test('reads the code from web and app links, ignores other links', () {
    expect(
      inviteCodeFromUri(Uri.parse('https://bahinko-303f2.web.app/j/NX3NP')),
      'NX3NP',
    );
    expect(inviteCodeFromUri(Uri.parse('bahinko://join/nx3np')), 'NX3NP');
    expect(inviteCodeFromUri(Uri.parse('bahinko://join/TOOLONG')), isNull);
    expect(
      inviteCodeFromUri(Uri.parse('https://bahinko-303f2.web.app/')),
      isNull,
    );
    expect(inviteCodeFromUri(Uri.parse('https://example.com/x/NX3NP')), isNull);
  });

  testWidgets('a waiting invite opens Join with the code filled in', (
    tester,
  ) async {
    pendingInvite.value = 'NX3NP';
    await tester.pumpWidget(
      const BahinKoApp(signedIn: true, lockOnStart: false),
    );
    await tester.pumpAndSettle();
    expect(find.byType(JoinGroupScreen), findsOneWidget);
    expect(find.text('NX3NP'), findsOneWidget);
    expect(pendingInvite.value, isNull); // handled only once
  });

  testWidgets('an invite tapped while the app is open also opens Join', (
    tester,
  ) async {
    await tester.pumpWidget(
      const BahinKoApp(signedIn: true, lockOnStart: false),
    );
    await tester.pumpAndSettle();
    expect(find.byType(JoinGroupScreen), findsNothing);
    pendingInvite.value = 'DJ7Q2';
    await tester.pumpAndSettle();
    expect(find.text('DJ7Q2'), findsOneWidget);
  });

  testWidgets('waits behind the PIN screen until unlocked', (tester) async {
    pendingInvite.value = 'DJ7Q2';
    await tester.pumpWidget(const BahinKoApp(signedIn: true));
    await tester.pumpAndSettle();
    expect(find.byType(JoinGroupScreen), findsNothing);
    expect(pendingInvite.value, 'DJ7Q2');
    pendingInvite.value = null;
  });
}
