/// Validated form dialog for adding a recurring bill.
library;

import 'package:flutter/material.dart';

class AddRecurringBillDialog extends StatefulWidget {
  const AddRecurringBillDialog({super.key, required this.onAdd});

  final void Function(String name, String amount, String day) onAdd;

  @override
  State<AddRecurringBillDialog> createState() => _AddRecurringBillDialogState();
}

class _AddRecurringBillDialogState extends State<AddRecurringBillDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _dayController = TextEditingController(text: '15');
  bool _isMonthly = true;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final amount = _amountController.text.trim();
    if (name.isEmpty || amount.isEmpty) return;
    widget.onAdd(name, '₱$amount', _dayController.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add Recurring Bill'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('recurring-name'),
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Boarding House Bills',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('recurring-amount'),
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₱ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Monthly'),
            value: _isMonthly,
            onChanged: (value) => setState(() => _isMonthly = value),
          ),
          TextField(
            key: const ValueKey('recurring-day'),
            controller: _dayController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Due day',
              border: OutlineInputBorder(),
            ),
          ),
        ],
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
