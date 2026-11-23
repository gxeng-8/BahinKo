// Test doubles shared by widget tests (tests can't use real Firebase).
import 'package:bahinko/services/auth_service.dart';

/// Pretends to be signed in as "me". Remembers the name it's given.
class FakeAuthService extends AuthService {
  FakeAuthService({this.name});

  String? name;

  /// Set to make setDisplayName fail (to test error states).
  AuthFailure? failWith;

  @override
  String? get uid => 'me';

  @override
  String? get displayName => name;

  @override
  Future<void> signIn() async {}

  @override
  Future<void> setDisplayName(String newName) async {
    if (failWith != null) throw failWith!;
    name = newName.trim();
  }
}
