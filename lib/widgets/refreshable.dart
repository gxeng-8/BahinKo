/// Pull-to-refresh: swipe down from the top of a page to reload it.
///
/// 1. [syncNow] asks the server for the latest data (shows a message if
///    offline or unreachable; the page still reloads from the phone).
/// 2. The page re-opens its live streams, so everything on it is rebuilt.
///
/// Pages made with AppPage get this by passing `onRefresh`. The bottom-tab
/// pages (Home, Stats, Profile) are wrapped in [Refreshable], which
/// rebuilds the whole page from scratch.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/widgets/app_toast.dart';

/// Checks the server; returns false (after a message) if it couldn't.
Future<bool> syncNow(BuildContext context) async {
  try {
    await GroupService.instance.refresh();
    return true;
  } on GroupFailure catch (e) {
    if (context.mounted) showAppToast(context, e.message);
    return false;
  }
}

/// The green spinner used by every refreshable page.
class PullToRefresh extends StatelessWidget {
  const PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;

  /// Must contain a vertical scroll view.
  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: green,
    backgroundColor: Colors.white,
    onRefresh: onRefresh,
    child: child,
  );
}

/// Rebuilds [child] from scratch after a pull, so every stream inside it
/// starts again.
class Refreshable extends StatefulWidget {
  const Refreshable({super.key, required this.child});

  final Widget child;

  @override
  State<Refreshable> createState() => _RefreshableState();
}

class _RefreshableState extends State<Refreshable> {
  int _generation = 0;

  Future<void> _refresh() async {
    await syncNow(context);
    if (mounted) setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) => PullToRefresh(
    onRefresh: _refresh,
    child: KeyedSubtree(key: ValueKey(_generation), child: widget.child),
  );
}

/// Lets short pages be pulled too (normally a page that fits on screen
/// can't scroll, so the pull would do nothing). Set on MaterialApp.
class AlwaysPullableScrollBehavior extends MaterialScrollBehavior {
  const AlwaysPullableScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics());
}
