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
///
/// Confirm Split SAVES the expense to the chosen group (Firestore): the
/// total is split equally among the group's members and owed to whoever
/// paid. Then Split Summary shows it, and Settle Up uses it for balances.
/// "Split another way" hands the items to Add Expense (Frame 6) to split
/// them by item, exact amounts, percent or shares instead.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/receipt_line_item.dart';
import 'package:bahinko/screens/bill/add_expense_screen.dart';
import 'package:bahinko/screens/bill/split_summary_screen.dart';
import 'package:bahinko/screens/bill/widgets/edit_item_sheet.dart';
import 'package:bahinko/screens/bill/widgets/payer_picker.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/services/receipt_scanner.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/settle_calculator.dart';
import 'package:bahinko/utils/split_calculator.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/app_toast.dart';
import 'package:bahinko/widgets/async_state_view.dart';
import 'package:bahinko/widgets/btn.dart';
import 'package:bahinko/widgets/info_banner.dart';
import 'package:bahinko/widgets/pill.dart';

class AssignItems extends StatefulWidget {
  const AssignItems({
    super.key,
    this.receiptItems,
    this.scan,
    this.groupId,
    this.storeName = 'Samgyup House',
  });

  /// Items typed in manually.
  final List<ReceiptLineItem>? receiptItems;

  /// Items found by the receipt scanner.
  final ScanResult? scan;

  /// The group to save into (from Group Detail). If null, the user picks.
  final String? groupId;
  final String storeName;

  @override
  State<AssignItems> createState() => _AssignItemsState();
}

class _AssignItemsState extends State<AssignItems> {
  /// The working list. Edits in the sheet change this copy.
  late List<ExpenseItem> _items;

  /// The user's groups, live (created once in initState).
  late final Stream<List<Group>> _groups;

  /// Chosen group and payer (null until the groups have loaded).
  String? _groupId;
  String? _payerId;

  /// True while saving (disables the button, shows "Saving…").
  bool _saving = false;

  bool get _fromScan => widget.scan != null;
  bool get _manual => widget.receiptItems != null;
  String get _store => widget.scan?.storeName ?? widget.storeName;

  @override
  void initState() {
    super.initState();
    _groups = GroupService.instance.watchMyGroups();
    _groupId = widget.groupId;
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

  /// Saves the expense, then opens its Split Summary. If items still need
  /// review, asks first: the user decides, not the AI.
  Future<void> _confirm(Group group) async {
    if (_items.isEmpty) {
      showAppToast(context, 'Add at least one item to split.');
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

    final payer = group.memberById(_payerId ?? '') ?? group.members.first;
    final memberIds = [
      for (final m in group.members)
        if (m.id.isNotEmpty) m.id,
    ];
    final expense = GroupExpense.create(
      title: _store,
      paidById: payer.id,
      paidByName: payer.name,
      amountCents: _total,
      // Everyone shares every item equally (exact amounts add up to total).
      shares: splitEqually(_total, memberIds),
      items: _items,
      category: group.category.name,
      source: widget.scan?.source == ScanSource.ai ? 'ai' : 'manual',
    );

    setState(() => _saving = true);
    try {
      final expenseId = await GroupService.instance.addExpense(
        group.id,
        expense,
      );
      if (!mounted) return;
      // Replace the whole scan/entry flow with the saved expense, so Back
      // goes home instead of to a finished form.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => SplitSummary(groupId: group.id, expenseId: expenseId),
        ),
        (route) => route.isFirst,
      );
      showAppToast(context, 'Saved to ${group.name}');
    } on GroupFailure catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(context, e.message); // error state
    }
  }

  /// Opens Add Expense with these items, in "By item" mode.
  void _splitAnotherWay() => Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => AddExpense(
        groupId: widget.groupId,
        title: _store,
        items: _items,
        source: widget.scan?.source == ScanSource.ai ? 'ai' : 'manual',
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Group>>(
    stream: _groups,
    builder: (context, snapshot) {
      final groups = snapshot.data ?? const <Group>[];
      // Pick the group: the one we came from, else the newest one.
      final group = groups.isEmpty
          ? null
          : groups.firstWhere(
              (g) => g.id == _groupId,
              orElse: () => groups.first,
            );
      if (group != null && group.memberById(_payerId ?? '') == null) {
        // Default payer: me, if I'm in the group; else the first member.
        final me = group.memberById(GroupService.instance.myId);
        _payerId = (me ?? group.members.first).id;
      }
      return _page(context, snapshot, group, groups);
    },
  );

  Widget _page(
    BuildContext context,
    AsyncSnapshot<List<Group>> snapshot,
    Group? group,
    List<Group> groups,
  ) {
    final people = group?.members.length ?? 0;
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
          const SizedBox(height: 8),
          // Which group, and who paid: loading / empty / error states.
          AsyncStateView<List<Group>>(
            snapshot: snapshot,
            compact: true,
            isEmpty: (list) => list.isEmpty,
            emptyIcon: Icons.groups_outlined,
            emptyMessage: 'Create or join a group first, then split this bill.',
            builder: (_) => _GroupAndPayer(
              groups: groups,
              group: group!,
              payerId: _payerId!,
              fixedGroup: widget.groupId != null,
              onGroup: (id) => setState(() {
                _groupId = id;
                _payerId = null; // re-pick the payer for the new group
              }),
              onPayer: (id) => setState(() => _payerId = id),
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
          Row(
            children: [
              Expanded(
                child: Btn(
                  'Split another way',
                  _items.isEmpty || _saving ? null : _splitAnotherWay,
                  outlined: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Btn(
                  _saving ? 'Saving…' : 'Confirm Split',
                  group == null || _saving ? null : () => _confirm(group),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Group" dropdown + "Paid by" avatars.
class _GroupAndPayer extends StatelessWidget {
  const _GroupAndPayer({
    required this.groups,
    required this.group,
    required this.payerId,
    required this.fixedGroup,
    required this.onGroup,
    required this.onPayer,
  });

  final List<Group> groups;
  final Group group;
  final String payerId;

  /// True when opened from a group: no need to choose.
  final bool fixedGroup;
  final ValueChanged<String> onGroup;
  final ValueChanged<String> onPayer;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Split in', style: AppText.section),
        const SizedBox(height: 6),
        if (fixedGroup)
          Text(group.name)
        else
          DropdownButtonFormField<String>(
            key: const ValueKey('split-group'),
            initialValue: group.id,
            isExpanded: true,
            items: [
              for (final g in groups)
                DropdownMenuItem(value: g.id, child: Text(g.name)),
            ],
            onChanged: (id) => onGroup(id!),
          ),
        const SizedBox(height: 12),
        Text('Paid by', style: AppText.section),
        const SizedBox(height: 8),
        PayerPicker(
          members: group.members,
          payerId: payerId,
          onChanged: onPayer,
        ),
        const SizedBox(height: 6),
        Text(
          'Split equally among ${group.members.length} members. '
          'Tap "Split another way" to split by item, amount, percent or shares.',
          style: AppText.caption,
        ),
      ],
    ),
  );
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
