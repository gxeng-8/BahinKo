/// Figma Frame 14 "Payment proof": after paying in GCash / Maya, type the
/// reference number from the app's receipt.
///
/// The reference is SAVED with the payment, so the receiver can match it
/// against their own GCash / Maya history before tapping Confirm.
/// Validated: 6–20 letters or digits (GCash uses 13 digits, Maya 12).
///
/// Returns the reference (spaces removed), or null if cancelled.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/models/person.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';

/// "1234 567 890 123" → "1234567890123"; null if it doesn't look like a
/// reference number.
String? normalizeReference(String input) {
  final ref = input.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  return RegExp(r'^[A-Z0-9]{6,20}$').hasMatch(ref) ? ref : null;
}

class PaymentProofDialog extends StatefulWidget {
  const PaymentProofDialog({
    super.key,
    required this.member,
    required this.payer,
    required this.provider,
    required this.amountInCents,
  });

  /// Who paid (you).
  final Person member;

  /// Who received it.
  final Person payer;
  final String provider;
  final int amountInCents;

  @override
  State<PaymentProofDialog> createState() => _PaymentProofDialogState();
}

class _PaymentProofDialogState extends State<PaymentProofDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reference = TextEditingController();
  bool _confirmedCorrect = false;

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, normalizeReference(_reference.text));
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add payment proof',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: mint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You paid ${widget.payer.name} via ${widget.provider}',
                    style: AppText.caption,
                  ),
                  Text(
                    formatMoney(widget.amountInCents),
                    style: AppText.money(24, color: deep),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('payment-proof-reference'),
              controller: _reference,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Reference no.',
                hintText: widget.provider == 'GCash'
                    ? '13 digits, e.g. 1009 876 543 210'
                    : 'From your ${widget.provider} receipt',
                helperText:
                    'Found on the ${widget.provider} receipt. '
                    '${widget.payer.name} uses it to check the payment.',
                helperMaxLines: 2,
              ),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) {
                  return 'Enter the reference number';
                }
                return normalizeReference(v!) == null
                    ? 'Use 6–20 letters or numbers'
                    : null;
              },
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const ValueKey('payment-proof-confirm'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _confirmedCorrect,
              onChanged: (value) =>
                  setState(() => _confirmedCorrect = value ?? false),
              title: const Text(
                'I sent this amount to the right person',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey('submit-payment-proof'),
                  onPressed: _confirmedCorrect ? _submit : null,
                  child: const Text('Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
