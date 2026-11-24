/// Shared screen layout used by most pages: centered display-font title,
/// round back button, scrollable body, and optional pinned bottom buttons.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/widgets/refreshable.dart';

/// Standard page scaffold so every screen looks consistent.
class AppPage extends StatelessWidget {
  final String title;
  final Widget body;

  /// Optional widget pinned to the bottom (usually one or two [Btn]s).
  final Widget? bottom;
  final List<Widget>? actions;

  /// Swipe down to reload. The page re-opens its streams here (the server
  /// check runs first, see [syncNow]). Null = no pull-to-refresh (forms).
  final VoidCallback? onRefresh;

  const AppPage(
    this.title,
    this.body, {
    super.key,
    this.bottom,
    this.actions,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, style: AppText.title),
      leading: Navigator.canPop(context) ? const RoundBackButton() : null,
      actions: actions,
    ),
    body: onRefresh == null
        ? SingleChildScrollView(padding: const EdgeInsets.all(16), child: body)
        : PullToRefresh(
            onRefresh: () async {
              await syncNow(context);
              onRefresh!();
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: body,
            ),
          ),
    bottomNavigationBar: bottom == null
        ? null
        : Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12)],
            ),
            child: SafeArea(top: false, child: bottom!),
          ),
  );
}

/// White round "<" button used at the top-left of every Figma screen.
class RoundBackButton extends StatelessWidget {
  const RoundBackButton({super.key, this.onDark = false});

  /// Use the translucent style when placed on a green header.
  final bool onDark;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Material(
      color: onDark ? Colors.white24 : Colors.white,
      shape: CircleBorder(
        side: BorderSide(color: onDark ? Colors.transparent : border),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.maybePop(context),
        child: Icon(
          Icons.chevron_left,
          color: onDark ? Colors.white : deep,
          semanticLabel: 'Back',
        ),
      ),
    ),
  );
}
