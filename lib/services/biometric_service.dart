/// Fingerprint / face unlock using the device's own biometrics (local_auth).
///
/// The fingerprint never leaves the phone: Android/iOS check it and only
/// tell the app "yes" or "no". Not available on web; on devices without
/// biometrics the app simply hides the fingerprint button.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  /// The service the whole app uses. Tests may replace it with a fake.
  static BiometricService instance = BiometricService();

  final _auth = LocalAuthentication();

  /// True if this device has biometrics set up and the app can use them.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false; // browsers don't support local_auth
    try {
      // Time limit: if the plugin never answers, act as if unavailable so
      // the PIN screen still loads.
      return await (_auth.isDeviceSupported().then(
        (supported) async => supported && await _auth.canCheckBiometrics,
      )).timeout(const Duration(seconds: 2), onTimeout: () => false);
    } catch (_) {
      return false; // e.g. plugin missing on this platform, or in tests
    }
  }

  /// Shows the system fingerprint prompt. True if the user was recognized.
  /// Any failure or cancel just returns false (the PIN still works).
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock BahinKo to see your balances',
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }
}
