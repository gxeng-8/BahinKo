/// Signs the user in with Firebase Authentication and stores the name
/// friends see in groups.
///
/// ACCOUNTS: a username + 6-digit PIN, so people get the SAME account back
/// after logging out, reinstalling or switching phones. Under the hood the
/// username becomes a made-up address (`yumi@users.bahinko-303f2...`) for
/// Firebase's Email/Password sign-in: no real email is collected or ever
/// used, and Firebase stores the PIN only as a secure hash. Firebase also
/// blocks rapid guessing ("too many attempts").
///
/// Older installs used anonymous accounts (tied to one phone); those can
/// be saved with [saveAccount], which keeps the same user ID and groups.
///
/// Screens call this service instead of FirebaseAuth directly, so the
/// sign-in method can change without touching any screen.
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

  /// The made-up address domain for usernames (never receives mail).
  static const usernameDomain = 'users.bahinko-303f2.firebaseapp.com';

  static String emailFor(String username) =>
      '${username.trim().toLowerCase()}@$usernameDomain';

  /// "yumi" for a saved account, or null (anonymous / signed out).
  String? get username {
    final email = _auth.currentUser?.email;
    if (email == null || !email.endsWith('@$usernameDomain')) return null;
    return email.split('@').first;
  }

  /// True when the account can be signed back into (username + PIN).
  bool get hasSavedAccount => username != null;

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

  /// New account: name, username and 6-digit PIN. If this phone already
  /// has an anonymous account (older installs), it is upgraded instead, so
  /// its groups are kept.
  Future<void> createAccount({
    required String name,
    required String username,
    required String pin,
  }) async {
    await _run(() async {
      final current = _auth.currentUser;
      final credential = EmailAuthProvider.credential(
        email: emailFor(username),
        password: pin,
      );
      if (current != null && current.isAnonymous) {
        await current.linkWithCredential(credential);
      } else {
        if (current != null) await _auth.signOut();
        await _auth.createUserWithEmailAndPassword(
          email: emailFor(username),
          password: pin,
        );
      }
    });
    await setDisplayName(name);
  }

  /// Older anonymous account -> saved account (same ID, same groups).
  Future<void> saveAccount({required String username, required String pin}) =>
      _run(() async {
        final user = _auth.currentUser;
        if (user == null) throw const AuthFailure('Please sign in first.');
        await user.linkWithCredential(
          EmailAuthProvider.credential(
            email: emailFor(username),
            password: pin,
          ),
        );
        await user.reload();
      });

  /// Sign back in with username + PIN (after log out or reinstall).
  Future<void> signInWithPin({required String username, required String pin}) =>
      _run(() async {
        if (_auth.currentUser != null) await _auth.signOut();
        await _auth.signInWithEmailAndPassword(
          email: emailFor(username),
          password: pin,
        );
      });

  /// Checks the PIN with Firebase (needed before changing the PIN or
  /// deleting the account). Throws [AuthFailure] if it's wrong.
  Future<void> confirmPin(String pin) => _run(() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) return; // anonymous: nothing to check
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: pin),
    );
  });

  /// Changes the sign-in PIN (checks the old one first).
  Future<void> changePin({required String oldPin, required String newPin}) =>
      _run(() async {
        await confirmPin(oldPin);
        await _auth.currentUser!.updatePassword(newPin);
      });

  /// Runs a Firebase call with a time limit and friendly errors.
  Future<void> _run(Future<void> Function() call) async {
    try {
      await call().timeout(timeout);
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

  /// Signs out. A saved account can sign back in with username + PIN; an
  /// anonymous one is lost, so Profile warns before calling it.
  Future<void> signOut() => _auth.signOut();

  /// Deletes the account itself (Privacy > Delete my data; call
  /// [confirmPin] first so Firebase allows it). Falls back to signing out
  /// if Firebase still refuses.
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete().timeout(timeout);
    } catch (_) {
      // The groups are already left; at least end the session.
    }
    await _auth.signOut();
  }

  AuthFailure _toFailure(FirebaseAuthException e) =>
      AuthFailure(switch (e.code) {
        'network-request-failed' =>
          'No internet connection. Connect and try again.',
        'email-already-in-use' ||
        'credential-already-in-use' => 'That username is taken. Try another.',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'invalid-email' => 'Wrong username or PIN.',
        'too-many-requests' =>
          'Too many tries. Wait a few minutes and try again.',
        'weak-password' => 'Use a 6-digit PIN.',
        'requires-recent-login' => 'Please enter your PIN again.',
        'operation-not-allowed' =>
          'Username sign-in is turned off. Turn on Email/Password in the '
              'Firebase console (Authentication > Sign-in method).',
        _ => 'Something went wrong. Please try again.',
      });
}

/// Error with a message that's safe to show to the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
