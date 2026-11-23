/// Form for typing receipt items by hand, with validation.
library;

import 'package:flutter/material.dart';
import 'package:bahinko/models/receipt_line_item.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/screens/bill/assign_items_screen.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/box.dart';
import 'package:bahinko/widgets/btn.dart';

class ManualReceiptEntry extends StatefulWidget {
  const ManualReceiptEntry({super.key});

  @override
  State<ManualReceiptEntry> createState() => _ManualReceiptEntryState();
}

class _ManualReceiptEntryState extends State<ManualReceiptEntry> {
  final _formKey = GlobalKey<FormState>();
  final _storeController = TextEditingController();
  final List<_ManualReceiptLine> _lines = [_ManualReceiptLine()];

  int get _total => _lines.fold(
    0,
    (total, line) => total + (parsePesosToCents(line.price.text) ?? 0),
  );

  @override
  void dispose() {
    _storeController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _addLine() => setState(() => _lines.add(_ManualReceiptLine()));

  void _removeLine(_ManualReceiptLine line) {
    if (_lines.length == 1) return;
    setState(() => _lines.remove(line));
    line.dispose();
  }

  void _continueToItems() {
    if (!_formKey.currentState!.validate()) return;

    final receiptItems = _lines
        .map(
          (line) => ReceiptLineItem(
            line.name.text.trim(),
            parsePesosToCents(line.price.text)!,
          ),
        )
        .toList();
    final storeName = _storeController.text.trim();
    go(
      context,
      AssignItems(
        receiptItems: receiptItems,
        storeName: storeName.isEmpty ? 'Manual Receipt' : storeName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppPage(
    'Enter Receipt',
    Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            key: const ValueKey('receipt-store-name'),
            controller: _storeController,
            decoration: const InputDecoration(
              labelText: 'Store or receipt name (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Items',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < _lines.length; index++)
            _buildItemFields(_lines[index], index),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _addLine,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
          ),
          const SizedBox(height: 12),
          Box(
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  formatCurrency(_total),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    bottom: Btn('Continue to items', _continueToItems),
  );

  Widget _buildItemFields(_ManualReceiptLine line, int index) => Padding(
    key: ObjectKey(line),
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            key: ValueKey('receipt-item-name-$index'),
            controller: line.name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Item name',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter an item name'
                : null,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: TextFormField(
            key: ValueKey('receipt-item-price-$index'),
            controller: line.price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price (₱)',
              helperText: 'Up to 2 decimal places',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter a price';
              }
              final amount = parsePesosToCents(value);
              if (amount == null) return 'Enter a valid price (max 2 decimals)';
              if (amount <= 0) return 'Must be over ₱0';
              return null;
            },
          ),
        ),
        IconButton(
          tooltip: 'Remove item',
          onPressed: _lines.length == 1 ? null : () => _removeLine(line),
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    ),
  );
}

class _ManualReceiptLine {
  final name = TextEditingController();
  final price = TextEditingController();

  void dispose() {
    name.dispose();
    price.dispose();
  }
}
