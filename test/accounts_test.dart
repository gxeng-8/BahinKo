import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bahinko/data/in_memory_group_service.dart';
import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/screens/auth/account_screens.dart';
import 'package:bahinko/screens/auth/app_lock_screen.dart';
import 'package:bahinko/screens/profile/profile_screen.dart';
import 'package:bahinko/screens/shell.dart';
import 'package:bahinko/services/app_lock_service.dart';
import 'package:bahinko/services/auth_service.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/services/settings_service.dart';
import 'package:bahinko/utils/validators.dart';

import 'fakes.dart';

late FakeAuthService auth;

Future<void> show(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String key, String text) =>
    tester.enterText(find.byKey(ValueKey(key)), text);

void main() {
  setUp(() {
    groupMembers.value = people;
    GroupService.instance = InMemoryGroupService();
    AuthService.instance = auth = FakeAuthService(signedIn: false);
    AppLockService.instance = AppLockService();
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance = SettingsService();
  });

  group('rules', () {
    test('usernames', () {
      expect(validateUsername('yumi'), isNull);
      expect(validateUsername('@Renz.D'), isNull); // @ and caps are fine
      expect(validateUsername('yu'), 'At least 3 characters');
      expect(validateUsername('1abc'), contains('start with a letter'));
      expect(validateUsername('ana cruz'), isNotNull);
      expect(normalizeUsername(' @Yumi '), 'yumi');
    });

    test('PINs: 6 digits, not easy to guess', () {
      expect(validateNewPin('482915'), isNull);
      expect(validateNewPin('1234'), 'Enter 6 digits');
      expect(validateNewPin('111111'), contains('easy'));
      expect(validateNewPin('123456'), contains('easy'));
      expect(validateNewPin('654321'), contains('easy'));
    });
  });

  testWidgets('create account: validates, then opens the app with the PIN '
      'as the app lock', (tester) async {
    await show(tester, const CreateAccountScreen());
    await tester.tap(find.byKey(const ValueKey('account-create')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a username'), findsOneWidget);
    expect(find.text('Enter 6 digits'), findsOneWidget);

    await type(tester, 'account-name', 'Yumi');
    await type(tester, 'account-username', 'yumi');
    await type(tester, 'account-pin', '482915');
    await type(tester, 'account-pin2', '482916');
    await tester.tap(find.byKey(const ValueKey('account-create')));
    await tester.pumpAndSettle();
    expect(find.text("PINs don't match"), findsOneWidget);

    await type(tester, 'account-pin2', '482915');
    await tester.tap(find.byKey(const ValueKey('account-create')));
    await tester.pumpAndSettle();
    expect(auth.accounts, {'yumi': '482915'});
    expect(auth.name, 'Yumi');
    expect(find.byType(Shell), findsOneWidget);
    expect(await AppLockService.instance.pinLength(), 6);
    expect(await AppLockService.instance.verify('482915'), isA<PinCorrect>());
  });

  testWidgets('taken username shows an error and keeps the form', (
    tester,
  ) async {
    auth.accounts['yumi'] = '999111';
    await show(tester, const CreateAccountScreen());
    await type(tester, 'account-name', 'Yumi');
    await type(tester, 'account-username', 'yumi');
    await type(tester, 'account-pin', '482915');
    await type(tester, 'account-pin2', '482915');
    await tester.tap(find.byKey(const ValueKey('account-create')));
    await tester.pumpAndSettle();
    expect(find.text('That username is taken. Try another.'), findsOneWidget);
    expect(find.byType(CreateAccountScreen), findsOneWidget);
  });

  testWidgets('sign back in after logging out: same account', (tester) async {
    auth.accounts['yumi'] = '482915';
    await show(tester, const SignInScreen());

    await type(tester, 'signin-username', 'yumi');
    await type(tester, 'signin-pin', '000999');
    await tester.tap(find.byKey(const ValueKey('signin-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Wrong username or PIN.'), findsOneWidget);

    await type(tester, 'signin-pin', '482915');
    await tester.tap(find.byKey(const ValueKey('signin-submit')));
    await tester.pumpAndSettle();
    expect(auth.user, 'yumi');
    expect(find.byType(Shell), findsOneWidget);
  });

  testWidgets('old 4-digit PINs still unlock; new ones are 6', (tester) async {
    await AppLockService.instance.setPin('2580');
    expect(await AppLockService.instance.pinLength(), 4);
    await show(tester, const AppLockScreen(popOnUnlock: true));
    expect(find.text('Enter your 4-digit PIN to open BahinKo'), findsOneWidget);
  });

  testWidgets('phone-only account can be saved from Profile', (tester) async {
    auth
      ..signedIn = true
      ..name = 'Yumi';
    await show(tester, const Profile());
    await tester.tap(find.byKey(const ValueKey('save-account')));
    await tester.pumpAndSettle();
    await type(tester, 'save-username', 'yumi');
    await type(tester, 'save-pin', '482915');
    await type(tester, 'save-pin2', '482915');
    await tester.tap(find.byKey(const ValueKey('save-account-submit')));
    await tester.pumpAndSettle();
    expect(auth.accounts, {'yumi': '482915'});
    expect(find.byKey(const ValueKey('save-account')), findsNothing);
    expect(find.textContaining('@yumi'), findsWidgets);
  });
}
