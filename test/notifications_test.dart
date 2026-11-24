import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bahinko/app.dart';
import 'package:bahinko/data/in_memory_group_service.dart';
import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/group.dart';
import 'package:bahinko/screens/notifications/notifications_screen.dart';
import 'package:bahinko/screens/profile/profile_screen.dart';
import 'package:bahinko/services/auth_service.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/services/settings_service.dart';
import 'package:bahinko/utils/notifications.dart';
import 'package:bahinko/widgets/wallet_logo.dart';

import 'fakes.dart';

/// Someone else (Jun) does something that concerns me.
Future<void> fromJun(String type, {int cents = 84500}) =>
    GroupService.instance.logActivity(
      demoGroupId,
      ActivityEvent(
        type: type,
        actorName: 'Jun',
        actorId: 'jun',
        forIds: const ['me'],
        amountCents: cents,
        text: 'Jun $type',
      ),
    );

Future<void> openApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const BahinKoApp(signedIn: true, lockOnStart: false));
  await tester.pumpAndSettle();
}

String? badgeText(WidgetTester tester) {
  final badge = find.byKey(const ValueKey('bell-badge'));
  if (badge.evaluate().isEmpty) return null;
  return tester
      .widget<Text>(find.descendant(of: badge, matching: find.byType(Text)))
      .data;
}

void main() {
  setUp(() {
    groupMembers.value = people;
    GroupService.instance = InMemoryGroupService();
    AuthService.instance = FakeAuthService(name: 'Yumi');
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance = SettingsService();
  });

  group('rules', () {
    ActivityEvent e(String actor, List<String> forIds) => ActivityEvent(
      type: 'reminder',
      text: '',
      actorId: actor,
      forIds: forIds,
    );

    test('only news about me, made by someone else', () {
      expect(isNotificationFor(e('jun', ['me']), 'me'), isTrue);
      expect(isNotificationFor(e('me', ['me', 'jun']), 'me'), isFalse);
      expect(isNotificationFor(e('jun', ['ana']), 'me'), isFalse);
      expect(isNotificationFor(e('', ['me']), 'me'), isFalse); // old entry
    });

    test('badge counts up to 9, then shows 9+', () {
      expect(badgeLabel(0), isNull);
      expect(badgeLabel(1), '1');
      expect(badgeLabel(9), '9');
      expect(badgeLabel(10), '9+');
      expect(badgeLabel(42), '9+');
    });

    test('wording is written to me', () {
      ActivityEvent ev(String type) => ActivityEvent(
        type: type,
        text: 'x',
        actorName: 'Mia',
        amountCents: 45000,
      );
      expect(
        notificationText(ev('reminder')),
        'Mia reminded you to pay ₱450.00',
      );
      expect(
        notificationText(ev('confirm')),
        'Mia confirmed your ₱450.00 payment',
      );
      expect(notificationText(ev('payment')), contains('paid you ₱450.00'));
    });
  });

  testWidgets('bell shows the unread count and clears after opening', (
    tester,
  ) async {
    await openApp(tester);
    expect(badgeText(tester), isNull);

    await fromJun('reminder');
    await fromJun('confirm');
    await tester.pumpAndSettle();
    expect(badgeText(tester), '2');

    await tester.tap(find.byKey(const ValueKey('home-bell')));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('Jun reminded you to pay ₱845.00'), findsOneWidget);
    expect(find.text('Jun confirmed your ₱845.00 payment'), findsOneWidget);
    expect(find.byKey(const ValueKey('notification-new')), findsNWidgets(2));

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(badgeText(tester), isNull); // all read now
  });

  testWidgets('more than 9 unread shows 9+', (tester) async {
    for (var i = 0; i < 12; i++) {
      await fromJun('reminder', cents: 100 + i);
    }
    await openApp(tester);
    expect(badgeText(tester), '9+');
  });

  testWidgets('my own actions never notify me', (tester) async {
    await openApp(tester);
    await GroupService.instance.addExpense(
      demoGroupId,
      GroupExpense.create(
        amountCents: 10000,
        title: 'Snacks',
        paidById: 'me',
        paidByName: 'You',
        shares: const {'me': 5000, 'jun': 5000},
      ),
    );
    await tester.pumpAndSettle();
    expect(badgeText(tester), isNull);
  });

  testWidgets('person icon shows my initial and opens Profile', (tester) async {
    await openApp(tester);
    final icon = find.byKey(const ValueKey('home-profile'));
    expect(find.descendant(of: icon, matching: find.text('Y')), findsOneWidget);
    await tester.tap(icon);
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsWidgets);
    expect(find.byType(Profile), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-GCash')), findsOneWidget);
  });

  testWidgets('wallet chips use the GCash and Maya logos', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(children: [WalletLogo('GCash'), WalletLogo('Maya')]),
        ),
      ),
    );
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    final names = [for (final i in images) (i.image as AssetImage).assetName];
    expect(names, ['assets/logos/gcash_mark.png', 'assets/logos/maya.png']);
  });
}
