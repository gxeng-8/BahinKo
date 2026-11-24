/// Figma Frame 2 "App Lock": a 4-digit PIN keypad that protects balances.
///
/// The same screen handles three modes:
/// * create  – first time: "Create a PIN"
/// * confirm – type it again to make sure it matches
/// * unlock  – returning user: "Welcome back" (+ fingerprint if available)
///
/// Validation feedback: mismatched PINs, wrong PIN with tries left, and a
/// 30-second pause after too many wrong tries (saved, so restarting the app
/// doesn't skip it). The PIN is stored only as a salted hash: see
/// AppLockService.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:bahinko/screens/shell.dart';
import 'package:bahinko/services/app_lock_service.dart';
import 'package:bahinko/services/biometric_service.dart';
import 'package:bahinko/services/settings_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/widgets/app_toast.dart';
import 'package:bahinko/widgets/app_logo.dart';

enum _LockMode { create, confirm, unlock }

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, this.popOnUnlock = false});

  /// True when shown on top of the app after it was in the background:
  /// unlocking just closes this screen, and Back can't skip it.
  final bool popOnUnlock;

  /// True while any lock screen is open (so the app never stacks two).
  static bool get isShowing => _openCount > 0;
  static int _openCount = 0;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  /// 6 for new PINs; older 4-digit PINs still unlock.
  int _pinLength = AppLockService.newPinLength;
  final _lock = AppLockService.instance;

  /// null while we check storage for a saved PIN (loading state).
  _LockMode? _mode;
  String _entered = '';
  String _firstPin = ''; // remembered between "create" and "confirm"
  String? _error;

  /// Seconds left in a lockout (null = not locked out).
  int? _lockSeconds;
  Timer? _countdown;

  /// Whether to offer fingerprint unlock on this device.
  bool _canUseFingerprint = false;

  @override
  void initState() {
    super.initState();
    AppLockScreen._openCount++;
    _load();
  }

  @override
  void dispose() {
    AppLockScreen._openCount--;
    _countdown?.cancel(); // stop the timer if the screen closes
    super.dispose();
  }

  /// Async start-up: is there a saved PIN? a running lockout? fingerprint?
  Future<void> _load() async {
    final hasPin = await _lock.hasPin();
    final length = hasPin
        ? await _lock.pinLength()
        : AppLockService.newPinLength;
    final remaining = await _lock.lockoutRemaining();
    final fingerprint =
        hasPin &&
        SettingsService.instance.useFingerprint &&
        await BiometricService.instance.isAvailable();
    if (!mounted) return;
    setState(() {
      _mode = hasPin ? _LockMode.unlock : _LockMode.create;
      _pinLength = length;
      _canUseFingerprint = fingerprint;
    });
    if (remaining != null) {
      _startLockout(remaining);
    } else if (fingerprint) {
      _onFingerprint(); // offer fingerprint right away, like banking apps
    }
  }

  // ---------- Keypad input ----------

  void _onDigit(String digit) {
    if (_lockSeconds != null || _entered.length == _pinLength) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length == _pinLength) _onPinComplete();
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  /// Runs when all digits are entered; what happens depends on the mode.
  Future<void> _onPinComplete() async {
    switch (_mode!) {
      case _LockMode.create:
        setState(() {
          _firstPin = _entered;
          _entered = '';
          _mode = _LockMode.confirm;
        });
      case _LockMode.confirm:
        if (_entered != _firstPin) {
          // Validation error: start over.
          setState(() {
            _error = "PINs don't match. Try again.";
            _entered = '';
            _firstPin = '';
            _mode = _LockMode.create;
          });
          return;
        }
        await _lock.setPin(_entered); // saved as salt + hash
        _unlocked('PIN set. Your balances are protected.');
      case _LockMode.unlock:
        final result = await _lock.verify(_entered);
        if (!mounted) return;
        switch (result) {
          case PinCorrect():
            _unlocked(null);
          case PinWrong(:final attemptsLeft):
            setState(() {
              _entered = '';
              _error =
                  'Incorrect PIN. $attemptsLeft '
                  '${attemptsLeft == 1 ? 'try' : 'tries'} left.';
            });
          case PinLockedOut(:final remaining):
            setState(() => _entered = '');
            _startLockout(remaining);
        }
    }
  }

  /// Disables the keypad and counts down until the lockout ends.
  void _startLockout(Duration remaining) {
    _countdown?.cancel();
    setState(() => _lockSeconds = remaining.inSeconds.clamp(1, 999));
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      final left = _lockSeconds! - 1;
      setState(() {
        if (left <= 0) {
          timer.cancel();
          _lockSeconds = null;
          _error = null;
        } else {
          _lockSeconds = left;
        }
      });
    });
  }

  /// Fingerprint prompt (system dialog). Falls back to the PIN silently.
  Future<void> _onFingerprint() async {
    if (_lockSeconds != null) return;
    final ok = await BiometricService.instance.authenticate();
    if (ok && mounted) _unlocked(null);
  }

  /// Leaves the lock screen: closes it (re-lock mode) or opens the app.
  void _unlocked(String? message) {
    if (!mounted) return;
    if (widget.popOnUnlock) {
      Navigator.pop(context);
    } else {
      // pushReplacement so Back doesn't return to the lock screen.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Shell()),
      );
    }
    if (message != null) showAppToast(context, message);
  }

  // ---------- UI ----------

  (String, String) get _texts => switch (_mode) {
    _LockMode.create => (
      'Create a PIN',
      'Choose a $_pinLength-digit PIN to keep your balances private',
    ),
    _LockMode.confirm => (
      'Confirm your PIN',
      'Enter the same $_pinLength digits again',
    ),
    _ => ('Welcome back', 'Enter your $_pinLength-digit PIN to open BahinKo'),
  };

  @override
  Widget build(BuildContext context) {
    // Loading state while storage is checked.
    if (_mode == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: green)),
      );
    }
    final (title, subtitle) = _texts;
    final lockedOut = _lockSeconds != null;
    final message = lockedOut
        ? 'Too many tries. Try again in $_lockSeconds s.'
        : _error;
    return PopScope(
      // In re-lock mode, Back must not reveal the app underneath.
      canPop: !widget.popOnUnlock,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          // Scrolls only when the screen is too short (small phones,
          // landscape); otherwise the Spacers center everything as usual.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: _content(title, subtitle, message, lockedOut),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The lock screen's column: logo, title, dots, keypad.
  Widget _content(
    String title,
    String subtitle,
    String? message,
    bool lockedOut,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    child: Column(
      children: [
        const Spacer(),
        const AppLogo(size: 60),
        const SizedBox(height: 16),
        Text(title, style: AppText.display(26, color: ink)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: AppText.caption),
        const SizedBox(height: 20),
        _PinDots(
          filled: _entered.length,
          length: _pinLength,
          hasError: message != null,
        ),
        SizedBox(
          height: 32,
          child: message == null
              ? null
              : Center(
                  child: Text(
                    message,
                    style: const TextStyle(color: errorFg, fontSize: 12),
                  ),
                ),
        ),
        const Spacer(),
        _Keypad(
          enabled: !lockedOut,
          onDigit: _onDigit,
          onBackspace: _onBackspace,
          onFingerprint: _canUseFingerprint && _mode == _LockMode.unlock
              ? _onFingerprint
              : null,
        ),
        const SizedBox(height: 16),
        if (_canUseFingerprint && _mode == _LockMode.unlock)
          TextButton(
            onPressed: lockedOut ? null : _onFingerprint,
            child: const Text(
              'Use fingerprint instead',
              style: TextStyle(color: green, fontWeight: FontWeight.w700),
            ),
          ),
        const Text(
          'App lock keeps your balances private',
          style: AppText.caption,
        ),
      ],
    ),
  );
}

/// One dot per digit: filled green for each digit typed; red when there's an error.
class _PinDots extends StatelessWidget {
  const _PinDots({
    required this.filled,
    required this.length,
    required this.hasError,
  });

  final int filled;
  final int length;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final color = hasError ? errorFg : green;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? color : Colors.transparent,
              border: Border.all(color: color, width: 1.5),
            ),
          ),
      ],
    );
  }
}

/// 3×4 number pad: 1–9, then fingerprint · 0 · backspace.
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
    required this.onFingerprint,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onFingerprint;

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, VoidCallback? onTap, {String? label}) => Padding(
      padding: const EdgeInsets.all(8),
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: onTap == null ? Colors.transparent : background,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onTap : null,
            child: SizedBox(height: 56, child: Center(child: child)),
          ),
        ),
      ),
    );

    Widget digit(String d) => key(
      Text(
        d,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
      () => onDigit(d),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Column(
        children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(children: [for (final d in row) Expanded(child: digit(d))]),
          Row(
            children: [
              Expanded(
                child: onFingerprint == null
                    ? const SizedBox()
                    : key(
                        const Icon(Icons.fingerprint, color: green),
                        onFingerprint,
                        label: 'Fingerprint',
                      ),
              ),
              Expanded(child: digit('0')),
              Expanded(
                child: key(
                  const Icon(Icons.backspace_outlined, color: ink),
                  onBackspace,
                  label: 'Delete',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
