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

  /// "Juan dela Cruz" → "@juandelacruz".
  String get _handle =>
      '@${_name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '')}';

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
        content: const Text(
          'Your BahinKo account is tied to this phone (no email or '
          'password). If you log out, you will NOT be able to get back '
          'into your groups, even on this phone. Your groups and their '
          'expenses stay for the other members.',
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
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 16,
                color: deep,
              ),
              const SizedBox(width: 6),
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
