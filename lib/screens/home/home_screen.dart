/// Figma Frame 3 "Home": net balance header, quick actions, group
/// categories, and the user's active groups.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/group.dart';
import 'package:bahinko/screens/bill/manual_receipt_entry_screen.dart';
import 'package:bahinko/screens/group/create_group_screen.dart';
import 'package:bahinko/screens/group/group_detail_screen.dart';
import 'package:bahinko/screens/history/activity_history_screen.dart';
import 'package:bahinko/screens/scan/scan_receipt_screen.dart';
import 'package:bahinko/screens/settle/settle_up_screen.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/widgets/icon_tile.dart';
import 'package:bahinko/widgets/pill.dart';
import 'package:bahinko/widgets/section_header.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  // BACKEND STEP: these totals will be computed from the user's payments.
  static const _owedToYouCents = 106000;
  static const _youOweCents = 35000;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header + quick-action card. The card overlaps the bottom of the
        // green header, so both live in a Stack.
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 44),
              child: _BalanceHeader(
                owedToYouCents: _owedToYouCents,
                youOweCents: _youOweCents,
              ),
            ),
            const Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              child: _QuickActions(),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                'Group Categories',
                actionText: 'See all',
                onAction: () => go(context, const CreateGroup()),
              ),
              const _CategoryGrid(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('Active Groups', style: AppText.section),
                  ),
                  TextButton.icon(
                    onPressed: () => go(context, const CreateGroup()),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New group'),
                    style: TextButton.styleFrom(
                      foregroundColor: green,
                      backgroundColor: mint,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const _ActiveGroups(),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Green header: profile/notification icons, net balance, and two chips.
class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({
    required this.owedToYouCents,
    required this.youOweCents,
  });

  final int owedToYouCents;
  final int youOweCents;

  @override
  Widget build(BuildContext context) {
    final net = owedToYouCents - youOweCents;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 64),
      decoration: const BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HeaderIcon(Icons.person_outline, onTap: () {}),
              _HeaderIcon(Icons.notifications_none, onTap: () {}),
            ],
          ),
          const Text('Net balance', style: TextStyle(color: Colors.white70)),
          Text(formatMoney(net), style: AppText.money(40, color: Colors.white)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Pill(
                'Owed to you ${formatMoney(owedToYouCents)}',
                bg: lime,
                fg: deep,
              ),
              Pill(
                'You owe ${formatMoney(youOweCents)}',
                bg: Colors.white,
                fg: errorFg,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small translucent round icon button used in the green header.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon(this.icon, {required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white24,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    ),
  );
}

/// White card with the four shortcuts: Scan, Add, Settle Up, History.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 16)],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconTile(
          Icons.qr_code_scanner,
          label: 'Scan',
          onTap: () => go(context, const ScanReceipt()),
        ),
        // TODO(M3): point "Add" to AddExpenseScreen (Frame 6) when ready.
        IconTile(
          Icons.add,
          label: 'Add',
          onTap: () => go(context, const ManualReceiptEntry()),
        ),
        IconTile(
          Icons.account_balance_wallet_outlined,
          label: 'Settle Up',
          onTap: () => go(context, const SettleUp()),
        ),
        IconTile(
          Icons.history,
          label: 'History',
          onTap: () => go(context, const ActivityHistory()),
        ),
      ],
    ),
  );
}

/// 4×2 grid of categories. Tapping one starts a new group of that type.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 4,
    shrinkWrap: true, // let the grid size itself inside the scroll view
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 8,
    childAspectRatio: 0.9,
    children: [
      for (final category in groupCategories)
        IconTile(
          // The last tile reads "More" on Home but means "Custom".
          category.icon == Icons.add ? Icons.grid_view : category.icon,
          label: category.name == 'Custom' ? 'More' : category.name,
          onTap: () => go(context, CreateGroup(initialCategory: category)),
        ),
    ],
  );
}

/// Horizontal list of group cards. Rebuilds when [groups] changes, so a
/// group made on the Create Group screen shows up right away.
class _ActiveGroups extends StatelessWidget {
  const _ActiveGroups();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<Group>>(
    valueListenable: groups,
    builder: (context, list, _) {
      // Empty state: no groups yet.
      if (list.isEmpty) {
        return Text(
          'No groups yet. Tap "New group" to start one.',
          style: AppText.caption,
        );
      }
      return SizedBox(
        height: 140,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) =>
              _GroupCard(group: list[i], highlighted: i == 0),
        ),
      );
    },
  );
}

/// One group card: green gradient for the first, lime for the others.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.highlighted});

  final Group group;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? Colors.white : deep;
    return GestureDetector(
      onTap: () => go(context, GroupDetail(group: group)),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: highlighted ? brandGradient : null,
          color: highlighted ? null : lime,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.display(18, color: fg),
            ),
            ValueListenableBuilder(
              valueListenable: group.members,
              builder: (context, members, _) => Text(
                '${members.length} members · ${group.unpaidCount} unpaid',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
            Text(
              formatMoney(group.totalCents),
              style: AppText.money(22, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
