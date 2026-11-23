/// Figma Frame 9 "Assign Items": the receipt's items, ready to split.
///
/// Items come from one of three places:
/// * [scan]: the AI scanner (labeled "AI-detected"; shaky items get an
///   orange border + "Needs review"),
/// * [receiptItems]: typed in on the manual entry screen,
/// * neither: the sample receipt (demo).
///
/// Every item can be edited, removed, or flagged, and missed items can be
/// added (Edit Item sheet, Frame 10), so users always have the final say
/// over what the AI found.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/expense.dart';
import 'package:bahinko/models/receipt_line_item.dart';
import 'package:bahinko/screens/bill/split_summary_screen.dart';
import 'package:bahinko/screens/bill/widgets/edit_item_sheet.dart';
import 'package:bahinko/services/receipt_scanner.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/utils/split_calculator.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/btn.dart';
import 'package:bahinko/widgets/info_banner.dart';
import 'package:bahinko/widgets/pill.dart';

class AssignItems extends StatefulWidget {
  const AssignItems({
    super.key,
    this.receiptItems,
    this.scan,
    this.storeName = 'Samgyup House',
  });

  /// Items typed in manually.
  final List<ReceiptLineItem>? receiptItems;

  /// Items found by the receipt scanner.
  final ScanResult? scan;
  final String storeName;

  @override
  State<AssignItems> createState() => _AssignItemsState();
}

class _AssignItemsState extends State<AssignItems> {
  /// The working list. Edits in the sheet change this copy.
  late List<ExpenseItem> _items;

  bool get _fromScan => widget.scan != null;
  bool get _manual => widget.receiptItems != null;
  String get _store => widget.scan?.storeName ?? widget.storeName;

  @override
  void initState() {
    super.initState();
    _items =
        widget.scan?.items.toList() ??
        [
          for (final i in widget.receiptItems ?? items)
            ExpenseItem(name: i.name, amountCents: i.amountInCents),
        ];
  }

  int get _total => _items.fold(0, (sum, i) => sum + i.amountCents);
  int get _needsReview => _items.where((i) => i.needsReview).length;

  /// Opens the Edit Item sheet for item [index] (or a new item if null).
  Future<void> _edit(int? index) async {
    final result = await showEditItemSheet(
      context,
      index == null ? null : _items[index],
    );
    if (result == null) return; // cancelled
    setState(() {
      if (result.deleted) {
        _items.removeAt(index!);
      } else if (index == null) {
        _items.add(result.item!);
      } else {
        _items[index] = result.item!;
      }
    });
  }

  /// Goes to the split summary. If items still need review, asks first:
  /// the user decides, not the AI.
  Future<void> _confirm() async {
    if (_items.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (_) =>
            const AlertDialog(content: Text('Add at least one item to split.')),
      );
      return;
    }
    if (_needsReview > 0) {
      final goOn = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Some items need review'),
          content: Text(
            '$_needsReview ${_needsReview == 1 ? 'item is' : 'items are'} '
            'marked "Needs review". Split anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Check items'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Split anyway'),
            ),
          ],
        ),
      );
      if (goOn != true || !mounted) return;
    }
    go(
      context,
      SplitSummary(
        receiptItems: [
          for (final i in _items) ReceiptLineItem(i.name, i.amountCents),
        ],
        storeName: _store,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final people = groupMembers.value.length;
    final warning = widget.scan?.warning;
    return AppPage(
      'Assign Items',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _manual
                      ? '${_items.length} items entered manually'
                      : 'Scanned ${_items.length} items from $_store',
                  style: AppText.caption,
                ),
              ),
              if (_fromScan) _SourcePill(widget.scan!.source),
              if (!_fromScan) Pill('$people people'),
            ],
          ),
          const SizedBox(height: 10),
          // Orange banner: why to double-check (AI warning or review count).
          if (warning != null || _needsReview > 0) ...[
            InfoBanner(
              _needsReview > 0 && warning == null
                  ? '$_needsReview needs review: tap any item to edit'
                  : warning ?? '',
              icon: Icons.warning_amber_rounded,
              color: unpaidBg,
            ),
            const SizedBox(height: 10),
          ],
          for (var i = 0; i < _items.length; i++)
            _ItemCard(number: i + 1, item: _items[i], onTap: () => _edit(i)),
          Center(
            child: TextButton.icon(
              onPressed: () => _edit(null),
              icon: const Icon(Icons.add, color: green),
              label: const Text(
                'Add item',
                style: TextStyle(color: green, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: AppText.caption),
              Text(formatCurrency(_total), style: AppText.money(22)),
            ],
          ),
          if (people > 0) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Each person pays', style: AppText.caption),
                Text(formatShareRange(_total, people)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Btn('Confirm Split', _confirm),
        ],
      ),
    );
  }
}

/// "AI-detected" (green) or "Basic detection" (orange) label.
class _SourcePill extends StatelessWidget {
  const _SourcePill(this.source);

  final ScanSource source;

  @override
  Widget build(BuildContext context) => source == ScanSource.ai
      ? const Pill('AI-detected', icon: Icons.auto_awesome)
      : const Pill.unpaid(text: 'Basic detection');
}

/// One numbered receipt line. Orange border + pill when it needs review.
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.number,
    required this.item,
    required this.onTap,
  });

  final int number;
  final ExpenseItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.needsReview ? unpaidFg : border,
              width: item.needsReview ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Text('$number', style: AppText.caption),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    item.needsReview
                        ? const Pill.needsReview()
                        : const Pill('Split equally'),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(item.amountCents),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.edit_outlined, size: 16, color: muted),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
