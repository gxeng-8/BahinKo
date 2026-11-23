/// Stores and checks the 4-digit app-lock PIN.
///
/// BACKEND STEP: right now the PIN only lives in memory, so it is forgotten
/// when the app closes. Later we will:
///   1. save a SHA-256 *hash* of the PIN (never the PIN itself) with
///      `flutter_secure_storage`, and
///   2. add fingerprint unlock with `local_auth`.
/// The methods are already `async`, so screens won't need to change.
library;

class AppLockService {
  AppLockService._();

  /// One shared instance for the whole app (singleton).
  static final instance = AppLockService._();

  /// Wrong attempts allowed before the keypad is paused.
  static const maxAttempts = 5;

  String? _pin;
  int _failedAttempts = 0;

  /// True once the user has created a PIN.
  Future<bool> hasPin() async => _pin != null;

  /// Saves a new PIN and resets the failed-attempt counter.
  Future<void> setPin(String pin) async {
    _pin = pin;
    _failedAttempts = 0;
  }

  /// Returns true if [pin] matches. Counts wrong attempts.
  Future<bool> verify(String pin) async {
    final ok = pin == _pin;
    _failedAttempts = ok ? 0 : _failedAttempts + 1;
    return ok;
  }

  int get attemptsLeft => maxAttempts - _failedAttempts;

  /// Clears the lockout after the wait time is over.
  void resetAttempts() => _failedAttempts = 0;
}
