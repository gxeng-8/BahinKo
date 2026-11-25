/// Privacy and trust information (RA 10173).
library;

import 'package:flutter/material.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/box.dart';
import 'package:bahinko/widgets/pill.dart';

class Privacy extends StatelessWidget {
  const Privacy({super.key});
  @override
  Widget build(BuildContext context) {
    const rows = [
      (
        Icons.shield_outlined,
        'Clear privacy policy',
        'See what we collect, why we collect it, and how long we keep it.',
      ),
      (
        Icons.lock_outline,
        'Encrypted data',
        'Your expense history and receipts are encrypted in storage and in transit.',
      ),
      (
        Icons.credit_card,
        'We never hold your money',
        'Payments open GCash or Maya with the amount prefilled. You confirm there.',
      ),
      (
        Icons.delete_outline,
        'You control your receipts',
        'Receipt photos are only used to read items. Delete them anytime or set auto-delete.',
      ),
    ];
    return AppPage(
      'Privacy and Trust',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows)
            Box(
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: mint,
                  child: Icon(r.$1, color: green),
                ),
                title: Text(
                  r.$2,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(r.$3, style: const TextStyle(fontSize: 12)),
              ),
            ),
          const Pill('GCash / Maya payment redirect', bg: lime, fg: deep),
        ],
      ),
    );
  }
}
