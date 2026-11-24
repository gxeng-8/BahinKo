// Test doubles shared by widget tests (tests can't use real Firebase).
import 'package:bahinko/services/auth_service.dart';

/// Pretends to be signed in as "me". Remembers the name it's given, and
/// keeps a pretend list of username -> PIN accounts.
class FakeAuthService extends AuthService {
  FakeAuthService({this.name, this.user, this.signedIn = true});

  String? name;

  /// The saved account's username (null = phone-only / anonymous).
  String? user;
  bool signedIn;

  /// Pretend server: username -> PIN.
  final accounts = <String, String>{};

  /// Set to make the next call fail (to test error states).
  AuthFailure? failWith;

  void _maybeFail() {
    if (failWith != null) throw failWith!;
  }

  @override
  String? get uid => signedIn ? 'me' : null;

  @override
  String? get displayName => name;

  @override
  String? get username => signedIn ? user : null;

  @override
  Future<void> signIn() async {}

  @override
  Future<void> setDisplayName(String newName) async {
    _maybeFail();
    name = newName.trim();
  }

  @override
  Future<void> createAccount({
    required String name,
    required String username,
    required String pin,
  }) async {
    _maybeFail();
    if (accounts.containsKey(username)) {
      throw const AuthFailure('That username is taken. Try another.');
    }
    accounts[username] = pin;
    user = username;
    this.name = name;
    signedIn = true;
  }

  @override
  Future<void> saveAccount({
    required String username,
    required String pin,
  }) async {
    _maybeFail();
    if (accounts.containsKey(username)) {
      throw const AuthFailure('That username is taken. Try another.');
    }
    accounts[username] = pin;
    user = username;
  }

  @override
  Future<void> signInWithPin({
    required String username,
    required String pin,
  }) async {
    _maybeFail();
    if (accounts[username] != pin) {
      throw const AuthFailure('Wrong username or PIN.');
    }
    user = username;
    signedIn = true;
  }

  @override
  Future<void> confirmPin(String pin) async {
    if (user != null && accounts[user] != pin) {
      throw const AuthFailure('Wrong username or PIN.');
    }
  }

  @override
  Future<void> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    await confirmPin(oldPin);
    accounts[user!] = newPin;
  }

  @override
  Future<void> signOut() async => signedIn = false;

  @override
  Future<void> deleteAccount() async {
    accounts.remove(user);
    user = null;
    signedIn = false;
  }
}
