/// Dialog for attaching proof of payment.
library;

import 'package:flutter/material.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/theme/app_colors.dart';

class PaymentProofDialog extends StatefulWidget {
  const PaymentProofDialog({
    super.key,
    required this.member,
    required this.payer,
    required this.provider,
    required this.amountInCents,
  });

  final Person member;
  final Person payer;
  final String provider;
  final int amountInCents;

  @override
  State<PaymentProofDialog> createState() => _PaymentProofDialogState();
}

class _PaymentProofDialogState extends State<PaymentProofDialog> {
  late final TextEditingController _amountController;
  final TextEditingController _referenceController = TextEditingController();
  bool _proofAttached = false;
  bool _confirmedCorrect = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: (formatCurrency(widget.amountInCents)).replaceFirst('₱', ''),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add payment proof',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('payment-proof-amount'),
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount paid',
              prefixText: '₱ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pay with ${widget.provider} (${widget.provider == 'GCash' ? '0998 000 7888' : '0921 456 7890'})',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          InkWell(
            key: const ValueKey('payment-proof-upload'),
            onTap: () => setState(() => _proofAttached = true),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF3FBF8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _proofAttached ? green : const Color(0xFF9DD6C6),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _proofAttached ? Icons.check_circle : Icons.image_outlined,
                    color: green,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _proofAttached
                        ? 'Payment screenshot attached'
                        : 'Attach payment proof',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('payment-proof-reference'),
            controller: _referenceController,
            decoration: const InputDecoration(
              labelText: 'Reference no.',
              hintText: 'Optional',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            key: const ValueKey('payment-proof-confirm'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _confirmedCorrect,
            onChanged: (value) =>
                setState(() => _confirmedCorrect = value ?? false),
            title: const Text(
              'I confirm that your payment is correct',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('submit-payment-proof'),
              onPressed: _proofAttached && _confirmedCorrect
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Submit'),
            ),
          ),
        ],
      ),
    ),
  );
}
