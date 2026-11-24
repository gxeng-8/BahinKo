/// Figma Frame 24 "Profile": your name, wallet numbers, and settings
/// (app lock, auto-delete receipts, reminders, offline mode, privacy),
/// plus Log out.
///
/// Every switch is real:
/// * App lock: on/off and Change PIN (asks for the current PIN first).
/// * Auto-delete receipt photos: SettingsService.
/// * Reminder settings: tone + days, used by the reminder sheet.
/// * Offline mode: stops Firestore syncing; changes wait on the phone.
/// Wallet numbers stay encrypted on this phone (WalletService).
library;

import 'package:flutter/material.dart';

import 'package:bahinko/models/group.dart';
import 'package:bahinko/screens/auth/app_lock_screen.dart';
import 'package:bahinko/screens/onboarding/onboarding_screen.dart';
import 'package:bahinko/screens/settings/privacy_screen.dart';
import 'package:bahinko/services/app_lock_service.dart';
import 'package:bahinko/services/auth_service.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/services/settings_service.dart';
import 'package:bahinko/services/wallet_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/widgets/app_toast.dart';
import 'package:bahinko/widgets/wallet_logo.dart';
import 'package:bahinko/screens/auth/account_screens.dart';
import 'package:bahinko/utils/validators.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final _settings = SettingsService.instance;
  late final Stream<List<Group>> _groups = GroupService.instance
      .watchMyGroups();

  /// Saved wallet numbers (provider → number), loaded in initState.
  final Map<String, String?> _wallets = {};

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    for (final p in WalletService.providers) {
      _wallets[p] = await WalletService.instance.number(p);
    }
    if (mounted) setState(() {});
  }

  /// Your name from your account. (Widget tests have no Firebase, so fall
  /// back to "You" there.)
  String get _name {
    try {
      return AuthService.instance.displayName ?? 'You';
    } catch (_) {
      return 'You';
    }
  }

  /// "@yumi" for a saved account; otherwise made from the name.
  String get _handle {
    final saved = _username;
    return saved != null
        ? '@$saved'
        : '@${_name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '')}';
  }

  /// The account's username, or null (not saved yet, or no Firebase).
  String? get _username {
    try {
      return AuthService.instance.username;
    } catch (_) {
      return null;
    }
  }

  /// Signed in at all? (false in widget tests without Firebase)
  bool get _hasFirebaseUser {
    try {
      return AuthService.instance.isSignedIn;
    } catch (_) {
      return false;
    }
  }

  /// True if this account can be signed back into with username + PIN.
  bool get _saved => _username != null;

  /// "Save your account" (older, phone-only accounts).
  Future<void> _saveAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _SaveAccountDialog(),
    );
    if (ok == true && mounted) {
      setState(() {});
      showAppToast(context, 'Account saved. Sign in with @$_username.');
    }
  }

  // ---------- Wallet numbers ----------

  Future<void> _editWallet(String provider) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _WalletDialog(provider: provider, initial: _wallets[provider]),
    );
    if (result == null) return; // cancelled
    await WalletService.instance.setNumber(provider, result);
    await _loadWallets();
  }

  // ---------- App lock ----------

  /// Asks for the current PIN (if there is one). True when it was entered.
  Future<bool> _verifyPin() async {
    if (!await AppLockService.instance.hasPin()) return true;
    if (!mounted) return false;
    // The lock screen only closes after the right PIN (Back is blocked).
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AppLockScreen(popOnUnlock: true)),
    );
    return mounted;
  }

  /// Opens the lock screen in "Create a PIN" mode.
  Future<void> _createPin() async {
    await AppLockService.instance.clearPin();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AppLockScreen(popOnUnlock: true)),
    );
  }

  Future<void> _setAppLock(bool on) async {
    if (on) {
      if (!await AppLockService.instance.hasPin()) await _createPin();
    } else if (!await _verifyPin()) {
      return; // turning the lock off needs the PIN
    }
    await _settings.setAppLockEnabled(on);
    if (mounted) setState(() {});
  }

  Future<void> _changePin() async {
    if (_saved) {
      // The PIN is also the sign-in PIN: change both together.
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => const _ChangePinDialog(),
      );
      if (ok == true && mounted) showAppToast(context, 'PIN changed');
      return;
    }
    if (!await _verifyPin()) return;
    await _createPin();
    if (mounted) showAppToast(context, 'PIN changed');
  }

  Future<void> _openAppLock() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('App lock', style: AppText.title),
            SwitchListTile(
              key: const ValueKey('lock-switch'),
              title: const Text('Ask for my PIN'),
              subtitle: const Text('When BahinKo opens or comes back'),
              value: _settings.appLockEnabled,
              activeThumbColor: green,
              onChanged: (v) async {
                await _setAppLock(v);
                setSheet(() {});
              },
            ),
            SwitchListTile(
              title: const Text('Use fingerprint'),
              subtitle: const Text('If this phone supports it'),
              value: _settings.useFingerprint,
              activeThumbColor: green,
              onChanged: _settings.appLockEnabled
                  ? (v) async {
                      await _settings.setUseFingerprint(v);
                      setSheet(() {});
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.pin_outlined),
              title: const Text('Change PIN'),
              enabled: _settings.appLockEnabled,
              onTap: () {
                Navigator.pop(context);
                _changePin();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );

  // ---------- Reminders ----------

  static const _tones = ['Polite', 'Friendly', 'Direct'];
  static const _days = [1, 3, 7];

  Future<void> _openReminders() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reminder settings', style: AppText.title),
                const SizedBox(height: 12),
                const Text('Tone', style: AppText.caption),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in _tones)
                      ChoiceChip(
                        key: ValueKey('tone-$t'),
                        label: Text(t),
                        selected: _settings.reminderTone == t,
                        selectedColor: mint,
                        onSelected: (_) async {
                          await _settings.setReminderTone(t);
                          setSheet(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Remind before recurring bills are due',
                  style: AppText.caption,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in _days)
                      ChoiceChip(
                        label: Text('$d ${d == 1 ? 'day' : 'days'}'),
                        selected: _settings.reminderDaysBefore == d,
                        selectedColor: mint,
                        onSelected: (_) async {
                          await _settings.setReminderDaysBefore(d);
                          setSheet(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Reminders are always kind: BahinKo never shames anyone '
                  'or shows debts to people outside the group.',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  // ---------- Offline ----------

  Future<void> _setOffline(bool v) async {
    await _settings.setOfflineMode(v);
    try {
      await GroupService.instance.setOffline(v);
    } catch (_) {
      // The switch still reflects the choice; it's applied on next start.
    }
    if (!mounted) return;
    setState(() {});
    showAppToast(
      context,
      v
          ? 'Offline: changes are saved on this phone'
          : 'Back online: syncing your changes',
    );
  }

  String get _offlineSubtitle {
    final since = _settings.offlineSince;
    if (!_settings.offlineMode || since == null) return 'Syncing live';
    final d = DateTime.now().difference(since);
    final ago = d.inMinutes < 1
        ? 'just now'
        : d.inHours < 1
        ? '${d.inMinutes} min ago'
        : d.inDays < 1
        ? '${d.inHours} h ago'
        : '${d.inDays} d ago';
    return 'Last synced $ago';
  }

  // ---------- Log out ----------

  Future<void> _logOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: Text(
          _saved
              ? 'You can sign back in any time with @$_username and your '
                    'PIN, on this phone or a new one.'
              : 'This account is only on this phone. If you log out you '
                    'will NOT get your groups back. Save your account '
                    'first (Profile > Save your account).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay logged in'),
          ),
          FilledButton(
            key: const ValueKey('confirm-logout'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: errorFg),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      if (_settings.offlineMode) await _setOffline(false); // sync first
      await AuthService.instance.signOut();
      // Remove this user's private data from the phone.
      await AppLockService.instance.clearPin();
      await WalletService.instance.clear();
    } catch (_) {
      if (mounted) showAppToast(context, "Couldn't log out. Try again.");
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Onboarding()),
      (_) => false,
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Center(child: Text('Profile', style: AppText.title)),
          const SizedBox(height: 16),
          _card(
            Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: mint,
                        border: Border.all(color: green, width: 2),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: green,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name,
                            style: AppText.section.copyWith(fontSize: 18),
                          ),
                          StreamBuilder<List<Group>>(
                            stream: _groups,
                            builder: (context, snap) {
                              final n = snap.data?.length;
                              return Text(
                                n == null
                                    ? _handle
                                    : '$_handle · $n ${n == 1 ? 'group' : 'groups'}',
                                style: AppText.caption,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (!_saved && _hasFirebaseUser) ...[
                  _SaveAccountBanner(onTap: _saveAccount),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    for (final p in WalletService.providers) ...[
                      if (p != WalletService.providers.first)
                        const SizedBox(width: 8),
                      Expanded(child: _walletChip(p)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            Column(
              children: [
                _SettingRow(
                  icon: Icons.lock_outline,
                  title: 'App lock',
                  subtitle: 'PIN or fingerprint',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _settings.appLockEnabled ? 'On' : 'Off',
                        style: const TextStyle(
                          color: green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: muted),
                    ],
                  ),
                  onTap: _openAppLock,
                ),
                _SettingRow(
                  icon: Icons.image_outlined,
                  title: 'Auto-delete receipt photos',
                  subtitle: 'After 30 days',
                  trailing: Switch(
                    key: const ValueKey('auto-delete'),
                    value: _settings.autoDeleteReceipts,
                    activeThumbColor: Colors.white,
                    activeTrackColor: green,
                    onChanged: (v) async {
                      await _settings.setAutoDeleteReceipts(v);
                      setState(() {});
                    },
                  ),
                ),
                _SettingRow(
                  icon: Icons.notifications_none,
                  title: 'Reminder settings',
                  subtitle:
                      '${_settings.reminderTone}, ${_settings.reminderDaysBefore} '
                      '${_settings.reminderDaysBefore == 1 ? 'day' : 'days'} '
                      'before due dates',
                  trailing: const Icon(Icons.chevron_right, color: muted),
                  onTap: _openReminders,
                ),
                _SettingRow(
                  icon: Icons.wifi_off,
                  title: 'Offline mode',
                  subtitle: _offlineSubtitle,
                  trailing: Switch(
                    key: const ValueKey('offline'),
                    value: _settings.offlineMode,
                    activeThumbColor: Colors.white,
                    activeTrackColor: green,
                    onChanged: _setOffline,
                  ),
                ),
                _SettingRow(
                  icon: Icons.verified_user_outlined,
                  title: 'Privacy and Trust',
                  subtitle: 'How we protect your data',
                  trailing: const Icon(Icons.chevron_right, color: muted),
                  onTap: () => go(context, const Privacy()),
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const ValueKey('logout'),
                onPressed: _logOut,
                style: TextButton.styleFrom(
                  foregroundColor: errorFg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Log out',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            padding: const EdgeInsets.all(4),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text('BahinKo v1.0 · prototype', style: AppText.caption),
          ),
        ],
      ),
    ),
  );

  Widget _card(Widget child, {EdgeInsets padding = const EdgeInsets.all(16)}) =>
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x0F000000), blurRadius: 14),
          ],
        ),
        child: child,
      );

  Widget _walletChip(String provider) {
    final number = _wallets[provider];
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('wallet-$provider'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editWallet(provider),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              WalletLogo(provider, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  number == null
                      ? 'Add $provider'
                      : '$provider ${maskPhone(number)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: number == null ? green : ink,
                    fontWeight: number == null
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One settings line: mint icon tile, title, subtitle, trailing control.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String title, subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  /// No divider under the last row.
  final bool last;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: mint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
          trailing,
        ],
      ),
    ),
  );
}

/// "Your GCash number" dialog. Its own widget so the text controller lives
/// exactly as long as the dialog (including its closing animation).
class _WalletDialog extends StatefulWidget {
  const _WalletDialog({required this.provider, this.initial});

  final String provider;
  final String? initial;

  @override
  State<_WalletDialog> createState() => _WalletDialogState();
}

class _WalletDialogState extends State<_WalletDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _number = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Your ${widget.provider} number'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kept only on this phone, encrypted. Leave it empty to remove.',
            style: AppText.caption,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('wallet-number'),
            controller: _number,
            autofocus: true,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              hintText: '0917 123 4567',
            ),
            validator: (v) {
              final text = v?.trim() ?? '';
              if (text.isEmpty) return null; // = remove
              return normalizePhone(text) == null
                  ? 'Enter a PH mobile number, like 0917 123 4567'
                  : null;
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('wallet-save'),
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, _number.text.trim());
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}

/// Orange card for older accounts that only live on this phone.
class _SaveAccountBanner extends StatelessWidget {
  const _SaveAccountBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFF4E5),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      key: const ValueKey('save-account'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Save your account: pick a username and PIN so you can '
                'sign back in after logging out or reinstalling.',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A4B00)),
              ),
            ),
            Icon(Icons.chevron_right, color: Color(0xFFB45309)),
          ],
        ),
      ),
    ),
  );
}

/// Username + new 6-digit PIN for an older, phone-only account.
class _SaveAccountDialog extends StatefulWidget {
  const _SaveAccountDialog();

  @override
  State<_SaveAccountDialog> createState() => _SaveAccountDialogState();
}

class _SaveAccountDialogState extends State<_SaveAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _pin.dispose();
    _pin2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService.instance.saveAccount(
        username: normalizeUsername(_username.text),
        pin: _pin.text,
      );
      // The same PIN now also unlocks the app on this phone.
      await AppLockService.instance.setPin(_pin.text);
      if (mounted) Navigator.pop(context, true);
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Save your account'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Keeps your groups. Your new PIN also unlocks the app.',
              style: AppText.caption,
            ),
            const SizedBox(height: 8),
            UsernameField(
              key: const ValueKey('save-username'),
              controller: _username,
            ),
            PinField(
              key: const ValueKey('save-pin'),
              controller: _pin,
              label: 'New 6-digit PIN',
              validator: validateNewPin,
            ),
            PinField(
              key: const ValueKey('save-pin2'),
              controller: _pin2,
              label: 'Enter the PIN again',
              validator: (v) => v != _pin.text ? "PINs don't match" : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: errorFg)),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Later'),
      ),
      FilledButton(
        key: const ValueKey('save-account-submit'),
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}

/// Current PIN + new PIN (changes the sign-in PIN and the app lock).
class _ChangePinDialog extends StatefulWidget {
  const _ChangePinDialog();

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  final _formKey = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _new2 = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _new2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService.instance.changePin(
        oldPin: _old.text,
        newPin: _new.text,
      );
      await AppLockService.instance.setPin(_new.text);
      if (mounted) Navigator.pop(context, true);
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message == 'Wrong username or PIN.'
              ? 'Your current PIN is wrong.'
              : e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Change PIN'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PinField(
              controller: _old,
              label: 'Current PIN',
              validator: (v) =>
                  (v ?? '').length < 4 ? 'Enter your current PIN' : null,
            ),
            PinField(
              controller: _new,
              label: 'New 6-digit PIN',
              validator: validateNewPin,
            ),
            PinField(
              controller: _new2,
              label: 'Enter the new PIN again',
              validator: (v) => v != _new.text ? "PINs don't match" : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: errorFg)),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Change'),
      ),
    ],
  );
}
