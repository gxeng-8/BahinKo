/// Entry point for scanning or typing in a receipt.
library;

import 'package:flutter/material.dart';
import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/screens/scan/camera_capture_screen.dart';
import 'package:bahinko/screens/bill/manual_receipt_entry_screen.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/box.dart';
import 'package:bahinko/widgets/btn.dart';

class ScanReceipt extends StatelessWidget {
  const ScanReceipt({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    'Scan Receipt',
    Column(
      children: [
        Box(
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: mint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SAMGYUP HOUSE',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final i in items)
                      Text(
                        '${i.name}   ${formatCurrency(i.amountInCents)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    Text(
                      'TOTAL   ${formatCurrency(items.fold<int>(0, (sum, item) => sum + item.amountInCents))}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Point your camera at the receipt. Items are listed for you.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Btn('Scan Receipt', () => go(context, const CameraCapture())),
            ],
          ),
        ),
        const Text('or'),
        const SizedBox(height: 8),
        Btn(
          'Enter manually',
          () => go(context, const ManualReceiptEntry()),
          outlined: true,
        ),
        const SizedBox(height: 16),
        const Box(
          color: lime,
          Text('Receipts are processed securely. You can delete them anytime.'),
        ),
      ],
    ),
  );
}
