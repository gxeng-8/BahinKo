/// "Add Recurring Bill" form (Figma 17): name, amount, due day, and
/// whether the amount changes each month (like electricity).
///
/// Validated with a Form; returns the new [RecurringBill], or null if
/// cancelled. The screen saves it to the group.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bahinko/models/recurring_bill.dart';
import 'package:bahinko/utils/currency.dart';

class AddRecurringBillDialog extends StatefulWidget {
  const AddRecurringBillDialog({super.key});

  @override
  State<AddRecurringBillDialog> createState() => _AddRecurringBillDialogState();
}

class _AddRecurringBillDialogState extends State<AddRecurringBillDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _day = TextEditingController(text: '15');
  bool _varies = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final name = v?.trim() ?? '';
    if (name.isEmpty) return 'Enter a name, like Rent or WiFi';
    if (name.length > 40) return 'Keep it under 40 characters';
    return null;
  }

  String? _validateAmount(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Enter the amount';
    final cents = parsePesosToCents(v!);
    if (cents == null) return 'Use numbers only, like 1400';
    if (cents <= 0) return 'Must be more than ₱0';
    if (cents > 100000000) return 'That looks too big';
    return null;
  }

  String? _validateDay(String? v) {
    final day = int.tryParse(v?.trim() ?? '');
    if (day == null || day < 1 || day > 31) return 'A day from 1 to 31';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      RecurringBill.create(
        name: _name.text,
        amountCents: parsePesosToCents(_amount.text)!,
        dayOfMonth: int.parse(_day.text.trim()),
        varies: _varies,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add Recurring Bill'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('recurring-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Boarding House Rent',
              ),
              validator: _validateName,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('recurring-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: _varies ? 'Usual amount' : 'Amount',
                prefixText: '₱ ',
              ),
              validator: _validateAmount,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('recurring-day'),
              controller: _day,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Due every month on day',
                helperText: 'Short months use their last day',
              ),
              validator: _validateDay,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Amount changes each month'),
              subtitle: const Text('Like electricity or water'),
              value: _varies,
              onChanged: (v) => setState(() => _varies = v),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('recurring-save'),
        onPressed: _submit,
        child: const Text('Save'),
      ),
    ],
  );
}
