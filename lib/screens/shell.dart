/// Main app frame after login (Figma Frame 3, bottom bar):
/// 4 tabs (Home · Stats · History · Profile) and a center scan button.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/screens/group/join_group_screen.dart';
import 'package:bahinko/screens/history/activity_history_screen.dart';
import 'package:bahinko/screens/home/home_screen.dart';
import 'package:bahinko/screens/scan/scan_receipt_screen.dart';
import 'package:bahinko/screens/profile/profile_screen.dart';
import 'package:bahinko/screens/stats/statistics_screen.dart';
import 'package:bahinko/services/invite_links.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/widgets/refreshable.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  /// Tab indexes, for [ShellState.select].
  static const profileTab = 3;

  @override
  State<Shell> createState() => ShellState();
}

/// Public so screens inside a tab can switch tabs (Home's person icon →
/// Profile) with `context.findAncestorStateOfType<ShellState>()`.
class ShellState extends State<Shell> {
  /// Index of the selected tab (0 = Home).
  int tab = 0;

  /// The page for each tab, in the same order as the nav buttons.
  /// Swipe down to refresh: Home, Stats and Profile are rebuilt by
  /// Refreshable; Activity History refreshes itself (it's also a pushed page).
  static const _pages = [
    Refreshable(child: Home()),
    Refreshable(child: Statistics()),
    ActivityHistory(),
    Refreshable(child: Profile()),
  ];

  void select(int index) => setState(() => tab = index);

  @override
  void initState() {
    super.initState();
    // An invite link may have opened the app, or may arrive later.
    pendingInvite.addListener(_openInvite);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInvite());
  }

  @override
  void dispose() {
    pendingInvite.removeListener(_openInvite);
    super.dispose();
  }

  /// Tapped an invite link: open Join with the code filled in.
  void _openInvite() {
    if (!mounted || pendingInvite.value == null) return;
    final code = takePendingInvite();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JoinGroupScreen(initialCode: code)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    // IndexedStack builds every tab once and only shows the selected one,
    // so each tab keeps its scroll position and state when you switch.
    body: IndexedStack(index: tab, children: _pages),

    // Scan is a flow you enter and leave, so it's pushed, not a tab.
    floatingActionButton: FloatingActionButton(
      tooltip: 'Scan receipt',
      shape: const CircleBorder(),
      elevation: 4,
      onPressed: () => go(context, const ScanReceipt()),
      // FloatingActionButton can't take a gradient, so paint one inside it.
      child: Ink(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: brandGradient,
        ),
        child: const SizedBox.expand(
          child: Icon(Icons.qr_code_scanner, color: Colors.white),
        ),
      ),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    bottomNavigationBar: BottomAppBar(
      color: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            selected: tab == 0,
            onTap: () => select(0),
          ),
          _NavItem(
            icon: Icons.bar_chart,
            label: 'Stats',
            selected: tab == 1,
            onTap: () => select(1),
          ),
          const SizedBox(width: 48), // space for the scan button notch
          _NavItem(
            icon: Icons.receipt_long_outlined,
            label: 'History',
            selected: tab == 2,
            onTap: () => select(2),
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            selected: tab == 3,
            onTap: () => select(3),
          ),
        ],
      ),
    ),
  );
}

/// One bottom-nav button: icon above a label, green when selected.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? green : muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
