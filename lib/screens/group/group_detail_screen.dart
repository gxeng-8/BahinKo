/// Figma Frame 5 "Group Detail": total spent, members, expenses, recent
/// activity, and the Settle Up / Add Expense buttons.
///
/// Data comes live from [GroupService]: one stream for the group and one
/// for its expenses, each with loading / empty / error states.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/data/in_memory_group_service.dart' show demoGroupId;
import 'package:bahinko/models/group.dart';
import 'package:bahinko/screens/bill/split_summary_screen.dart';
import 'package:bahinko/screens/group/invite_members_screen.dart';
import 'package:bahinko/screens/group/members_screen.dart';
import 'package:bahinko/screens/history/activity_history_screen.dart';
import 'package:bahinko/screens/scan/scan_receipt_screen.dart';
import 'package:bahinko/screens/settle/settle_up_screen.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/navigation.dart';
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
  late Stream<Group> _group;
  late Stream<List<GroupExpense>> _expenses;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _group = GroupService.instance.watchGroup(widget.groupId);
    _expenses = GroupService.instance.watchExpenses(widget.groupId);
  }

  /// Retry button: re-open both streams after an error.
  void _reload() => setState(_listen);

  @override
  Widget build(BuildContext context) => StreamBuilder<Group>(
    stream: _group,
    builder: (context, snapshot) {
      final g = snapshot.data;
      return AppPage(
        g?.name ?? 'Group', // title appears once the group has loaded
        AsyncStateView<Group>(
          snapshot: snapshot,
          onRetry: _reload,
          builder: (g) => _GroupBody(group: g, expenses: _expenses),
        ),
        actions: [
          if (g != null)
            IconButton(
              tooltip: 'Invite',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => go(context, InviteMembers(groupId: g.id)),
            ),
        ],
        bottom: g == null
            ? null
            : Row(
                children: [
                  Expanded(
                    child: Btn(
                      'Settle Up',
                      () => go(context, const SettleUp()),
                      outlined: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // TODO(M3): open AddExpenseScreen (Frame 6) when it's built.
                  Expanded(
                    child: Btn(
                      '+ Add Expense',
                      () => go(context, const ScanReceipt()),
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

/// Everything below the app bar once the group has loaded.
class _GroupBody extends StatelessWidget {
  const _GroupBody({required this.group, required this.expenses});

  final Group group;
  final Stream<List<GroupExpense>> expenses;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _TotalCard(group: group),
      const SizedBox(height: 8),
      SectionHeader(
        'Members',
        actionText: 'See all',
        onAction: () => go(context, Members(groupId: group.id)),
      ),
      _MemberStrip(group: group),
      const SizedBox(height: 8),
      const SectionHeader('Expenses'),
      StreamBuilder<List<GroupExpense>>(
        stream: expenses,
        builder: (context, snapshot) => AsyncStateView<List<GroupExpense>>(
          snapshot: snapshot,
          compact: true,
          isEmpty: (list) => list.isEmpty,
          emptyIcon: Icons.receipt_long_outlined,
          emptyMessage: 'No expenses yet. Add one or scan a receipt.',
          builder: (list) => _ExpenseList(expenses: list),
        ),
      ),
      const SizedBox(height: 8),
      SectionHeader(
        'Activity',
        actionText: 'See all',
        onAction: () => go(context, const ActivityHistory()),
      ),
      // TODO(M5): read the latest entry from the group's activity feed.
      const Box(
        Row(
          children: [
            Icon(Icons.edit_outlined, size: 16, color: muted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Jun edited Soju from ₱420 to ₱450',
                style: TextStyle(fontSize: 12),
              ),
            ),
            Text('2h ago', style: AppText.caption),
          ],
        ),
      ),
    ],
  );
}

/// Dark gradient card: "Total spent ₱2,950" + expense/unpaid pills.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) => Container(
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
          formatMoney(group.totalCents),
          style: AppText.money(32, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            Pill(
              '${group.expenseCount} expenses',
              bg: Colors.white24,
              fg: Colors.white,
            ),
            if (group.unpaidCount > 0)
              Pill.unpaid(text: '${group.unpaidCount} unpaid'),
          ],
        ),
      ],
    ),
  );
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
                  Text(p.name, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// The group's expense cards.
class _ExpenseList extends StatelessWidget {
  const _ExpenseList({required this.expenses});

  final List<GroupExpense> expenses;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final e in expenses)
        Box(
          onTap: () => go(context, const SplitSummary()),
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
                      'Paid by ${e.paidBy} · split ${e.splitWays} ways',
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
                  e.unpaidCount > 0
                      ? Pill.unpaid(text: '${e.unpaidCount} unpaid')
                      : const Pill('In smart settle', icon: Icons.sync),
                ],
              ),
            ],
          ),
        ),
    ],
  );
}
