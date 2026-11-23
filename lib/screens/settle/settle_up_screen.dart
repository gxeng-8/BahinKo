/// Figma Frame 12 "Settle Up": who pays whom, from REAL balances.
///
/// Balances = every expense's shares (owed to whoever paid) minus confirmed
/// payments. Smart settle turns them into the fewest transfers (see
/// utils/settle_calculator.dart). Payment flow:
///   payer taps "Pay with GCash/Maya" or "Paid in cash" → saved as PENDING
///   → the receiver taps "Confirm received" → CONFIRMED → balances update.
/// Payments to guests (no app) are confirmed right away, since guests can't
/// confirm for themselves. BahinKo never moves money; it only records it.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/screens/settings/privacy_screen.dart';
import 'package:bahinko/screens/settle/widgets/payment_dialogs.dart';
import 'package:bahinko/screens/settle/widgets/payment_proof_dialog.dart';
import 'package:bahinko/screens/settle/widgets/reminder_sheet.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/utils/settle_calculator.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/app_toast.dart';
import 'package:bahinko/widgets/async_state_view.dart';
import 'package:bahinko/widgets/avatar.dart';
import 'package:bahinko/widgets/box.dart';
import 'package:bahinko/widgets/btn.dart';
import 'package:bahinko/widgets/info_banner.dart';
import 'package:bahinko/widgets/pill.dart';
import 'package:bahinko/widgets/section_header.dart';

class SettleUp extends StatefulWidget {
  /// Settle the group [groupId]. If null (e.g. from Home), the user picks
  /// a group first.
  const SettleUp({super.key, this.groupId});

  final String? groupId;

  @override
  State<SettleUp> createState() => _SettleUpState();
}

class _SettleUpState extends State<SettleUp> {
  String? _groupId;
  Stream<GroupLedger>? _ledger;
  late final Stream<List<Group>> _groups;

  /// Last unpaid count we saved, so we don't write the same value twice.
  int? _savedUnpaid;

  String get _myId => GroupService.instance.myId;

  @override
  void initState() {
    super.initState();
    _groups = GroupService.instance.watchMyGroups();
    if (widget.groupId != null) _open(widget.groupId!);
  }

  void _open(String groupId) => setState(() {
    _groupId = groupId;
    _ledger = GroupService.instance.watchLedger(groupId);
  });

  /// Keeps the "N unpaid" on Home / Group Detail in sync with balances.
  void _syncUnpaid(GroupLedger ledger) {
    final count = ledger.debtorCount;
    if (count == ledger.group.unpaidCount || count == _savedUnpaid) return;
    _savedUnpaid = count;
    GroupService.instance
        .setUnpaidCount(ledger.group.id, count)
        .catchError((_) {}); // cosmetic; retried next time
  }

  // ---------- Actions ----------

  /// Saves a payment and shows the result.
  Future<void> _record(Payment payment, String doneMessage) async {
    try {
      await GroupService.instance.recordPayment(_groupId!, payment);
      if (mounted) showAppToast(context, doneMessage);
    } on GroupFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  /// "Pay with GCash/Maya": the existing hand-off → confirm → proof
  /// dialogs (Figma 13, 13b, 14), then the payment is recorded.
  Future<void> _payWithApp(
    GroupLedger ledger,
    Person me,
    Person to,
    int cents,
    String provider,
  ) async {
    final opened = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentOpeningDialog(
        provider: provider,
        member: me,
        payer: to,
        amountInCents: cents,
      ),
    );
    if (opened != true || !mounted) return;
    final paid = await showDialog<bool>(
      context: context,
      builder: (_) =>
          PaymentConfirmationDialog(provider: provider, amountInCents: cents),
    );
    if (paid != true || !mounted) return;
    final proof = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentProofDialog(
        member: me,
        payer: to,
        provider: provider,
        amountInCents: cents,
      ),
    );
    if (proof != true || !mounted) return;
    await _payment(ledger, me, to, cents, provider.toLowerCase());
  }

  /// Records [from] → [to]. Guests can't confirm, so payments to them are
  /// confirmed right away; app users confirm themselves.
  Future<void> _payment(
    GroupLedger ledger,
    Person from,
    Person to,
    int cents,
    String method,
  ) {
    final toGuest = ledger.group.isGuest(to);
    final toMe = to.id == _myId;
    return _record(
      Payment(
        fromId: from.id,
        fromName: from.name,
        toId: to.id,
        toName: to.name,
        amountCents: cents,
        method: method,
        status: toGuest || toMe ? 'confirmed' : 'pending',
      ),
      toGuest || toMe
          ? 'Marked ${formatMoney(cents)} as paid'
          : 'Sent. Waiting for ${to.name} to confirm.',
    );
  }

  Future<void> _confirmCash(
    GroupLedger ledger,
    Person from,
    Person to,
    int cents,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paid in cash?'),
        content: Text(
          '${_name(from)} paid ${_name(to)} ${formatMoney(cents)} in cash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, record it'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _payment(ledger, from, to, cents, 'cash');
    }
  }

  Future<void> _confirmReceived(Payment p) async {
    try {
      await GroupService.instance.confirmPayment(
        _groupId!,
        p,
        fullShare: false, // balances handle partial payments themselves
      );
      if (mounted) showAppToast(context, 'Confirmed: ${p.fromName} paid you');
    } on GroupFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  Future<void> _remind(Person from, Person me, int cents) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          ReminderSheet(member: from, payer: me, amountInCents: cents),
    );
    // Log it for the activity feed (Figma 20, "Reminders" filter).
    await GroupService.instance
        .logActivity(
          _groupId!,
          ActivityEvent(
            type: 'reminder',
            actorName: me.name,
            text: 'Reminder sent to ${from.name}',
          ),
        )
        .catchError((_) {});
  }

  String _name(Person p) => p.id == _myId ? 'You' : p.name;

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) => AppPage(
    'Settle Up',
    _ledger == null ? _groupChooser() : _ledgerView(),
    bottom: Btn('Done', () => Navigator.popUntil(context, (r) => r.isFirst)),
  );

  /// Shown when opened without a group: pick one.
  Widget _groupChooser() => StreamBuilder<List<Group>>(
    stream: _groups,
    builder: (context, snap) => AsyncStateView<List<Group>>(
      snapshot: snap,
      isEmpty: (list) => list.isEmpty,
      emptyIcon: Icons.groups_outlined,
      emptyMessage: 'No groups yet. Create or join one first.',
      builder: (groups) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Which group?'),
          for (final g in groups)
            Box(
              onTap: () => _open(g.id),
              Row(
                children: [
                  Icon(g.category.icon, color: green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      g.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (g.unpaidCount > 0)
                    Pill.unpaid(text: '${g.unpaidCount} unpaid'),
                  const Icon(Icons.chevron_right, color: muted),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  Widget _ledgerView() => StreamBuilder<GroupLedger>(
    stream: _ledger,
    builder: (context, snap) => AsyncStateView<GroupLedger>(
      snapshot: snap,
      onRetry: () => _open(_groupId!),
      builder: (ledger) {
        _syncUnpaid(ledger);
        return _LedgerBody(
          ledger: ledger,
          myId: _myId,
          name: _name,
          onPayWithApp: (to, cents, provider) {
            final me = ledger.group.memberById(_myId);
            if (me != null) _payWithApp(ledger, me, to, cents, provider);
          },
          onCash: (from, to, cents) => _confirmCash(ledger, from, to, cents),
          onConfirm: _confirmReceived,
          onRemind: (from, cents) {
            final me = ledger.group.memberById(_myId);
            if (me != null) _remind(from, me, cents);
          },
        );
      },
    ),
  );
}

/// The settle-up content for one group.
class _LedgerBody extends StatelessWidget {
  const _LedgerBody({
    required this.ledger,
    required this.myId,
    required this.name,
    required this.onPayWithApp,
    required this.onCash,
    required this.onConfirm,
    required this.onRemind,
  });

  final GroupLedger ledger;
  final String myId;
  final String Function(Person) name;
  final void Function(Person to, int cents, String provider) onPayWithApp;
  final void Function(Person from, Person to, int cents) onCash;
  final void Function(Payment p) onConfirm;
  final void Function(Person from, int cents) onRemind;

  @override
  Widget build(BuildContext context) {
    final group = ledger.group;
    // Payments waiting for MY confirmation (I'm the receiver).
    final toConfirm = [
      for (final p in ledger.payments)
        if (!p.isConfirmed && p.toId == myId) p,
    ];
    if (ledger.settled && toConfirm.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 40),
          const CircleAvatar(
            radius: 36,
            backgroundColor: mint,
            child: Icon(Icons.celebration_outlined, color: green, size: 36),
          ),
          const SizedBox(height: 12),
          Text('All settled up!', style: AppText.title),
          const SizedBox(height: 4),
          Text(
            ledger.expenses.isEmpty
                ? 'No expenses in ${group.name} yet.'
                : 'Nobody in ${group.name} owes anything.',
            style: AppText.caption,
          ),
        ],
      );
    }

    final iPay = [
      for (final t in ledger.transfers)
        if (t.fromId == myId) t,
    ];
    final paysMe = [
      for (final t in ledger.transfers)
        if (t.toId == myId) t,
    ];
    final others = [
      for (final t in ledger.transfers)
        if (t.fromId != myId && t.toId != myId) t,
    ];
    final count = ledger.transfers.length;
    final naive = ledger.naiveTransfers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoBanner(
          naive > count
              ? 'Smart settle: $count ${count == 1 ? 'transfer' : 'transfers'}'
                    ' instead of $naive · ${group.name}'
              : '$count ${count == 1 ? 'transfer' : 'transfers'} to settle '
                    '${group.name}',
          icon: Icons.auto_fix_high,
        ),
        if (toConfirm.isNotEmpty) ...[
          const SectionHeader('Waiting for you to confirm'),
          for (final p in toConfirm)
            Box(
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${p.fromName} says they paid you '
                      '${formatMoney(p.amountCents)} (${p.method})',
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: ValueKey('confirm-${p.id}'),
                    onPressed: () => onConfirm(p),
                    style: FilledButton.styleFrom(backgroundColor: green),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ),
        ],
        if (iPay.isNotEmpty) ...[
          const SectionHeader('You pay'),
          for (final t in iPay) _youPayCard(context, t),
        ],
        if (paysMe.isNotEmpty) ...[
          const SectionHeader('Pays you'),
          for (final t in paysMe) _paysYouCard(t),
        ],
        if (others.isNotEmpty) ...[
          const SectionHeader('Others in the group'),
          for (final t in others) _otherCard(t),
        ],
        const SizedBox(height: 8),
        const Text(
          'BahinKo only records payments. Money moves in GCash, Maya, or cash.',
          textAlign: TextAlign.center,
          style: AppText.caption,
        ),
        Center(
          child: TextButton(
            onPressed: () => go(context, const Privacy()),
            child: const Text('How we protect your data ›'),
          ),
        ),
      ],
    );
  }

  Person _person(String id) =>
      ledger.group.memberById(id) ??
      Person('Former member', '?', muted, '', '', id: id);

  /// Waiting text if pending payments already cover this transfer.
  String? _waiting(Transfer t) {
    final pending = pendingBetween(ledger.payments, t.fromId, t.toId);
    if (pending <= 0) return null;
    return pending >= t.amountCents
        ? 'Waiting for ${name(_person(t.toId))} to confirm'
        : '${formatMoney(pending)} waiting for confirmation';
  }

  Widget _header(Person p, String subtitle, int cents, {bool owed = false}) =>
      Row(
        children: [
          Avatar(p, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name(p),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
          Text(
            formatMoney(cents),
            style: AppText.money(18, color: owed ? paidFg : ink),
          ),
        ],
      );

  Widget _youPayCard(BuildContext context, Transfer t) {
    final to = _person(t.toId);
    final me = _person(myId);
    final waiting = _waiting(t);
    return Box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(to, ledger.group.name, t.amountCents),
          const SizedBox(height: 10),
          if (waiting != null)
            Pill.unpaid(text: waiting)
          else ...[
            Row(
              children: [
                Expanded(
                  child: Btn(
                    'Pay with GCash',
                    () => onPayWithApp(to, t.amountCents, 'GCash'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Btn(
                    'Pay with Maya',
                    () => onPayWithApp(to, t.amountCents, 'Maya'),
                    outlined: true,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              key: ValueKey('cash-${t.fromId}-${t.toId}'),
              onPressed: () => onCash(me, to, t.amountCents),
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text('Paid in cash'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paysYouCard(Transfer t) {
    final from = _person(t.fromId);
    final me = _person(myId);
    final waiting = _waiting(t);
    return Box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(from, ledger.group.name, t.amountCents, owed: true),
          const SizedBox(height: 10),
          if (waiting != null)
            Pill.unpaid(text: 'They paid: confirm above')
          else
            Row(
              children: [
                Expanded(
                  child: Btn(
                    'Send neutral reminder',
                    () => onRemind(from, t.amountCents),
                    outlined: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Btn('Got cash', () => onCash(from, me, t.amountCents)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _otherCard(Transfer t) {
    final from = _person(t.fromId);
    final to = _person(t.toId);
    final waiting = _waiting(t);
    // Anyone may mark a payment to a GUEST (they have no app to confirm).
    final canMark = ledger.group.isGuest(to) && waiting == null;
    return Box(
      Row(
        children: [
          Avatar(from, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${from.name} pays ${to.name}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            formatMoney(t.amountCents),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (canMark) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Mark as paid',
              icon: const Icon(Icons.check_circle_outline, color: green),
              onPressed: () => onCash(from, to, t.amountCents),
            ),
          ],
        ],
      ),
    );
  }
}
