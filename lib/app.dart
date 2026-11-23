/// Root MaterialApp: theme, phone-width frame, and start screen.
///
/// The first screen depends on [BahinKoApp.signedIn]: new users see
/// Onboarding; returning users (already signed in) go straight to App Lock.
library;

import 'package:flutter/material.dart';
import 'package:bahinko/screens/auth/app_lock_screen.dart';
import 'package:bahinko/screens/onboarding/onboarding_screen.dart';
import 'package:bahinko/theme/app_theme.dart';

class BahinKoApp extends StatelessWidget {
  const BahinKoApp({super.key, this.signedIn = false});

  /// Passed in from main() instead of asking Firebase here, so widget tests
  /// (which don't start Firebase) can build the app too.
  final bool signedIn;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'BahinKo',
    theme: buildAppTheme(), // colors, fonts, inputs: see theme/app_theme.dart
    builder: (context, child) => LayoutBuilder(
      builder: (context, constraints) {
        final appWidth = constraints.maxWidth < 430
            ? constraints.maxWidth
            : 430.0;

        return ColoredBox(
          color: const Color(0xFFEFF3F1),
          child: Center(
            child: SizedBox(
              width: appWidth,
              height: constraints.maxHeight,
              child: child,
            ),
          ),
        );
      },
    ),
    home: signedIn ? const AppLockScreen() : const Onboarding(),
  );
}
