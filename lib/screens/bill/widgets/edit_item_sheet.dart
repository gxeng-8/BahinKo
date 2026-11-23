/// Figma Frame 10 "Edit item": bottom sheet to fix a receipt line.
///
/// RESPONSIBLE AI (course requirement d): users can correct or remove
/// anything the AI produced, or flag it. Saving clears "Needs review"
/// unless the user flags it.
///
/// Returns an [ItemEdit] (changed item, or deleted), or null if cancelled.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/models/expense.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/widgets/btn.dart';

/// What the user did in the sheet.
class ItemEdit {
  const ItemEdit.changed(ExpenseItem this.item) : deleted = false;
  const ItemEdit.deleted() : item = null, deleted = true;

  final ExpenseItem? item;
  final bool deleted;
}

/// Opens the sheet. Pass null [item] to add a new line the AI missed.
Future<ItemEdit?> showEditItemSheet(BuildContext context, ExpenseItem? item) =>
    showModalBottomSheet<ItemEdit>(
      context: context,
      isScrollControlled: true, // lets the sheet move up with the keyboard
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _EditItemSheet(item: item),
    );

class _EditItemSheet extends StatefulWidget {
  const _EditItemSheet({required this.item});

  final ExpenseItem? item;

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _price = TextEditingController(
    text: widget.item == null
        ? ''
        : (widget.item!.amountCents / 100).toStringAsFixed(2),
  );
  late bool _flagged = widget.item?.needsReview ?? false;

  bool get _isNew => widget.item == null;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  String? _validatePrice(String? value) {
    final cents = parsePesosToCents(value ?? '');
    if ((value ?? '').trim().isEmpty) return 'Enter the price';
    if (cents == null) return 'Use numbers only, like 450.00';
    if (cents <= 0) return 'Price must be more than ₱0';
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      ItemEdit.changed(
        ExpenseItem(
          name: _name.text.trim(),
          amountCents: parsePesosToCents(_price.text)!,
          assignedTo: widget.item?.assignedTo ?? const [],
          // Still counts as AI-found, but the user has now checked it.
          aiGenerated: widget.item?.aiGenerated ?? false,
          needsReview: _flagged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    // Push the sheet above the on-screen keyboard.
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.of(context).viewInsets.bottom + 20,
    ),
    child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isNew ? 'Add item' : 'Edit item', style: AppText.title),
          if (widget.item?.aiGenerated == true) ...[
            const SizedBox(height: 4),
            const Text(
              'Found by AI: check it against your receipt.',
              style: AppText.caption,
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('edit-item-name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Item name'),
            validator: (v) {
              final name = v?.trim() ?? '';
              if (name.isEmpty) return 'Enter the item name';
              if (name.length > 40) return 'Keep it under 40 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('edit-item-price'),
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price (check the receipt)',
              prefixText: '₱ ',
            ),
            validator: _validatePrice,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _flagged,
            activeThumbColor: errorFg,
            onChanged: (v) => setState(() => _flagged = v),
            title: const Text(
              'Flag this item',
              style: TextStyle(color: errorFg, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Keep it marked "Needs review" so the group double-checks it.',
              style: AppText.caption,
            ),
          ),
          const SizedBox(height: 8),
          Btn('Save', _save),
          if (!_isNew)
            Center(
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.pop(context, const ItemEdit.deleted()),
                icon: const Icon(Icons.delete_outline, color: errorFg),
                label: const Text(
                  'Remove item',
                  style: TextStyle(color: errorFg),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
