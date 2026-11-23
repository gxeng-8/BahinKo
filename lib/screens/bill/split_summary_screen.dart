/// Breakdown of how much each member owes.
library;

import 'package:flutter/material.dart';
import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/receipt_line_item.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/utils/split_calculator.dart';
import 'package:bahinko/screens/settle/settle_up_screen.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/widgets/avatar.dart';
import 'package:bahinko/widgets/btn.dart';

class SplitSummary extends StatelessWidget {
  const SplitSummary({
    super.key,
    this.receiptItems,
    this.storeName = 'Samgyup House',
  });

  final List<ReceiptLineItem>? receiptItems;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final displayItems = receiptItems ?? items;
    final currentMembers = groupMembers.value;
    final numberOfPeople = currentMembers.length;
    final total = displayItems.fold<int>(
      0,
      (sum, item) => sum + item.amountInCents,
    );
    final memberShares = calculateMemberShares(
      total,
      numberOfPeople,
      useSampleShares: receiptItems == null,
    );
    String formatAmount(int amountInCents) {
      final pesos = amountInCents ~/ 100;
      final centavos = amountInCents % 100;
      final pesosText = pesos.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );
      return centavos == 0
          ? '₱$pesosText'
          : '₱$pesosText.${centavos.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 178,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF159B82), Color(0xFF087D69)],
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '6  Split Summary',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.chevron_left_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Text(
                                  'Split Summary',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: IconButton(
                                  onPressed: () {},
                                  icon: const Icon(
                                    Icons.share_outlined,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 132, 16, 16),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Text(
                                storeName,
                                style: const TextStyle(
                                  color: Color(0xFF202523),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                receiptItems == null
                                    ? 'Oct 20, 2026 · $numberOfPeople people'
                                    : '$numberOfPeople people sharing',
                                style: const TextStyle(
                                  color: Color(0xFF8A9390),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFE7ECE9)),
                        const SizedBox(height: 12),
                        for (final item in displayItems)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(
                                      color: Color(0xFF7B8581),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  formatAmount(item.amountInCents),
                                  style: const TextStyle(
                                    color: Color(0xFF202523),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 2),
                        const Divider(height: 1, color: Color(0xFFE7ECE9)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                color: Color(0xFF202523),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              formatAmount(total),
                              style: const TextStyle(
                                color: green,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Each person pays',
                          style: TextStyle(
                            color: Color(0xFF202523),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (var i = 0; i < currentMembers.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Avatar(currentMembers[i], size: 32),
                                const SizedBox(width: 10),
                                Text(
                                  currentMembers[i].name,
                                  style: const TextStyle(
                                    color: Color(0xFF202523),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  formatAmount(memberShares[i]),
                                  style: const TextStyle(
                                    color: Color(0xFF202523),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: const Color(0xFFF8FAF9),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Btn(
                    'Settle Up',
                    () => go(
                      context,
                      SettleUp(
                        receiptItems: receiptItems,
                        storeName: storeName,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Btn('Download report', () {}, outlined: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
