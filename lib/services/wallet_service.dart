/// Your GCash / Maya numbers (Profile, Frame 24).
///
/// Phone numbers are personal data, so they are kept ONLY on this phone,
/// encrypted (SecureStore), never uploaded. Profile shows them masked:
/// "0917 ••• 4821".
library;

import 'package:bahinko/services/secure_store.dart';

class WalletService {
  WalletService({KeyValueStore? store}) : _store = store ?? MemoryStore();

  /// main() swaps in encrypted storage; tests keep memory.
  static WalletService instance = WalletService();

  final KeyValueStore _store;

  static const providers = ['GCash', 'Maya'];

  String _key(String provider) => 'wallet_${provider.toLowerCase()}';

  /// The saved number ("09171234821"), or null.
  Future<String?> number(String provider) => _store.read(_key(provider));

  /// Saves (or with null/empty, removes) the number for [provider].
  Future<void> setNumber(String provider, String? number) =>
      number == null || number.isEmpty
      ? _store.delete(_key(provider))
      : _store.write(_key(provider), normalizePhone(number)!);

  /// Removes everything (on log out).
  Future<void> clear() async {
    for (final p in providers) {
      await _store.delete(_key(p));
    }
  }
}

/// "0917 123 4821" / "+63 917-123-4821" → "09171234821".
/// Null if it isn't a Philippine mobile number.
String? normalizePhone(String input) {
  final digits = input.replaceAll(RegExp(r'[\s\-()]'), '');
  final m = RegExp(r'^(?:\+?63|0)(9\d{9})$').firstMatch(digits);
  return m == null ? null : '0${m.group(1)}';
}

/// "09171234821" → "0917 ••• 4821" (enough to recognise, not to copy).
String maskPhone(String number) => number.length < 8
    ? number
    : '${number.substring(0, 4)} ••• ${number.substring(number.length - 4)}';
