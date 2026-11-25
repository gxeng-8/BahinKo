/// Figma Frame 2 "App Lock": a 4-digit PIN keypad that protects balances.
///
/// The same screen handles three modes:
/// * create  – first time: "Create a PIN"
/// * confirm – type it again to make sure it matches
/// * unlock  – returning user: "Welcome back"
///
/// Validation feedback: mismatched PINs, wrong PIN with tries left, and a
/// 30-second pause after too many wrong tries.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:bahinko/screens/shell.dart';
import 'package:bahinko/services/app_lock_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/widgets/app_toast.dart';

enum _LockMode { create, confirm, unlock }

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  static const _pinLength = 4;
  final _lock = AppLockService.instance;

  /// null while we ask the service whether a PIN exists (loading state).
  _LockMode? _mode;
  String _entered = '';
  String _firstPin = ''; // remembered between "create" and "confirm"
  String? _error;
  bool _lockedOut = false;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel(); // stop the timer if the screen closes
    super.dispose();
  }

  /// Async: checks storage for a saved PIN, then picks the mode.
  Future<void> _loadMode() async {
    final hasPin = await _lock.hasPin();
    if (!mounted) return;
    setState(() => _mode = hasPin ? _LockMode.unlock : _LockMode.create);
  }

  // ---------- Keypad input ----------

  void _onDigit(String digit) {
    if (_lockedOut || _entered.length == _pinLength) return;
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

  /// Runs when 4 digits are entered; what happens depends on the mode.
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
        await _lock.setPin(_entered);
        _openApp('PIN set. Your balances are protected.');
      case _LockMode.unlock:
        if (await _lock.verify(_entered)) {
          _openApp(null);
        } else {
          _wrongPin();
        }
    }
  }

  void _wrongPin() {
    final left = _lock.attemptsLeft;
    setState(() {
      _entered = '';
      _error = left > 0
          ? 'Incorrect PIN. $left ${left == 1 ? 'try' : 'tries'} left.'
          : 'Too many tries. Wait 30 seconds.';
    });
    if (left <= 0) {
      setState(() => _lockedOut = true);
      _lockoutTimer = Timer(const Duration(seconds: 30), () {
        _lock.resetAttempts();
        if (mounted) {
          setState(() {
            _lockedOut = false;
            _error = null;
          });
        }
      });
    }
  }

  /// Goes to the main app. pushReplacement so Back doesn't return here.
  void _openApp(String? message) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const Shell()),
    );
    if (message != null) showAppToast(context, message);
  }

  // BACKEND STEP: replace with local_auth fingerprint check.
  void _onFingerprint() =>
      showAppToast(context, 'Fingerprint unlock is coming soon. Use your PIN.');

  // ---------- UI ----------

  (String, String) get _texts => switch (_mode) {
    _LockMode.create => (
      'Create a PIN',
      'Choose a 4-digit PIN to keep your balances private',
    ),
    _LockMode.confirm => ('Confirm your PIN', 'Enter the same 4 digits again'),
    _ => ('Welcome back', 'Enter your 4-digit PIN to open BahinKo'),
  };

  @override
  Widget build(BuildContext context) {
    // Loading state while the saved PIN is checked.
    if (_mode == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: green)),
      );
    }
    final (title, subtitle) = _texts;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: mint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.receipt_long, color: green, size: 28),
              ),
              const SizedBox(height: 16),
              Text(title, style: AppText.display(26, color: ink)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppText.caption,
              ),
              const SizedBox(height: 20),
              _PinDots(filled: _entered.length, hasError: _error != null),
              SizedBox(
                height: 32,
                child: _error == null
                    ? null
                    : Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: errorFg, fontSize: 12),
                        ),
                      ),
              ),
              const Spacer(),
              _Keypad(
                enabled: !_lockedOut,
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                onFingerprint: _mode == _LockMode.unlock
                    ? _onFingerprint
                    : null,
              ),
              const SizedBox(height: 16),
              if (_mode == _LockMode.unlock)
                TextButton(
                  onPressed: _onFingerprint,
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
        ),
      ),
    );
  }
}

/// Four dots: filled green for each digit typed; red when there's an error.
class _PinDots extends StatelessWidget {
  const _PinDots({required this.filled, required this.hasError});

  final int filled;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final color = hasError ? errorFg : green;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++)
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
