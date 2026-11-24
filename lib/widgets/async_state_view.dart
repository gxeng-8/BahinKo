/// One widget for the three async states the course requires:
/// loading, empty, and error (with a Retry button).
///
/// Usage with a Future or Stream:
///
///     StreamBuilder<List<Group>>(
///       stream: _groupsStream, // create it in initState, not in build!
///       builder: (context, snap) => AsyncStateView<List<Group>>(
///         snapshot: snap,
///         isEmpty: (groups) => groups.isEmpty,
///         emptyMessage: 'No groups yet.',
///         onRetry: _reload,
///         builder: (groups) => GroupList(groups),
///       ),
///     )
library;

import 'package:flutter/material.dart';

import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/widgets/btn.dart';

class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.snapshot,
    required this.builder,
    this.isEmpty,
    this.emptyMessage = 'Nothing here yet.',
    this.emptyIcon = Icons.inbox_outlined,
    this.onRetry,
    this.compact = false,
  });

  final AsyncSnapshot<T> snapshot;
  final Widget Function(T data) builder;

  /// Returns true when the loaded data should show the empty state.
  final bool Function(T data)? isEmpty;
  final String emptyMessage;
  final IconData emptyIcon;
  final VoidCallback? onRetry;

  /// Smaller padding, for use inside a section rather than a whole page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // 1) Error state. Services throw errors whose toString() is a
    //    user-friendly message (GroupFailure, AuthFailure).
    if (snapshot.hasError) {
      final error = snapshot.error;
      final text = error is Exception && error.toString().isNotEmpty
          ? error.toString()
          : 'Something went wrong. Check your connection and try again.';
      return _Message(
        icon: Icons.cloud_off_outlined,
        text: text.replaceFirst('Exception: ', ''),
        compact: compact,
        action: onRetry == null ? null : Btn('Retry', onRetry, outlined: true),
      );
    }
    // 2) Loading state
    if (!snapshot.hasData) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 32),
          child: const CircularProgressIndicator(color: green),
        ),
      );
    }
    // 3) Empty state
    final data = snapshot.data as T;
    if (isEmpty?.call(data) ?? false) {
      return _Message(icon: emptyIcon, text: emptyMessage, compact: compact);
    }
    // 4) Loaded data
    return builder(data);
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    required this.compact,
    this.action,
  });

  final IconData icon;
  final String text;
  final bool compact;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, // centered even inside a left-aligned Column
    padding: EdgeInsets.all(compact ? 12 : 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: compact ? 20 : 28,
          backgroundColor: mint,
          child: Icon(icon, color: green),
        ),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}
