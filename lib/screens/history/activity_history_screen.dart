/// Searchable and filterable history of past activity.
library;

import 'package:flutter/material.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/box.dart';

class ActivityHistory extends StatefulWidget {
  const ActivityHistory({super.key});

  @override
  State<ActivityHistory> createState() => _ActivityHistoryState();
}

class _ActivityHistoryState extends State<ActivityHistory> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    const activities = [
      (
        'Activity',
        'Ana paid',
        'Payment received · 10:35 AM',
        Icons.check_circle,
      ),
      (
        'Payments',
        'You paid ₱320 to Mia',
        'Payment recorded · 9:41 AM',
        Icons.account_balance_wallet_outlined,
      ),
      (
        'Reminders',
        'Reminder sent to Leo',
        'Due tomorrow · Yesterday',
        Icons.notifications_outlined,
      ),
      (
        'Reminders',
        'You sent reminder to Jun',
        'Friendly reminder · Yesterday',
        Icons.send_outlined,
      ),
      (
        'Activity',
        'Electricity Bill was added',
        'Boarding · Oct 12',
        Icons.bolt_outlined,
      ),
    ];
    final filtered = _filter == 'All'
        ? activities
        : activities.where((activity) => activity.$1 == _filter).toList();

    return AppPage(
      'Activity',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in [
                  'All',
                  'Payments',
                  'Reminders',
                  'Activity',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final activity in filtered)
            Box(
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: mint,
                  child: Icon(activity.$4, color: green, size: 20),
                ),
                title: Text(
                  activity.$2,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(activity.$3),
              ),
            ),
        ],
      ),
    );
  }
}
