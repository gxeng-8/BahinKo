/// Assign each receipt item to the members who shared it.
library;

import 'package:flutter/material.dart';
import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/receipt_line_item.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/utils/split_calculator.dart';
import 'package:bahinko/screens/bill/split_summary_screen.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/avatar.dart';
import 'package:bahinko/widgets/box.dart';
import 'package:bahinko/widgets/btn.dart';
import 'package:bahinko/widgets/pill.dart';

class AssignItems extends StatelessWidget {
  const AssignItems({
    super.key,
    this.receiptItems,
    this.storeName = 'Samgyup House',
  });

  final List<ReceiptLineItem>? receiptItems;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final displayItems = receiptItems ?? items;
    final numberOfPeople = groupMembers.value.length;
    final total = displayItems.fold<int>(
      0,
      (sum, item) => sum + item.amountInCents,
    );

    // who ordered each item (indexes into `people`); empty list = split equally
    const who = [
      [0, 1, 2],
      <int>[],
      [2, 4],
      [1, 3],
      <int>[],
    ];
    return AppPage(
      'Assign Items',
      Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                receiptItems == null
                    ? 'Scanned ${displayItems.length} items'
                    : '${displayItems.length} items entered manually',
              ),
              if (receiptItems == null)
                const Pill(
                  '1 needs review',
                  bg: Color(0xFFFFF3D6),
                  fg: Color(0xFFB7791F),
                )
              else
                Pill('$numberOfPeople people'),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < displayItems.length; i++)
            Box(
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayItems[i].name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(formatCurrency(displayItems[i].amountInCents)),
                      ],
                    ),
                  ),
                  if (receiptItems != null)
                    const Pill('Split equally')
                  else if (who[i].isEmpty)
                    Pill(i == 1 ? 'All' : 'Split equally')
                  else
                    for (final p in who[i])
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Avatar(people[p], size: 30),
                      ),
                ],
              ),
            ),
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total'),
              Text(
                formatCurrency(total),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (receiptItems != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Each person pays'),
                Text(formatShareRange(total, numberOfPeople)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Btn(
            'Confirm Split',
            () => go(
              context,
              SplitSummary(receiptItems: receiptItems, storeName: storeName),
            ),
          ),
        ],
      ),
    );
  }
}
