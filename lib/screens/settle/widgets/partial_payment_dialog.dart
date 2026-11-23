/// "Pay part of it" / "Got part of it" on Settle Up: record a payment for
/// LESS than the full amount (e.g. ₱300 now, the rest after payday).
///
/// Balances already handle any amount: a partial payment just lowers the
/// debt, and Settle Up shows what's left. This dialog validates the amount
/// (more than ₱0, not more than what's owed) and picks the method.
///
/// Returns the amount and method, or null if cancelled.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';

typedef PartialPayment = ({int cents, String method});

Future<PartialPayment?> showPartialPaymentDialog(
  BuildContext context, {
  required String title,
  required String message,
  required int maxCents,

  /// Which methods to offer ('GCash', 'Maya', 'Cash'). Receiving money
  /// you were handed only offers 'Cash'.
  List<String> methods = const ['GCash', 'Maya', 'Cash'],
}) => showDialog<PartialPayment>(
  context: context,
  builder: (_) => _PartialPaymentDialog(
    title: title,
    message: message,
    maxCents: maxCents,
    methods: methods,
  ),
);

class _PartialPaymentDialog extends StatefulWidget {
  const _PartialPaymentDialog({
    required this.title,
    required this.message,
    required this.maxCents,
    required this.methods,
  });

  final String title, message;
  final int maxCents;
  final List<String> methods;

  @override
  State<_PartialPaymentDialog> createState() => _PartialPaymentDialogState();
}

class _PartialPaymentDialogState extends State<_PartialPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  late String _method = widget.methods.first;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String? _validate(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Enter how much';
    final cents = parsePesosToCents(v!);
    if (cents == null) return 'Use numbers only, like 300.00';
    if (cents <= 0) return 'Must be more than ₱0';
    if (cents > widget.maxCents) {
      return 'Only ${formatMoney(widget.maxCents)} is owed';
    }
    return null;
  }

  void _fill(int cents) => setState(
    () => _amount.text = cents % 100 == 0
        ? '${cents ~/ 100}'
        : (cents / 100).toStringAsFixed(2),
  );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (
      cents: parsePesosToCents(_amount.text)!,
      method: _method.toLowerCase(),
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: AppText.caption),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('partial-amount'),
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₱ ',
            ),
            validator: _validate,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Half'),
                onPressed: () => _fill(widget.maxCents ~/ 2),
              ),
              ActionChip(
                label: Text('All ${formatMoney(widget.maxCents)}'),
                onPressed: () => _fill(widget.maxCents),
              ),
            ],
          ),
          if (widget.methods.length > 1) ...[
            const SizedBox(height: 12),
            const Text('Paid with', style: AppText.caption),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final m in widget.methods)
                  ButtonSegment(value: m, label: Text(m)),
              ],
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: mint,
                selectedForegroundColor: deep,
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('partial-submit'),
        onPressed: _submit,
        style: FilledButton.styleFrom(backgroundColor: green),
        child: const Text('Record'),
      ),
    ],
  );
}
