// Tests the Get Started sign-in flow with a fake sign-in function,
// so no real Firebase connection is needed.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bahinko/screens/auth/app_lock_screen.dart';
import 'package:bahinko/screens/onboarding/onboarding_screen.dart';
import 'package:bahinko/services/auth_service.dart';

void main() {
  testWidgets('shows loading, then opens the PIN screen on success', (
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
    expect(find.byType(AppLockScreen), findsOneWidget);
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
}
