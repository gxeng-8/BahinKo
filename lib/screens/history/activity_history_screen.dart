/// Figma Frame 20 "Activity History" (History tab): everything that
/// happened in your groups (expenses, payments, confirmations, reminders,
/// edits, joins), newest first, grouped by day.
///
/// Searchable, with filter chips. Live from every group's activity feed
/// (GroupService.watchAllActivity), or one group's when [groupId] is given
/// (Group Detail → Activity "See all").
library;

import 'package:flutter/material.dart';

import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/notifications.dart' show GroupEvent;
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/async_state_view.dart';
import 'package:bahinko/widgets/box.dart';

/// Filter chips → which event types they show.
const activityFilters = <String, Set<String>>{
  'All': {},
  'Expenses': {'expense'},
  'Payments': {'payment', 'confirm'},
  'Reminders': {'reminder'},
  'Edits': {'edit', 'flag'},
};

class ActivityHistory extends StatefulWidget {
  const ActivityHistory({super.key, this.groupId});

  /// Only this group's activity (null = all my groups).
  final String? groupId;

  @override
  State<ActivityHistory> createState() => _ActivityHistoryState();
}

class _ActivityHistoryState extends State<ActivityHistory> {
  late Stream<List<GroupEvent>> _events;
  final _search = TextEditingController();
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    final all = GroupService.instance.watchAllActivity();
    final id = widget.groupId;
    _events = id == null
        ? all
        : all.map(
            (list) => [
              for (final e in list)
                if (e.group.id == id) e,
            ],
          );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The events that match the chip and the search box.
  List<GroupEvent> _visible(List<GroupEvent> all) {
    final types = activityFilters[_filter]!;
    final q = _search.text.trim().toLowerCase();
    return [
      for (final e in all)
        if ((types.isEmpty || types.contains(e.event.type)) &&
            (q.isEmpty ||
                e.event.text.toLowerCase().contains(q) ||
                e.group.name.toLowerCase().contains(q)))
          e,
    ];
  }

  @override
  Widget build(BuildContext context) => AppPage(
    'Activity',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('activity-search'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search activity',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(_search.clear),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in activityFilters.keys)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: _filter == f,
                    selectedColor: mint,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<GroupEvent>>(
          stream: _events,
          builder: (context, snap) => AsyncStateView<List<GroupEvent>>(
            snapshot: snap,
            onRetry: () => setState(_listen),
            isEmpty: (list) => list.isEmpty,
            emptyIcon: Icons.history,
            emptyMessage:
                'No activity yet. Expenses, payments and reminders '
                'will show up here.',
            builder: (all) {
              final list = _visible(all);
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Nothing matches.',
                      style: TextStyle(color: muted),
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, e) in list.indexed) ...[
                    if (i == 0 ||
                        dayLabel(e.event.createdAt) !=
                            dayLabel(list[i - 1].event.createdAt))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 0, 6),
                        child: Text(
                          dayLabel(e.event.createdAt),
                          style: AppText.section,
                        ),
                      ),
                    _EventTile(e, showGroup: widget.groupId == null),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// "Today", "Yesterday", or "Oct 12" ("Just now" for events still being
/// saved, which have no server time yet).
String dayLabel(DateTime? t, {DateTime? now}) {
  if (t == null) return 'Today';
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(t);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final label = '${months[day.month - 1]} ${day.day}';
  return day.year == today.year ? label : '$label, ${day.year}';
}

/// "9:41 AM".
String timeLabel(DateTime? t) {
  if (t == null) return 'Just now';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} '
      '${t.hour < 12 ? 'AM' : 'PM'}';
}

class _EventTile extends StatelessWidget {
  const _EventTile(this.item, {required this.showGroup});

  final GroupEvent item;
  final bool showGroup;

  static IconData _icon(String type) => switch (type) {
    'expense' => Icons.receipt_long_outlined,
    'payment' => Icons.account_balance_wallet_outlined,
    'confirm' => Icons.check_circle,
    'reminder' => Icons.notifications_outlined,
    'edit' => Icons.edit_outlined,
    'flag' => Icons.flag_outlined,
    'join' => Icons.person_add_alt_1_outlined,
    _ => Icons.history,
  };

  @override
  Widget build(BuildContext context) {
    final e = item.event;
    final when = timeLabel(e.createdAt);
    return Box(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: mint,
            child: Icon(_icon(e.type), color: green, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.text,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  showGroup ? '${item.group.name} · $when' : when,
                  style: AppText.caption,
                ),
                // Edits: show the price change, e.g. ₱420.00 → ₱450.00.
                if (e.oldCents != null && e.newCents != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MoneyChip(e.oldCents!, old: true),
                      const Icon(Icons.arrow_forward, size: 14, color: muted),
                      _MoneyChip(e.newCents!),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (e.amountCents != null && e.oldCents == null)
            Text(
              formatMoney(e.amountCents!),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
        ],
      ),
    );
  }
}

class _MoneyChip extends StatelessWidget {
  const _MoneyChip(this.cents, {this.old = false});

  final int cents;
  final bool old;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: old ? background : paidBg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      formatMoney(cents),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: old ? muted : paidFg,
        decoration: old ? TextDecoration.lineThrough : null,
      ),
    ),
  );
}
