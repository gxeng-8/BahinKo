/// Figma Frame 5 "Group Detail": total spent, members, expenses, recent
/// activity, and the Settle Up / Add Expense buttons.
///
/// Loads the group's ledger (group + expenses + payments) live from
/// [GroupService], so totals, "N unpaid" and the expense labels always
/// match the real balances. Loading / empty / error states included.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/data/in_memory_group_service.dart' show demoGroupId;
import 'package:bahinko/models/group.dart';
import 'package:bahinko/screens/bill/add_expense_screen.dart';
import 'package:bahinko/screens/bill/split_summary_screen.dart';
import 'package:bahinko/screens/group/invite_members_screen.dart';
import 'package:bahinko/screens/group/members_screen.dart';
import 'package:bahinko/screens/history/activity_history_screen.dart';
import 'package:bahinko/screens/recurring/recurring_bills_screen.dart';
import 'package:bahinko/screens/report/report_preview_screen.dart';
import 'package:bahinko/screens/settle/settle_up_screen.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/utils/settle_calculator.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/async_state_view.dart';
import 'package:bahinko/widgets/avatar.dart';
import 'package:bahinko/widgets/box.dart';
import 'package:bahinko/widgets/btn.dart';
import 'package:bahinko/widgets/pill.dart';
import 'package:bahinko/widgets/section_header.dart';

class GroupDetail extends StatefulWidget {
  /// Opens the group with [groupId] (defaults to the sample group).
  const GroupDetail({super.key, this.groupId = demoGroupId});

  final String groupId;

  @override
  State<GroupDetail> createState() => _GroupDetailState();
}

class _GroupDetailState extends State<GroupDetail> {
  // Streams are created once (initState), not on every build.
  late Stream<GroupLedger> _ledger;
  late Stream<List<ActivityEvent>> _activity;
  int? _savedUnpaid;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _ledger = GroupService.instance.watchLedger(widget.groupId);
    _activity = GroupService.instance.watchActivity(widget.groupId);
  }

  /// Retry button: re-open the streams after an error.
  void _reload() => setState(_listen);

  /// Keeps the stored "N unpaid" (shown on Home) equal to the balances.
  void _syncUnpaid(GroupLedger ledger) {
    final count = ledger.debtorCount;
    if (count == ledger.group.unpaidCount || count == _savedUnpaid) return;
    _savedUnpaid = count;
    GroupService.instance
        .setUnpaidCount(widget.groupId, count)
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<GroupLedger>(
    stream: _ledger,
    builder: (context, snapshot) {
      final ledger = snapshot.data;
      final id = widget.groupId;
      return AppPage(
        ledger?.group.name ?? 'Group', // title once loaded
        onRefresh: _reload,
        AsyncStateView<GroupLedger>(
          snapshot: snapshot,
          onRetry: _reload,
          builder: (ledger) {
            _syncUnpaid(ledger);
            return _GroupBody(ledger: ledger, activity: _activity);
          },
        ),
        actions: [
          if (ledger != null)
            IconButton(
              tooltip: 'Report',
              icon: const Icon(Icons.description_outlined),
              onPressed: () => go(context, ReportPreview(groupId: id)),
            ),
          if (ledger != null)
            IconButton(
              tooltip: 'Invite',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => go(context, InviteMembers(groupId: id)),
            ),
        ],
        bottom: ledger == null
            ? null
            : Row(
                children: [
                  Expanded(
                    child: Btn(
                      'Settle Up',
                      () => go(context, SettleUp(groupId: id)),
                      outlined: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Btn(
                      '+ Add Expense',
                      () => go(context, AddExpense(groupId: id)),
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

/// Everything below the app bar once the ledger has loaded.
class _GroupBody extends StatelessWidget {
  const _GroupBody({required this.ledger, required this.activity});

  final GroupLedger ledger;
  final Stream<List<ActivityEvent>> activity;

  @override
  Widget build(BuildContext context) {
    final group = ledger.group;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TotalCard(ledger: ledger),
        const SizedBox(height: 8),
        SectionHeader(
          'Members',
          actionText: 'See all',
          onAction: () => go(context, Members(groupId: group.id)),
        ),
        _MemberStrip(group: group),
        Box(
          onTap: () => go(context, RecurringBills(groupId: group.id)),
          const Row(
            children: [
              Icon(Icons.event_repeat, color: green),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Recurring bills',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text('Rent, WiFi, utilities', style: AppText.caption),
              Icon(Icons.chevron_right, color: muted),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const SectionHeader('Expenses'),
        if (ledger.expenses.isEmpty)
          // Empty state (course requirement e).
          const Box(
            Column(
              children: [
                Icon(Icons.receipt_long_outlined, color: green, size: 32),
                SizedBox(height: 8),
                Text(
                  'No expenses yet. Add one or scan a receipt.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
              ],
            ),
          )
        else
          for (final e in ledger.expenses)
            _ExpenseCard(
              groupId: group.id,
              expense: e,
              settled: ledger.settled,
            ),
        const SizedBox(height: 8),
        SectionHeader(
          'Activity',
          actionText: 'See all',
          onAction: () => go(context, ActivityHistory(groupId: group.id)),
        ),
        _LatestActivity(stream: activity),
      ],
    );
  }
}

/// Dark gradient card: "Total spent ₱2,950" + expense/unpaid pills.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.ledger});

  final GroupLedger ledger;

  @override
  Widget build(BuildContext context) {
    final total = ledger.expenses.fold(0, (sum, e) => sum + e.amountCents);
    final unpaid = ledger.debtorCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total spent', style: TextStyle(color: Colors.white70)),
          Text(
            formatMoney(total),
            style: AppText.money(32, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Pill(
                '${ledger.expenses.length} expenses',
                bg: Colors.white24,
                fg: Colors.white,
              ),
              if (unpaid > 0) Pill.unpaid(text: '$unpaid unpaid'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Row of member avatars with first names underneath.
class _MemberStrip extends StatelessWidget {
  const _MemberStrip({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) => Box(
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in group.members)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                children: [
                  Avatar(p, size: 38),
                  const SizedBox(height: 4),
                  Text(
                    p.id == GroupService.instance.myId ? 'You' : p.name,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// One expense: icon, title, who paid, amount, settle status. Tap → summary.
class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.groupId,
    required this.expense,
    required this.settled,
  });

  final String groupId;
  final GroupExpense expense;

  /// True when the whole group is settled up.
  final bool settled;

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final paidBy = e.paidById == GroupService.instance.myId ? 'You' : e.paidBy;
    return Box(
      onTap: () => go(
        context,
        SplitSummary(groupId: groupId, expenseId: e.id.isEmpty ? null : e.id),
      ),
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: mint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(e.icon, color: green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Paid by $paidBy · split ${e.splitWays} ways',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(e.amountCents),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              settled
                  ? const Pill.paid(text: 'Settled')
                  : const Pill('In smart settle', icon: Icons.sync),
            ],
          ),
        ],
      ),
    );
  }
}

/// The newest activity entry, e.g. "Jun edited Soju · 2h ago".
class _LatestActivity extends StatelessWidget {
  const _LatestActivity({required this.stream});

  final Stream<List<ActivityEvent>> stream;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ActivityEvent>>(
    stream: stream,
    builder: (context, snap) => AsyncStateView<List<ActivityEvent>>(
      snapshot: snap,
      compact: true,
      isEmpty: (list) => list.isEmpty,
      emptyIcon: Icons.history,
      emptyMessage: 'No activity yet.',
      builder: (list) {
        final e = list.first;
        return Box(
          Row(
            children: [
              const Icon(Icons.history, size: 16, color: muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(e.text, style: const TextStyle(fontSize: 12)),
              ),
              if (e.createdAt != null)
                Text(_ago(e.createdAt!), style: AppText.caption),
            ],
          ),
        );
      },
    ),
  );

  /// "just now", "5m ago", "2h ago", "3d ago".
  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
