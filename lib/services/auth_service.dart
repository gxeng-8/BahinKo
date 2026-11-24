/// Signs the user in with Firebase Authentication (anonymous for now) and
/// stores the name friends see in groups.
///
/// Screens call this service instead of FirebaseAuth directly, so the
/// sign-in method can change later (e.g. email) without touching any screen.
///
/// Why anonymous? No email or password is collected: only a first name,
/// the minimum personal data needed, in line with the Data Privacy Act
/// (RA 10173). Firebase keeps the session on the device, so returning
/// users stay signed in.
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService();

  /// The service the whole app uses. Tests replace it with a fake
  /// (see test/onboarding_test.dart), because they can't use Firebase.
  static AuthService instance = AuthService();

  /// How long to wait for Firebase before giving up.
  static const timeout = Duration(seconds: 15);

  /// A getter (not a field) so creating an AuthService doesn't touch
  /// Firebase until it's actually used.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// The signed-in user's ID, or null if nobody is signed in.
  /// Firestore uses this to know whose groups are whose.
  String? get uid => _auth.currentUser?.uid;

  bool get isSignedIn => uid != null;

  /// The name friends see in groups ("Renz"), or null if not set yet.
  String? get displayName {
    final name = _auth.currentUser?.displayName?.trim();
    return (name == null || name.isEmpty) ? null : name;
  }

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
      throw _toFailure(e);
    }
  }

  /// Saves the user's name on their Firebase account.
  Future<void> setDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('Please sign in first.');
    try {
      await user.updateDisplayName(name.trim()).timeout(timeout);
      await user.reload(); // refresh currentUser so displayName is updated
    } on TimeoutException {
      throw const AuthFailure(
        'Taking too long. Check your internet and try again.',
      );
    } on FirebaseAuthException catch (e) {
      throw _toFailure(e);
    }
  }

  /// Signs out. With anonymous accounts this loses the user's data link,
  /// so the Profile screen should warn before calling it.
  Future<void> signOut() => _auth.signOut();

  /// Deletes the account itself (Privacy → Delete my data). Falls back to
  /// signing out if Firebase refuses (e.g. it wants a recent sign-in).
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete().timeout(timeout);
    } catch (_) {
      // The groups are already left; at least end the session.
    }
    await _auth.signOut();
  }

  AuthFailure _toFailure(FirebaseAuthException e) => AuthFailure(
    e.code == 'network-request-failed'
        ? 'No internet connection. Connect and try again.'
        : 'Something went wrong. Please try again.',
  );
}

/// Error with a message that's safe to show to the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
