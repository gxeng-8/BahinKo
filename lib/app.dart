/// Root MaterialApp: theme, phone-width frame, start screen, and re-lock.
///
/// First screen:
/// * not signed in            → Onboarding
/// * signed in, no name yet   → "What should friends call you?"
/// * app lock on              → PIN screen
/// * app lock off             → the app (Shell)
///
/// Re-lock: if the app sat in the background for [relockAfter] or longer,
/// the PIN screen is shown again on top when it comes back, so someone
/// who picks up an unlocked phone can't see your balances.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/screens/auth/app_lock_screen.dart';
import 'package:bahinko/screens/auth/your_name_screen.dart';
import 'package:bahinko/screens/onboarding/onboarding_screen.dart';
import 'package:bahinko/screens/shell.dart';
import 'package:bahinko/services/app_lock_service.dart';
import 'package:bahinko/services/settings_service.dart';
import 'package:bahinko/theme/app_theme.dart';

class BahinKoApp extends StatefulWidget {
  const BahinKoApp({
    super.key,
    this.signedIn = false,
    this.needsName = false,
    this.lockOnStart = true,
  });

  /// These are passed in from main() instead of asking Firebase/storage
  /// here, so widget tests (which don't start Firebase) can build the app.
  final bool signedIn;
  final bool needsName;
  final bool lockOnStart;

  @override
  State<BahinKoApp> createState() => _BahinKoAppState();
}

class _BahinKoAppState extends State<BahinKoApp> with WidgetsBindingObserver {
  static const relockAfter = Duration(minutes: 1);

  /// Lets us push the lock screen from outside any screen's context.
  final _navigatorKey = GlobalKey<NavigatorState>();
  DateTime? _backgroundedAt;
  bool _relockShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // listen to app lifecycle
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called by Flutter when the app goes to the background or comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since != null && DateTime.now().difference(since) >= relockAfter) {
        _relock();
      }
    }
  }

  Future<void> _relock() async {
    // Only if lock is on, a PIN exists (i.e. setup is finished), and no
    // lock screen is already showing.
    if (_relockShowing ||
        AppLockScreen.isShowing ||
        !SettingsService.instance.appLockEnabled ||
        !await AppLockService.instance.hasPin()) {
      return;
    }
    _relockShowing = true;
    await _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const AppLockScreen(popOnUnlock: true)),
    );
    _relockShowing = false;
  }

  Widget get _firstScreen {
    if (!widget.signedIn) return const Onboarding();
    if (widget.needsName) return const YourNameScreen();
    return widget.lockOnStart ? const AppLockScreen() : const Shell();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
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
    home: _firstScreen,
  );
}
