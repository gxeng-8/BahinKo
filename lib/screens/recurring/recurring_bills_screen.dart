/// List of recurring bills (rent, Wi-Fi, etc.).
library;

import 'package:flutter/material.dart';
import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/recurring_bill.dart';
import 'package:bahinko/screens/recurring/widgets/add_recurring_bill_dialog.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/avatar.dart';
import 'package:bahinko/widgets/box.dart';
import 'package:bahinko/widgets/btn.dart';

class RecurringBills extends StatefulWidget {
  const RecurringBills({super.key});

  @override
  State<RecurringBills> createState() => _RecurringBillsState();
}

class _RecurringBillsState extends State<RecurringBills> {
  final List<RecurringBill> _bills = [
    RecurringBill('Boarding House Bills', 'Every month', '₱2,000', true),
    RecurringBill('Electricity', 'Due Oct 15', '₱1,400', true),
    RecurringBill('WiFi', 'Due Oct 20', '₱400', false),
  ];

  void _addBill(String name, String amount, String day) {
    setState(() {
      _bills.insert(0, RecurringBill(name, 'Due $day', amount, true));
    });
  }

  @override
  Widget build(BuildContext context) => AppPage(
    'Recurring Bills',
    Column(
      children: [
        Box(
          color: const Color(0xFF74E4A7),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recurring Bills',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '₱2,000 monthly · 4 members',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              for (final person in people.take(4))
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Avatar(person, size: 28),
                ),
            ],
          ),
        ),
        for (var i = 0; i < _bills.length; i++)
          Box(
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: mint,
                child: Icon(
                  i == 0
                      ? Icons.home_outlined
                      : i == 1
                      ? Icons.bolt_outlined
                      : Icons.wifi,
                  color: green,
                ),
              ),
              title: Text(
                _bills[i].name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(_bills[i].schedule),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _bills[i].amount,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: _bills[i].enabled,
                    onChanged: (value) =>
                        setState(() => _bills[i].enabled = value),
                  ),
                ],
              ),
            ),
          ),
        Box(
          color: lime,
          const Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: green),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reminders are 1–3 days before the due date',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    bottom: Btn(
      '+ Add recurring bill',
      () => showDialog<void>(
        context: context,
        builder: (_) => AddRecurringBillDialog(onAdd: _addBill),
      ),
    ),
  );
}
