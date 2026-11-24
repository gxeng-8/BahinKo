/// Figma Frame 3 "Home": net balance header, quick actions, group
/// categories, and the user's active groups.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/models/group.dart';
import 'package:bahinko/screens/bill/add_expense_screen.dart';
import 'package:bahinko/screens/group/create_group_screen.dart';
import 'package:bahinko/screens/group/group_detail_screen.dart';
import 'package:bahinko/screens/group/join_group_screen.dart';
import 'package:bahinko/screens/history/activity_history_screen.dart';
import 'package:bahinko/screens/notifications/notifications_screen.dart';
import 'package:bahinko/screens/profile/profile_screen.dart';
import 'package:bahinko/screens/scan/scan_receipt_screen.dart';
import 'package:bahinko/screens/settle/settle_up_screen.dart';
import 'package:bahinko/screens/shell.dart';
import 'package:bahinko/services/auth_service.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/services/settings_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/utils/notifications.dart';
import 'package:bahinko/widgets/async_state_view.dart';
import 'package:bahinko/widgets/icon_tile.dart';
import 'package:bahinko/widgets/pill.dart';
import 'package:bahinko/widgets/section_header.dart';

class Home extends StatelessWidget {
  const Home({super.key});

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
              child: _BalanceHeader(),
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
                  TextButton(
                    onPressed: () => go(context, const JoinGroupScreen()),
                    style: TextButton.styleFrom(
                      foregroundColor: green,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Join'),
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
/// Green header: net balance and "owed to you / you owe" across ALL my
/// groups, computed live from real expenses and confirmed payments.
class _BalanceHeader extends StatefulWidget {
  const _BalanceHeader();

  @override
  State<_BalanceHeader> createState() => _BalanceHeaderState();
}

class _BalanceHeaderState extends State<_BalanceHeader> {
  late final Stream<({int owedToYou, int youOwe})> _totals = GroupService
      .instance
      .watchMyTotals();

  /// The bell's badge: my notifications newer than the last visit.
  late final Stream<List<GroupEvent>> _notifications = GroupService.instance
      .watchNotifications();

  /// Opens the bell list; when back, the badge recounts (now read).
  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
    if (mounted) setState(() {});
  }

  /// Person icon → the Profile tab (or the Profile page outside the shell).
  void _openProfile() {
    final shell = context.findAncestorStateOfType<ShellState>();
    if (shell != null) {
      shell.select(Shell.profileTab);
    } else {
      go(context, const Profile());
    }
  }

  /// First letter of my name, or null (then a person icon is shown).
  String? get _initial {
    try {
      final name = AuthService.instance.displayName?.trim() ?? '';
      return name.isEmpty ? null : name[0].toUpperCase();
    } catch (_) {
      return null; // Firebase not started (tests)
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<({int owedToYou, int youOwe})>(
        stream: _totals,
        builder: (context, snap) {
          final totals = snap.data;
          // Loading or error: show dashes instead of wrong numbers.
          String money(int? cents) => cents == null ? '₱—' : formatMoney(cents);
          final net = totals == null ? null : totals.owedToYou - totals.youOwe;
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
                    _HeaderIcon(
                      Icons.person_outline,
                      key: const ValueKey('home-profile'),
                      tooltip: 'Profile',
                      letter: _initial,
                      onTap: _openProfile,
                    ),
                    StreamBuilder<List<GroupEvent>>(
                      stream: _notifications,
                      builder: (context, snap) => _HeaderIcon(
                        Icons.notifications_none,
                        key: const ValueKey('home-bell'),
                        tooltip: 'Notifications',
                        badge: badgeLabel(
                          unreadCount(
                            snap.data ?? const [],
                            SettingsService.instance.notificationsSeenAt,
                          ),
                        ),
                        onTap: _openNotifications,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Net balance',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(money(net), style: AppText.money(40, color: Colors.white)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Pill(
                      'Owed to you ${money(totals?.owedToYou)}',
                      bg: lime,
                      fg: deep,
                    ),
                    Pill(
                      'You owe ${money(totals?.youOwe)}',
                      bg: Colors.white,
                      fg: errorFg,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
}

/// Small translucent round icon button used in the green header.
/// [letter] replaces the icon (my initial); [badge] adds a red count
/// ("3", "9+") on the corner.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon(
    this.icon, {
    super.key,
    required this.onTap,
    required this.tooltip,
    this.letter,
    this.badge,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final String? letter;
  final String? badge;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: badge == null ? tooltip : '$tooltip ($badge new)',
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white24,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44, // easy to hit with a thumb
              height: 44,
              child: Center(
                child: letter == null
                    ? Icon(icon, color: Colors.white, size: 20)
                    : Text(
                        letter!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: -4,
            right: -6,
            child: IgnorePointer(
              child: Container(
                key: const ValueKey('bell-badge'),
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: errorFg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
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
        IconTile(
          Icons.add,
          label: 'Add',
          onTap: () => go(context, const AddExpense()),
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

/// Grid of group categories. Tapping one starts a new group of that type.
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
      // "Custom" is left out here; it's still offered in Create Group.
      for (final category in groupCategories)
        if (category.name != 'Custom')
          IconTile(
            category.icon,
            label: category.name,
            onTap: () => go(context, CreateGroup(initialCategory: category)),
          ),
    ],
  );
}

/// Horizontal list of the user's groups, loaded live from [GroupService].
/// Shows loading, empty, and error (with Retry) states.
class _ActiveGroups extends StatefulWidget {
  const _ActiveGroups();

  @override
  State<_ActiveGroups> createState() => _ActiveGroupsState();
}

class _ActiveGroupsState extends State<_ActiveGroups> {
  /// Created once in initState. Creating the stream inside build() would
  /// open a new Firestore listener every time the screen rebuilds.
  late Stream<List<Group>> _groups;

  @override
  void initState() {
    super.initState();
    _groups = GroupService.instance.watchMyGroups();
  }

  /// Retry button: open a fresh stream after an error.
  void _reload() =>
      setState(() => _groups = GroupService.instance.watchMyGroups());

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Group>>(
    stream: _groups,
    builder: (context, snapshot) => AsyncStateView<List<Group>>(
      snapshot: snapshot,
      compact: true,
      onRetry: _reload,
      isEmpty: (list) => list.isEmpty,
      emptyIcon: Icons.groups_outlined,
      emptyMessage: 'No groups yet. Tap "New group" to start one.',
      builder: (list) => SizedBox(
        height: 140,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) =>
              _GroupCard(group: list[i], highlighted: i == 0),
        ),
      ),
    ),
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
      onTap: () => go(context, GroupDetail(groupId: group.id)),
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
            Text(
              '${group.members.length} members · ${group.unpaidCount} unpaid',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 12),
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
