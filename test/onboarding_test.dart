// Tests the welcome screen and the name screen with a fake AuthService,
// so no real Firebase connection is needed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bahinko/screens/auth/account_screens.dart';
import 'package:bahinko/screens/auth/app_lock_screen.dart';
import 'package:bahinko/screens/auth/your_name_screen.dart';
import 'package:bahinko/screens/onboarding/onboarding_screen.dart';
import 'package:bahinko/services/app_lock_service.dart';
import 'package:bahinko/services/auth_service.dart';

import 'fakes.dart';

void main() {
  late FakeAuthService auth;
  setUp(() {
    AuthService.instance = auth = FakeAuthService();
    AppLockService.instance = AppLockService(); // fresh, no PIN yet
  });

  testWidgets('Get Started opens Create account', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Onboarding()));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateAccountScreen), findsOneWidget);
  });

  testWidgets('"I already have an account" opens Sign in', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Onboarding()));
    await tester.tap(find.byKey(const ValueKey('have-account')));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('your name: validates, saves, then opens the PIN screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: YourNameScreen()));

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('your-name')), 'R2D2');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Use letters only'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('your-name')), ' Renz ');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(auth.name, 'Renz');
    expect(find.byType(AppLockScreen), findsOneWidget);
  });

  testWidgets('your name: shows the error when saving fails', (tester) async {
    auth.failWith = const AuthFailure('No internet connection.');
    await tester.pumpWidget(const MaterialApp(home: YourNameScreen()));

    await tester.enterText(find.byKey(const ValueKey('your-name')), 'Renz');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('No internet connection.'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget); // button is back
  });
}
