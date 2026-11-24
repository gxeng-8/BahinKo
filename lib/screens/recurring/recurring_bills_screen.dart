/// Figma Frames 16–17 "Recurring Bills": a group's monthly bills (rent,
/// WiFi, electricity), saved in Firestore at groups/{id}/recurring.
///
/// * Switch: pause / resume a bill.
/// * Tap: add this month's bill as an expense (Add Expense, pre-filled).
/// * Swipe left: delete (asks first).
/// * "+ Add recurring bill": validated form (AddRecurringBillDialog).
/// Opened from Group Detail; without a group, the user picks one.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/recurring_bill.dart';
import 'package:bahinko/screens/bill/add_expense_screen.dart';
import 'package:bahinko/screens/recurring/widgets/add_recurring_bill_dialog.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/services/settings_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/app_toast.dart';
import 'package:bahinko/widgets/async_state_view.dart';
import 'package:bahinko/widgets/avatar.dart';
import 'package:bahinko/widgets/box.dart';
import 'package:bahinko/widgets/btn.dart';

class RecurringBills extends StatefulWidget {
  const RecurringBills({super.key, this.groupId});

  /// The group whose bills to show (null = pick one).
  final String? groupId;

  @override
  State<RecurringBills> createState() => _RecurringBillsState();
}

class _RecurringBillsState extends State<RecurringBills> {
  late final Stream<List<Group>> _groups;
  String? _groupId;

  /// The bills stream for [_billsFor] (re-created when the group changes).
  Stream<List<RecurringBill>>? _bills;
  String? _billsFor;

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _groups = GroupService.instance.watchMyGroups();
    _groupId = widget.groupId;
  }

  /// The group to show: the chosen one, else a bills-type group, else the
  /// newest.
  Group? _pick(List<Group> groups) {
    if (groups.isEmpty) return null;
    for (final g in groups) {
      if (g.id == _groupId) return g;
    }
    const billsTypes = {'Boarding', 'Utilities', 'Subscriptions', 'Bills'};
    return groups.firstWhere(
      (g) => billsTypes.contains(g.category.name),
      orElse: () => groups.first,
    );
  }

  Stream<List<RecurringBill>> _billsOf(String groupId) {
    if (_billsFor != groupId) {
      _billsFor = groupId;
      _bills = GroupService.instance.watchRecurring(groupId);
    }
    return _bills!;
  }

  Future<void> _add(Group group) async {
    final bill = await showDialog<RecurringBill>(
      context: context,
      builder: (_) => const AddRecurringBillDialog(),
    );
    if (bill == null || !mounted) return;
    try {
      await GroupService.instance.addRecurring(group.id, bill);
      if (mounted) showAppToast(context, 'Added ${bill.name}');
    } on GroupFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  Future<void> _toggle(Group group, RecurringBill bill, bool on) async {
    try {
      await GroupService.instance.setRecurringEnabled(group.id, bill.id, on);
    } on GroupFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  Future<bool> _confirmDelete(RecurringBill bill) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete ${bill.name}?'),
          content: const Text(
            'It stops repeating. Expenses already added from it stay.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: errorFg),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _delete(Group group, RecurringBill bill) async {
    try {
      await GroupService.instance.deleteRecurring(group.id, bill.id);
      if (mounted) showAppToast(context, 'Deleted ${bill.name}');
    } on GroupFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  /// Tap a bill: add this month's as an expense, ready to split.
  void _addAsExpense(Group group, RecurringBill bill) {
    final due = bill.nextDue(DateTime.now());
    go(
      context,
      AddExpense(
        groupId: group.id,
        title: '${bill.name} (${_monthNames[due.month - 1]})',
        initialAmountCents: bill.amountCents,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Group>>(
    stream: _groups,
    builder: (context, snap) {
      final groups = snap.data ?? const <Group>[];
      final group = _pick(groups);
      return AppPage(
        'Recurring Bills',
        AsyncStateView<List<Group>>(
          snapshot: snap,
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.groups_outlined,
          emptyMessage: 'Create or join a group first, then add its bills.',
          builder: (_) => _body(groups, group!),
        ),
        bottom: group == null
            ? null
            : Btn('+ Add recurring bill', () => _add(group)),
      );
    },
  );

  Widget _body(List<Group> groups, Group group) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.groupId == null && groups.length > 1) ...[
        DropdownButtonFormField<String>(
          key: const ValueKey('recurring-group'),
          initialValue: group.id,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Group'),
          items: [
            for (final g in groups)
              DropdownMenuItem(value: g.id, child: Text(g.name)),
          ],
          onChanged: (id) => setState(() => _groupId = id),
        ),
        const SizedBox(height: 12),
      ],
      StreamBuilder<List<RecurringBill>>(
        stream: _billsOf(group.id),
        builder: (context, snap) => AsyncStateView<List<RecurringBill>>(
          snapshot: snap,
          onRetry: () => setState(() => _billsFor = null),
          builder: (bills) => _billList(group, bills),
        ),
      ),
    ],
  );

  Widget _billList(Group group, List<RecurringBill> bills) {
    final monthly = bills
        .where((b) => b.enabled)
        .fold(0, (sum, b) => sum + b.amountCents);
    final days = SettingsService.instance.reminderDaysBefore;
    return Column(
      children: [
        Box(
          color: const Color(0xFF74E4A7),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${formatMoney(monthly)} monthly · '
                      '${group.members.length} members',
                      key: const ValueKey('recurring-total'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              for (final person in group.members.take(4))
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Avatar(person, size: 28),
                ),
            ],
          ),
        ),
        if (bills.isEmpty)
          const Box(
            Column(
              children: [
                Icon(Icons.event_repeat, color: green, size: 32),
                SizedBox(height: 6),
                Text(
                  'No recurring bills yet. Add rent, WiFi or electricity '
                  'so nobody forgets.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
              ],
            ),
          ),
        for (final bill in bills)
          Dismissible(
            key: ValueKey('bill-${bill.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmDelete(bill),
            onDismissed: (_) => _delete(group, bill),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: errorFg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            child: _BillTile(
              bill: bill,
              onTap: () => _addAsExpense(group, bill),
              onToggle: (on) => _toggle(group, bill, on),
            ),
          ),
        Box(
          color: lime,
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined, color: green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reminders go out $days ${days == 1 ? 'day' : 'days'} '
                  'before each due date (change it in Profile). Tap a bill '
                  "to add this month's expense; swipe left to delete.",
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({
    required this.bill,
    required this.onTap,
    required this.onToggle,
  });

  final RecurringBill bill;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  /// A fitting icon from the bill's name.
  static IconData _icon(String name) {
    final n = name.toLowerCase();
    if (n.contains('wifi') || n.contains('internet')) return Icons.wifi;
    if (n.contains('electric') || n.contains('meralco')) {
      return Icons.bolt_outlined;
    }
    if (n.contains('water')) return Icons.water_drop_outlined;
    if (n.contains('rent') || n.contains('house') || n.contains('boarding')) {
      return Icons.home_outlined;
    }
    if (n.contains('netflix') || n.contains('spotify')) return Icons.repeat;
    return Icons.event_repeat;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final due = bill.nextDue(DateTime.now());
    return Opacity(
      opacity: bill.enabled ? 1 : 0.55,
      child: Box(
        onTap: onTap,
        Row(
          children: [
            CircleAvatar(
              backgroundColor: mint,
              child: Icon(_icon(bill.name), color: green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    bill.enabled
                        ? 'Next: ${_months[due.month - 1]} ${due.day}'
                              '${bill.varies ? ' · amount varies' : ''}'
                        : 'Paused',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            Text(
              bill.amount.isNotEmpty
                  ? bill.amount
                  : formatMoney(bill.amountCents),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Switch(
              key: ValueKey('bill-switch-${bill.id}'),
              value: bill.enabled,
              activeTrackColor: green,
              onChanged: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}
