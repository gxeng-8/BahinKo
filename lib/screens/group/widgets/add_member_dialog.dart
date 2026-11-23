/// Validated form dialog for adding a member.
library;

import 'package:flutter/material.dart';

class AddMemberDialog extends StatefulWidget {
  const AddMemberDialog({super.key, required this.onAdd});

  final ValueChanged<String> onAdd;

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onAdd(_nameController.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add member'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        key: const ValueKey('new-member-name'),
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Member name',
          border: OutlineInputBorder(),
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Enter a member name'
            : null,
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('confirm-add-member'),
        onPressed: _submit,
        child: const Text('Add member'),
      ),
    ],
  );
}
