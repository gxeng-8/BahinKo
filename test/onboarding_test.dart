// Tests the Get Started sign-in flow with a fake sign-in function,
// so no real Firebase connection is needed.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('shows loading, then asks for your name on success', (
    tester,
  ) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(home: Onboarding(signIn: () => pending.future)),
    );

    await tester.tap(find.text('Get Started'));
    await tester.pump();
    expect(find.text('Getting ready…'), findsOneWidget); // loading state

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(YourNameScreen), findsOneWidget);
  });

  testWidgets('shows the error and lets the user retry on failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Onboarding(
          signIn: () async =>
              throw const AuthFailure('No internet connection.'),
        ),
      ),
    );

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('No internet connection.'), findsOneWidget); // error
    expect(find.text('Get Started'), findsOneWidget); // button is back
    expect(find.byType(AppLockScreen), findsNothing);
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
