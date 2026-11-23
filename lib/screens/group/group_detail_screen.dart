/// Details of one group and its bills.
library;

import 'package:flutter/material.dart';
import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/screens/group/members_screen.dart';
import 'package:bahinko/screens/scan/scan_receipt_screen.dart';
import 'package:bahinko/screens/bill/split_summary_screen.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/avatar.dart';
import 'package:bahinko/widgets/box.dart';
import 'package:bahinko/widgets/btn.dart';
import 'package:bahinko/widgets/pill.dart';

class GroupDetail extends StatelessWidget {
  const GroupDetail({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    'Dinner at Jaro',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Box(
          color: green,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total spent', style: TextStyle(color: Colors.white70)),
              Text(
                '₱2,450',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Row(
                children: [
                  Pill('Paid by Mia', bg: lime, fg: deep),
                  SizedBox(width: 8),
                  Pill(
                    '2 unpaid',
                    bg: Color(0xFFFFF3D6),
                    fg: Color(0xFFB7791F),
                  ),
                ],
              ),
            ],
          ),
        ),
        Box(
          onTap: () => go(context, const Members()),
          ValueListenableBuilder<List<Person>>(
            valueListenable: groupMembers,
            builder: (context, currentMembers, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Members (${currentMembers.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final p in currentMembers)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Avatar(p),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Text('Expenses', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Box(
          onTap: () => go(context, const SplitSummary()),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: mint,
              child: Icon(Icons.coffee, color: green),
            ),
            title: Text('Samgyup Dinner'),
            subtitle: Text('Paid by Mia · split 5 ways'),
            trailing: Text(
              '₱2,450',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const Box(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: mint,
              child: Icon(Icons.coffee, color: green),
            ),
            title: Text('Milk Tea Run'),
            subtitle: Text('Paid by You · split 3 ways'),
            trailing: Text(
              '₱380',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const Box(
          Text('Activity history\nJun edited the price of Soju · 2h ago'),
        ),
      ],
    ),
    bottom: Btn('+ Add Expense', () => go(context, const ScanReceipt())),
  );
}
