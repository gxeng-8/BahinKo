/// Figma Frame 5 "Group Detail": total spent, members, expenses, recent
/// activity, and the Settle Up / Add Expense buttons.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/screens/bill/split_summary_screen.dart';
import 'package:bahinko/screens/group/invite_members_screen.dart';
import 'package:bahinko/screens/group/members_screen.dart';
import 'package:bahinko/screens/history/activity_history_screen.dart';
import 'package:bahinko/screens/scan/scan_receipt_screen.dart';
import 'package:bahinko/screens/settle/settle_up_screen.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/avatar.dart';
import 'package:bahinko/widgets/box.dart';
import 'package:bahinko/widgets/btn.dart';
import 'package:bahinko/widgets/pill.dart';
import 'package:bahinko/widgets/section_header.dart';

class GroupDetail extends StatelessWidget {
  /// Opens [group]; without one, shows the sample "Dinner at Jaro" group.
  const GroupDetail({super.key, this.group});

  final Group? group;

  @override
  Widget build(BuildContext context) {
    final g = group ?? demoGroup;
    return AppPage(
      g.name,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TotalCard(group: g),
          const SizedBox(height: 8),
          SectionHeader(
            'Members',
            actionText: 'See all',
            onAction: () => go(context, Members(group: g)),
          ),
          _MemberStrip(group: g),
          const SizedBox(height: 8),
          const SectionHeader('Expenses'),
          _ExpenseList(group: g),
          const SizedBox(height: 8),
          SectionHeader(
            'Activity',
            actionText: 'See all',
            onAction: () => go(context, const ActivityHistory()),
          ),
          // BACKEND STEP: read the latest entry from the group's activity feed.
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
      ),
      actions: [
        IconButton(
          tooltip: 'Invite',
          icon: const Icon(Icons.share_outlined),
          onPressed: () => go(context, InviteMembers(group: g)),
        ),
      ],
      bottom: Row(
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
            child: Btn('+ Add Expense', () => go(context, const ScanReceipt())),
          ),
        ],
      ),
    );
  }
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
              '${group.expenses.length} expenses',
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

/// Row of member avatars with first names underneath. Rebuilds when a
/// member is added on the Members or Invite screen.
class _MemberStrip extends StatelessWidget {
  const _MemberStrip({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) => Box(
    ValueListenableBuilder<List<Person>>(
      valueListenable: group.members,
      builder: (context, members, _) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final p in members)
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
    ),
  );
}

/// The group's expenses, or an empty state for a brand-new group.
class _ExpenseList extends StatelessWidget {
  const _ExpenseList({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    // Empty state (course requirement e).
    if (group.expenses.isEmpty) {
      return const Box(
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
      );
    }
    return Column(
      children: [
        for (final e in group.expenses)
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
}
