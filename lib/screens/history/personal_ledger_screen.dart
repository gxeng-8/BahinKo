/// Per-person ledger of what you owe and are owed.
library;

import 'package:flutter/material.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/box.dart';

class PersonalLedger extends StatelessWidget {
  const PersonalLedger({super.key});

  @override
  Widget build(BuildContext context) => AppPage(
    'Personal Ledger',
    Column(
      children: [
        Box(
          color: deep,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Balance',
                style: TextStyle(color: Colors.white70),
              ),
              const Text(
                '₱710.00',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ledgerBalance(
                      'Owed to you',
                      '₱1,950',
                      const Color(0xFF74E4A7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ledgerBalance(
                      'You owe',
                      '₱1,240',
                      const Color(0xFFFFF3D6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        for (final row in const [
          ('Owes you', 'Ana', '+₱350', green),
          ('Owes you', 'Jun', '+₱220', green),
          ('You owe', 'Leo', '-₱430', orange),
          ('You owe', 'Mia', '-₱180', orange),
        ])
          Box(
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: mint,
                child: Text(
                  row.$2.substring(0, 1),
                  style: const TextStyle(
                    color: green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(row.$2),
              subtitle: Text(row.$1),
              trailing: Text(
                row.$3,
                style: TextStyle(color: row.$4, fontWeight: FontWeight.w900),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _ledgerBalance(String label, String amount, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}
