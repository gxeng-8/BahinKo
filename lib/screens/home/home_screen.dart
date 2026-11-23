/// Home dashboard: balances, groups, and quick actions.
library;

import 'package:flutter/material.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/screens/group/group_detail_screen.dart';
import 'package:bahinko/screens/scan/scan_receipt_screen.dart';
import 'package:bahinko/screens/bill/assign_items_screen.dart';
import 'package:bahinko/screens/settle/settle_up_screen.dart';
import 'package:bahinko/screens/recurring/recurring_bills_screen.dart';
import 'package:bahinko/screens/history/personal_ledger_screen.dart';
import 'package:bahinko/screens/history/activity_history_screen.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/widgets/box.dart';
import 'package:bahinko/widgets/pill.dart';

class Home extends StatelessWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext context) {
    const cats = [
      ('Dinner', Icons.coffee),
      ('Boarding', Icons.home_outlined),
      ('Trips', Icons.explore_outlined),
      ('Utilities', Icons.bolt),
      ('Subscriptions', Icons.repeat),
      ('Groceries', Icons.shopping_cart_outlined),
      ('Bills', Icons.description_outlined),
      ('More', Icons.grid_view),
    ];
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF12A883), Color(0xFF056B52)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
            child: Column(
              children: [
                const Text(
                  'Net balance',
                  style: TextStyle(color: Colors.white70),
                ),
                const Text(
                  '₱920.00',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Pill('Owed to you ₱1,240', bg: lime, fg: deep),
                    const SizedBox(width: 8),
                    Pill(
                      'You owe ₱320',
                      bg: Colors.white,
                      fg: Colors.red.shade600,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Box(
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _action(
                        context,
                        Icons.qr_code_scanner,
                        'Scan',
                        const ScanReceipt(),
                      ),
                      _action(context, Icons.add, 'Add', const AssignItems()),
                      _action(
                        context,
                        Icons.credit_card,
                        'Settle Up',
                        const SettleUp(),
                      ),
                      _action(
                        context,
                        Icons.history,
                        'History',
                        const ActivityHistory(),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Group Categories',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final c in cats)
                      InkWell(
                        onTap: () {
                          if (c.$1 == 'Subscriptions') {
                            go(context, const RecurringBills());
                          } else if (c.$1 == 'Bills') {
                            go(context, const PersonalLedger());
                          }
                        },
                        child: Column(
                          children: [
                            CircleAvatar(
                              backgroundColor: mint,
                              child: Icon(c.$2, color: green),
                            ),
                            const SizedBox(height: 4),
                            Text(c.$1, style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                  ],
                ),
                const Text(
                  'Active Groups',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _group(
                        context,
                        'Dinner at Jaro',
                        '5 members · 2 unpaid',
                        '₱2,450',
                        green,
                        Colors.white,
                      ),
                      _group(
                        context,
                        'Boarding',
                        '4 members',
                        '₱3,800',
                        lime,
                        deep,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(BuildContext c, IconData i, String t, Widget to) => InkWell(
    onTap: () => go(c, to),
    child: Column(
      children: [
        CircleAvatar(
          backgroundColor: mint,
          child: Icon(i, color: green),
        ),
        const SizedBox(height: 4),
        Text(t, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );

  Widget _group(
    BuildContext c,
    String name,
    String sub,
    String amt,
    Color bg,
    Color fg,
  ) => GestureDetector(
    onTap: () => go(c, const GroupDetail()),
    child: Container(
      width: 240,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          Text(sub, style: TextStyle(color: fg.withAlpha(200), fontSize: 12)),
          const Spacer(),
          Text(
            amt,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
        ],
      ),
    ),
  );
}
