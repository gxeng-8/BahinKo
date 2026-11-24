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

  /// Erases every saved setting (Privacy → Delete my data).
  Future<void> clear() async {
    await load();
    await _prefs!.clear();
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

  /// Reminder tone (Profile → Reminder settings): 'Polite', 'Friendly'
  /// or 'Direct'. Default: Polite (BahinKo never shames anyone).
  String get reminderTone => _prefs?.getString('reminder_tone') ?? 'Polite';
  Future<void> setReminderTone(String v) async {
    await load();
    await _prefs!.setString('reminder_tone', v);
  }

  /// Remind this many days before a recurring bill is due. Default: 3.
  int get reminderDaysBefore => _prefs?.getInt('reminder_days') ?? 3;
  Future<void> setReminderDaysBefore(int v) async {
    await load();
    await _prefs!.setInt('reminder_days', v);
  }

  /// Offline mode toggle (Profile, Frame 24). Default: off.
  bool get offlineMode => _get('offline_mode', false);
  Future<void> setOfflineMode(bool v) async {
    await _set('offline_mode', v);
    // Remember when we stopped syncing ("Last synced 2 min ago").
    if (v) {
      await _prefs!.setInt(
        'offline_since',
        DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      await _prefs!.remove('offline_since');
    }
  }

  /// When offline mode was turned on (= the last sync), or null.
  DateTime? get offlineSince {
    final ms = _prefs?.getInt('offline_since');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
