/// Figma "Privacy and Trust" (RA 10173, the Data Privacy Act): what
/// BahinKo collects and why, in plain words, plus "Delete my data".
///
/// Every promise here matches what the code does (see the comments), so
/// it can be defended line by line.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/screens/onboarding/onboarding_screen.dart';
import 'package:bahinko/services/app_lock_service.dart';
import 'package:bahinko/services/auth_service.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/services/settings_service.dart';
import 'package:bahinko/services/wallet_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/app_toast.dart';
import 'package:bahinko/widgets/box.dart';
import 'package:bahinko/widgets/pill.dart';

class Privacy extends StatelessWidget {
  const Privacy({super.key});

  @override
  Widget build(BuildContext context) {
    const rows = [
      (
        Icons.shield_outlined,
        'What we collect',
        'Your name, your groups, and their expenses and payments. Nothing '
            'else: no email, no contacts, no location.',
      ),
      (
        Icons.document_scanner_outlined,
        'Receipts stay on your phone',
        // receipt_scanner.dart: OCR on-device, redactForAi() before Gemini.
        'Text is read on your phone. Only that text goes to the AI, with '
            'card and phone numbers hidden first. The photo is never '
            'uploaded.',
      ),
      (
        Icons.lock_outline,
        'Locked and encrypted',
        // Firestore encrypts at rest + TLS; PIN = salted hash; WalletService.
        'Group data is encrypted in storage and in transit. Your PIN is '
            'stored only as a scrambled hash, and your GCash/Maya numbers '
            'stay encrypted on this phone.',
      ),
      (
        Icons.credit_card,
        'We never hold your money',
        'BahinKo only records payments. Money moves in GCash, Maya or cash, '
            'and only the person who received it can confirm it.',
      ),
      (
        Icons.edit_note,
        'You stay in control',
        'Edit or delete any expense (the group sees who changed what). '
            'Delete my data below removes you from everything.',
      ),
    ];
    return AppPage(
      'Privacy and Trust',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows)
            Box(
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: mint,
                  child: Icon(r.$1, color: green),
                ),
                title: Text(
                  r.$2,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(r.$3, style: const TextStyle(fontSize: 12)),
              ),
            ),
          const Pill('Data Privacy Act of 2012 (RA 10173)', bg: lime, fg: deep),
          const SizedBox(height: 20),
          const DeleteMyDataCard(),
        ],
      ),
    );
  }
}

/// Red "Delete my data" card. Steps, in order:
/// 1. leave every group (my name and account leave the member list);
///    groups where I'm the only app user and the creator are deleted;
/// 2. erase this phone's PIN, wallet numbers and settings;
/// 3. delete the account, then go back to the welcome screen.
class DeleteMyDataCard extends StatefulWidget {
  const DeleteMyDataCard({super.key});

  @override
  State<DeleteMyDataCard> createState() => _DeleteMyDataCardState();
}

class _DeleteMyDataCardState extends State<DeleteMyDataCard> {
  bool _deleting = false;

  Future<void> _start() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDeleteDialog(),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      final settings = SettingsService.instance;
      if (settings.offlineMode) {
        await GroupService.instance.setOffline(false); // must reach server
      }
      await GroupService.instance.leaveAllGroups();
      await AppLockService.instance.clearPin();
      await WalletService.instance.clear();
      await settings.clear();
      await AuthService.instance.deleteAccount();
    } on GroupFailure catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        showAppToast(context, e.message);
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        showAppToast(
          context,
          "Couldn't delete everything. Check your "
          'internet and try again.',
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Onboarding()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFDECEA),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delete my data',
          style: TextStyle(fontWeight: FontWeight.w800, color: errorFg),
        ),
        const SizedBox(height: 4),
        const Text(
          'Leave all your groups and erase your account and everything '
          'BahinKo keeps on this phone.',
          style: AppText.caption,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('delete-my-data'),
            onPressed: _deleting ? null : _start,
            style: OutlinedButton.styleFrom(
              foregroundColor: errorFg,
              side: const BorderSide(color: errorFg),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: _deleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever_outlined),
            label: Text(_deleting ? 'Deleting…' : 'Delete my data'),
          ),
        ),
      ],
    ),
  );
}

/// Explains exactly what happens; needs a tick before Delete works.
class _ConfirmDeleteDialog extends StatefulWidget {
  const _ConfirmDeleteDialog();

  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Delete my data?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('This will:'),
        const SizedBox(height: 6),
        const Text('• remove you from every group'),
        const Text('• delete groups where you are the only app user'),
        const Text('• erase your PIN, wallet numbers and settings'),
        const Text('• delete your BahinKo account'),
        const SizedBox(height: 8),
        const Text(
          "Expenses and payments you shared stay in the others' groups, "
          'so their balances still add up.',
          style: AppText.caption,
        ),
        CheckboxListTile(
          key: const ValueKey('delete-understood'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _understood,
          onChanged: (v) => setState(() => _understood = v ?? false),
          title: const Text(
            "I understand this can't be undone",
            style: TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('delete-confirm'),
        onPressed: _understood ? () => Navigator.pop(context, true) : null,
        style: FilledButton.styleFrom(backgroundColor: errorFg),
        child: const Text('Delete everything'),
      ),
    ],
  );
}
