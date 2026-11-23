/// Track who has paid and record payments.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/receipt_line_item.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/utils/split_calculator.dart';
import 'package:bahinko/screens/settle/widgets/payment_dialogs.dart';
import 'package:bahinko/screens/settle/widgets/payment_proof_dialog.dart';
import 'package:bahinko/screens/settle/widgets/reminder_sheet.dart';
import 'package:bahinko/screens/settings/privacy_screen.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/box.dart';
import 'package:bahinko/widgets/btn.dart';
import 'package:bahinko/widgets/pill.dart';

class SettleUp extends StatefulWidget {
  const SettleUp({
    super.key,
    this.receiptItems,
    this.storeName = 'Samgyup House',
  });

  final List<ReceiptLineItem>? receiptItems;
  final String storeName;

  @override
  State<SettleUp> createState() => _SettleUpState();
}

class _SettleUpState extends State<SettleUp> {
  final Set<Person> _paidMembers = {};

  @override
  Widget build(BuildContext context) => AppPage(
    'Settle Up',
    ValueListenableBuilder<List<Person>>(
      valueListenable: groupMembers,
      builder: (context, currentMembers, _) {
        final displayItems = widget.receiptItems ?? items;
        final total = displayItems.fold<int>(
          0,
          (sum, item) => sum + item.amountInCents,
        );
        final memberShares = calculateMemberShares(
          total,
          currentMembers.length,
          useSampleShares: widget.receiptItems == null,
        );
        final payerIndex = currentMembers.indexWhere(
          (member) => member.pay == 'Paid the bill',
        );
        final payer = payerIndex < 0 ? null : currentMembers[payerIndex];
        final transferCount = payer == null ? 0 : currentMembers.length - 1;

        return Column(
          children: [
            Box(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.storeName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${currentMembers.length} people'),
                      Text('${displayItems.length} items'),
                      Text(
                        formatCurrency(total),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    payer == null
                        ? 'No bill payer is set for this split.'
                        : '$transferCount payments to ${payer.name}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            if (payer == null)
              const Box(
                Text(
                  'Set a member as the bill payer to calculate settlements.',
                ),
              )
            else
              for (var i = 0; i < currentMembers.length; i++)
                if (i != payerIndex)
                  _settlementCard(
                    context,
                    member: currentMembers[i],
                    payer: payer,
                    amountInCents: memberShares[i],
                    memberIndex: i,
                  ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Payments happen outside BahinKo. Mark a person paid after confirming the transfer.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            TextButton(
              onPressed: () => go(context, const Privacy()),
              child: const Text('How we protect your data ›'),
            ),
          ],
        );
      },
    ),
    bottom: Btn('Done', () => Navigator.popUntil(context, (r) => r.isFirst)),
  );

  Widget _settlementCard(
    BuildContext context, {
    required Person member,
    required Person payer,
    required int amountInCents,
    required int memberIndex,
  }) {
    final isPaid = _paidMembers.contains(member);
    return Box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${member.name} pays ${payer.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                formatCurrency(amountInCents),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isPaid)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: ValueKey('settle-payment-gcash-$memberIndex'),
                      style: FilledButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: amountInCents == 0
                          ? null
                          : () => _openPayment(
                              context,
                              member,
                              payer,
                              amountInCents,
                              'GCash',
                            ),
                      child: const Text('Pay with GCash'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: ValueKey('settle-payment-maya-$memberIndex'),
                      onPressed: amountInCents == 0
                          ? null
                          : () => _openPayment(
                              context,
                              member,
                              payer,
                              amountInCents,
                              'Maya',
                            ),
                      child: const Text('Pay with Maya'),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Pill(
                  isPaid ? 'Paid' : 'Pending',
                  bg: isPaid ? mint : const Color(0xFFFFF3D6),
                  fg: isPaid ? green : const Color(0xFFB7791F),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: ValueKey('settle-payment-$memberIndex'),
                  onPressed: amountInCents == 0
                      ? null
                      : () => isPaid
                            ? setState(() => _paidMembers.remove(member))
                            : setState(() => _paidMembers.add(member)),
                  child: Text(isPaid ? 'Undo' : 'Pay with Cash'),
                ),
              ),
            ],
          ),
          if (!isPaid) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: ValueKey('send-reminder-$memberIndex'),
                onPressed: () =>
                    _openReminder(context, member, payer, amountInCents),
                icon: const Icon(Icons.notifications_outlined, size: 18),
                label: const Text('Send reminder'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openPayment(
    BuildContext context,
    Person member,
    Person payer,
    int amountInCents,
    String provider,
  ) async {
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentOpeningDialog(
        provider: provider,
        member: member,
        payer: payer,
        amountInCents: amountInCents,
      ),
    );

    if (completed != true || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => PaymentConfirmationDialog(
        provider: provider,
        amountInCents: amountInCents,
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentProofDialog(
        member: member,
        payer: payer,
        provider: provider,
        amountInCents: amountInCents,
      ),
    );

    if (submitted == true) {
      setState(() => _paidMembers.add(member));
    }
  }

  Future<void> _openReminder(
    BuildContext context,
    Person member,
    Person payer,
    int amountInCents,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ReminderSheet(
        member: member,
        payer: payer,
        amountInCents: amountInCents,
      ),
    );
  }
}
