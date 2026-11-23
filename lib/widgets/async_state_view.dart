/// One widget for the three async states the course requires:
/// loading, empty, and error (with a Retry button).
///
/// Usage with a Future or Stream:
///
///     FutureBuilder<List<Bill>>(
///       future: billService.fetchBills(),
///       builder: (context, snap) => AsyncStateView<List<Bill>>(
///         snapshot: snap,
///         isEmpty: (bills) => bills.isEmpty,
///         emptyMessage: 'No bills yet. Scan a receipt to start.',
///         onRetry: () => setState(() {}),
///         builder: (bills) => BillList(bills),
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
  });

  final AsyncSnapshot<T> snapshot;
  final Widget Function(T data) builder;

  /// Returns true when the loaded data should show the empty state.
  final bool Function(T data)? isEmpty;
  final String emptyMessage;
  final IconData emptyIcon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // 1) Error state
    if (snapshot.hasError) {
      return _Message(
        icon: Icons.cloud_off_outlined,
        text: 'Something went wrong. Check your connection and try again.',
        action: onRetry == null ? null : Btn('Retry', onRetry, outlined: true),
      );
    }
    // 2) Loading state
    if (!snapshot.hasData) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: green),
        ),
      );
    }
    // 3) Empty state
    final data = snapshot.data as T;
    if (isEmpty?.call(data) ?? false) {
      return _Message(icon: emptyIcon, text: emptyMessage);
    }
    // 4) Loaded data
    return builder(data);
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 28,
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
