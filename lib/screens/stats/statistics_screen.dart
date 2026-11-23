/// Spending statistics and charts.
library;

import 'package:flutter/material.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/screens/history/personal_ledger_screen.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/widgets/box.dart';
import 'package:bahinko/widgets/btn.dart';

class Statistics extends StatelessWidget {
  const Statistics({super.key});
  @override
  Widget build(BuildContext context) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
    const paid = <double>[30, 50, 70, 25, 15, 45, 55];
    const owed = <double>[55, 110, 80, 60, 75, 70, 65];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Statistics',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Total owed to you'),
            const Text(
              '₱4,820.00',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: deep,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Overview',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            // Simple bar chart. Swap for fl_chart later if you want.
            Box(
              SizedBox(
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var i = 0; i < months.length; i++)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                width: 10,
                                height: paid[i],
                                color: green,
                              ),
                              const SizedBox(width: 2),
                              Container(
                                width: 10,
                                height: owed[i],
                                color: const Color(0xFF5ED38A),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(months[i], style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _stat(
                    'Collected',
                    '₱4,820',
                    deep,
                    Icons.arrow_downward,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _stat('Paid out', '₱3,150', green, Icons.arrow_upward),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Box(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spending by category',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  for (final category in const [
                    ('Dining', 48, green),
                    ('Other', 30, deep),
                    ('Shopping', 22, orange),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              category.$1,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: category.$2 / 100,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(8),
                              color: category.$3,
                              backgroundColor: mint,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${category.$2}%'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Btn(
              'Open Personal Ledger',
              () => go(context, const PersonalLedger()),
              outlined: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String l, String v, Color c, IconData i) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: c,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.white,
          child: Icon(i, size: 16, color: c),
        ),
        const SizedBox(height: 24),
        Text(l, style: const TextStyle(color: Colors.white70)),
        Text(
          v,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}
