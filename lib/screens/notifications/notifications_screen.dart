/// The bell on Home: reminders, payments waiting for my confirmation,
/// confirmations of my payments, and expenses that include me, from all
/// my groups. Opening it marks everything as read.
///
/// Tap a payment or reminder → Settle Up for that group; anything else →
/// the group.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:bahinko/screens/group/group_detail_screen.dart';
import 'package:bahinko/screens/history/activity_history_screen.dart'
    show dayLabel, timeLabel;
import 'package:bahinko/screens/recurring/recurring_bills_screen.dart';
import 'package:bahinko/screens/settle/settle_up_screen.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/services/settings_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/notifications.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/async_state_view.dart';
import 'package:bahinko/widgets/box.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Stream<List<GroupEvent>> _stream;

  /// Read-marker from BEFORE this visit, so new ones still show a dot now.
  final DateTime? _seenBefore = SettingsService.instance.notificationsSeenAt;

  @override
  void initState() {
    super.initState();
    _listen();
    unawaited(SettingsService.instance.setNotificationsSeenAt(DateTime.now()));
  }

  void _listen() => _stream = GroupService.instance.watchNotifications();

  bool _isNew(GroupEvent n) =>
      _seenBefore == null ||
      (n.event.createdAt ?? DateTime.now()).isAfter(_seenBefore);

  void _open(GroupEvent n) {
    final id = n.group.id;
    final Widget page = switch (n.event.type) {
      'payment' || 'reminder' || 'confirm' => SettleUp(groupId: id),
      'due' => RecurringBills(groupId: id),
      _ => GroupDetail(groupId: id),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => AppPage(
    'Notifications',
    onRefresh: () => setState(_listen),
    StreamBuilder<List<GroupEvent>>(
      stream: _stream,
      builder: (context, snap) => AsyncStateView<List<GroupEvent>>(
        snapshot: snap,
        onRetry: () => setState(_listen),
        isEmpty: (list) => list.isEmpty,
        emptyIcon: Icons.notifications_none,
        emptyMessage:
            "You're all caught up. Payments to confirm, reminders, "
            'confirmations and bills due soon will show up here.',
        builder: (list) {
          String? lastDay;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final n in list) ...[
                if (dayLabel(n.event.createdAt) != lastDay)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Text(
                      lastDay = dayLabel(n.event.createdAt),
                      style: AppText.section,
                    ),
                  ),
                _NotificationTile(n, isNew: _isNew(n), onTap: () => _open(n)),
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile(this.n, {required this.isNew, required this.onTap});

  final GroupEvent n;
  final bool isNew;
  final VoidCallback onTap;

  static (IconData, Color) _style(String type) => switch (type) {
    'reminder' => (
      Icons.notifications_active_outlined,
      const Color(0xFFB45309),
    ),
    'payment' => (Icons.account_balance_wallet_outlined, green),
    'confirm' => (Icons.check_circle, green),
    'expense' => (Icons.receipt_long_outlined, deep),
    'due' => (Icons.event_outlined, const Color(0xFFB45309)),
    'join' => (Icons.person_add_alt_1_outlined, green),
    _ => (Icons.edit_outlined, deep),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style(n.event.type);
    return Box(
      InkWell(
        key: ValueKey('notification-${n.event.id}'),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: mint,
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notificationText(n.event, GroupService.instance.myId),
                    style: TextStyle(
                      fontWeight: isNew ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${n.group.name} · ${timeLabel(n.event.createdAt)}',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            if (isNew)
              Container(
                key: const ValueKey('notification-new'),
                margin: const EdgeInsets.only(left: 8, top: 6),
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: errorFg,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
