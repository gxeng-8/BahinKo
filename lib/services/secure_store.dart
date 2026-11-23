/// Small key–value storage used for secrets (the PIN hash).
///
/// * [SecureStore]: the real app. Uses flutter_secure_storage, which keeps
///   values encrypted in the Android Keystore / iOS Keychain (on web it
///   encrypts them before saving in the browser).
/// * [MemoryStore]: tests. Keeps values in a Map, forgotten on restart.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureStore implements KeyValueStore {
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemoryStore implements KeyValueStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
