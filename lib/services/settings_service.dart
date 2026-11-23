/// App settings saved on the device with shared_preferences (survive
/// restarts). Not secret: secrets go in SecureStore instead.
///
/// main() calls [load] once at startup; after that the getters are
/// instant. Until load() runs (e.g. in widget tests) they return defaults.
///
/// For M3's Profile screen (Frame 24): bind the switches to these, e.g.
///   SwitchListTile(
///     value: SettingsService.instance.autoDeleteReceipts,
///     onChanged: (v) async {
///       await SettingsService.instance.setAutoDeleteReceipts(v);
///       setState(() {});
///     },
///   )
library;

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static SettingsService instance = SettingsService();

  SharedPreferences? _prefs;

  /// Loads saved settings from the device. Safe to call more than once.
  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  bool _get(String key, bool fallback) => _prefs?.getBool(key) ?? fallback;

  Future<void> _set(String key, bool value) async {
    await load();
    await _prefs!.setBool(key, value);
  }

  /// Ask for the PIN when the app opens / comes back. Default: on.
  bool get appLockEnabled => _get('app_lock_enabled', true);
  Future<void> setAppLockEnabled(bool v) => _set('app_lock_enabled', v);

  /// Offer fingerprint unlock (when the device supports it). Default: on.
  bool get useFingerprint => _get('use_fingerprint', true);
  Future<void> setUseFingerprint(bool v) => _set('use_fingerprint', v);

  /// Delete receipt photos after 30 days (Profile, Frame 24). Default: on.
  bool get autoDeleteReceipts => _get('auto_delete_receipts', true);
  Future<void> setAutoDeleteReceipts(bool v) => _set('auto_delete_receipts', v);

  /// Offline mode toggle (Profile, Frame 24). Default: off.
  bool get offlineMode => _get('offline_mode', false);
  Future<void> setOfflineMode(bool v) => _set('offline_mode', v);
}
