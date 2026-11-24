/// Stores and checks the 4-digit app-lock PIN.
///
/// Security:
/// * The PIN itself is NEVER saved. We save a random "salt" and the
///   SHA-256 hash of salt + PIN. To check a PIN we hash it again and
///   compare. Someone who reads the storage can't get the PIN back, and
///   the salt stops pre-computed hash tables from cracking it.
/// * Wrong attempts and the 30-second lockout are saved too, so closing
///   and reopening the app doesn't reset the lockout.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'package:bahinko/services/secure_store.dart';

/// Result of checking a PIN.
sealed class PinResult {
  const PinResult();
}

class PinCorrect extends PinResult {
  const PinCorrect();
}

class PinWrong extends PinResult {
  const PinWrong(this.attemptsLeft);
  final int attemptsLeft;
}

class PinLockedOut extends PinResult {
  const PinLockedOut(this.remaining);
  final Duration remaining;
}

class AppLockService {
  AppLockService({KeyValueStore? store}) : _store = store ?? MemoryStore();

  /// The service the whole app uses. main() gives it real secure storage;
  /// tests keep the in-memory default.
  static AppLockService instance = AppLockService();

  /// Wrong attempts allowed before the keypad is paused.
  static const maxAttempts = 5;
  static const lockoutDuration = Duration(seconds: 30);

  // Storage keys.
  static const _hashKey = 'pin_hash';
  static const _saltKey = 'pin_salt';
  static const _lengthKey = 'pin_length';
  static const _failsKey = 'pin_failed_attempts';
  static const _lockedUntilKey = 'pin_locked_until';

  final KeyValueStore _store;

  /// True once the user has created a PIN on this device.
  Future<bool> hasPin() async => await _store.read(_hashKey) != null;

  /// Saves a new PIN (as salt + hash) and clears any lockout.
  Future<void> setPin(String pin) async {
    final salt = _randomSalt();
    await _store.write(_saltKey, salt);
    await _store.write(_hashKey, _hash(salt, pin));
    await _store.write(_lengthKey, '${pin.length}');
    await _resetAttempts();
  }

  /// New PINs are 6 digits (they double as the account's sign-in PIN).
  static const newPinLength = 6;

  /// Digits in the saved PIN: 6, or 4 for PINs made before accounts.
  Future<int> pinLength() async =>
      int.tryParse(await _store.read(_lengthKey) ?? '') ??
      (await hasPin() ? 4 : newPinLength);

  /// Checks [pin]. Counts wrong attempts and starts a lockout after
  /// [maxAttempts] wrong tries.
  Future<PinResult> verify(String pin) async {
    final remaining = await lockoutRemaining();
    if (remaining != null) return PinLockedOut(remaining);

    final salt = await _store.read(_saltKey) ?? '';
    final saved = await _store.read(_hashKey);
    if (saved != null && _hash(salt, pin) == saved) {
      await _resetAttempts();
      return const PinCorrect();
    }

    final fails = int.parse(await _store.read(_failsKey) ?? '0') + 1;
    if (fails >= maxAttempts) {
      final until = DateTime.now().add(lockoutDuration);
      await _store.write(_lockedUntilKey, until.toIso8601String());
      await _store.write(_failsKey, '0'); // fresh tries after the wait
      return const PinLockedOut(lockoutDuration);
    }
    await _store.write(_failsKey, '$fails');
    return PinWrong(maxAttempts - fails);
  }

  /// Time left in the current lockout, or null if not locked out.
  Future<Duration?> lockoutRemaining() async {
    final raw = await _store.read(_lockedUntilKey);
    if (raw == null) return null;
    final left = DateTime.parse(raw).difference(DateTime.now());
    if (left <= Duration.zero) {
      await _store.delete(_lockedUntilKey);
      return null;
    }
    return left;
  }

  /// Removes the PIN (e.g. when the user turns app lock off).
  Future<void> clearPin() async {
    await _store.delete(_hashKey);
    await _store.delete(_saltKey);
    await _store.delete(_lengthKey);
    await _resetAttempts();
  }

  Future<void> _resetAttempts() async {
    await _store.delete(_failsKey);
    await _store.delete(_lockedUntilKey);
  }

  /// SHA-256 of salt + PIN, as a hex string.
  String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  /// 16 random bytes from a cryptographically secure generator.
  String _randomSalt() {
    final rng = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => rng.nextInt(256)));
  }
}
