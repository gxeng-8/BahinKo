/// Signs the user in with Firebase Authentication (anonymous for now).
///
/// Screens call this service instead of FirebaseAuth directly, so the
/// sign-in method can change later (e.g. email) without touching any screen.
///
/// Why anonymous? No email or password is collected: the minimum personal
/// data needed, in line with the Data Privacy Act (RA 10173). Firebase keeps
/// the session on the device, so returning users stay signed in.
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();

  /// One shared instance for the whole app (singleton).
  static final instance = AuthService._();

  /// How long to wait for Firebase before giving up.
  static const timeout = Duration(seconds: 15);

  final _auth = FirebaseAuth.instance;

  /// The signed-in user's ID, or null if nobody is signed in.
  /// Firestore uses this to know whose groups are whose.
  String? get uid => _auth.currentUser?.uid;

  bool get isSignedIn => uid != null;

  /// Waits until Firebase has restored a saved sign-in from the device.
  ///
  /// On web this happens a moment after startup, so checking [isSignedIn]
  /// too early would wrongly say "not signed in". `authStateChanges()`
  /// emits the restored user (or null) as its first event.
  Future<void> restoreSession() async {
    try {
      await _auth.authStateChanges().first.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      // Not fatal: the user just sees Onboarding and signs in again.
    }
  }

  /// Signs in anonymously if needed.
  ///
  /// Throws [AuthFailure] with a user-friendly message when it fails, so
  /// screens can show it directly without knowing Firebase error codes.
  Future<void> signIn() async {
    if (isSignedIn) return; // already signed in on this device
    try {
      await _auth.signInAnonymously().timeout(timeout);
    } on TimeoutException {
      throw const AuthFailure(
        'Taking too long. Check your internet and try again.',
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(
        e.code == 'network-request-failed'
            ? 'No internet connection. Connect and try again.'
            : "Couldn't sign in. Please try again.",
      );
    }
  }

  /// Signs out. With anonymous accounts this loses the user's data link,
  /// so the Profile screen should warn before calling it.
  Future<void> signOut() => _auth.signOut();
}

/// Error with a message that's safe to show to the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
