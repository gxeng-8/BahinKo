/// Figma Frame 6 "Add Expense": name, amount, who paid, date, category,
/// and how to split it: Equal · By item · Exact · Percent · Shares.
///
/// Form validation (course requirement): name and amount are checked by
/// the form; the split is checked live by [buildShares] (exact amounts must
/// add up to the total, percents to 100%, …) and shown under the split
/// list. Saving writes the expense to the group (Firestore), then opens its
/// Split Summary. The math lives in utils/split_modes.dart.
///
/// Opened from Group Detail / Home ("+ Add Expense"), or from Assign Items
/// with the scanned receipt's [items] to split them item by item.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/screens/bill/split_summary_screen.dart';
import 'package:bahinko/screens/bill/widgets/edit_item_sheet.dart';
import 'package:bahinko/screens/bill/widgets/payer_picker.dart';
import 'package:bahinko/screens/scan/scan_receipt_screen.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/utils/split_modes.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/app_toast.dart';
import 'package:bahinko/widgets/async_state_view.dart';
import 'package:bahinko/widgets/avatar.dart';
import 'package:bahinko/widgets/btn.dart';
import 'package:bahinko/widgets/pill.dart';

/// Biggest single expense we accept (₱10,000,000): catches typos.
const maxExpenseCents = 1000000000;

class AddExpense extends StatefulWidget {
  const AddExpense({
    super.key,
    this.groupId,
    this.title,
    this.items,
    this.source = 'manual',
  });

  /// The group to save into. If null, the user chooses one.
  final String? groupId;

  /// Pre-filled from a scanned receipt (store name + items): the form
  /// then starts in "By item" mode.
  final String? title;
  final List<ExpenseItem>? items;

  /// 'ai' if the items came from the AI scanner.
  final String source;

  @override
  State<AddExpense> createState() => _AddExpenseState();
}

class _AddExpenseState extends State<AddExpense> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.title ?? '');
  final _amount = TextEditingController();
  late final Stream<List<Group>> _groups;

  String? _groupId;
  String? _payerId;
  String? _category;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  late SplitMode _mode;
  bool _saving = false;

  /// True after the first Save tap: from then on, show split errors in red.
  bool _triedSave = false;

  // ---- Per-member split inputs (kept per member ID) ----
  final Set<String> _included = {}; // Equal
  final Map<String, TextEditingController> _exact = {}; // Exact (pesos)
  final Map<String, TextEditingController> _percent = {}; // Percent
  final Map<String, int> _weights = {}; // Shares
  late List<ExpenseItem> _items; // By item

  /// The group the inputs above were set up for.
  String? _setUpFor;

  @override
  void initState() {
    super.initState();
    _groups = GroupService.instance.watchMyGroups();
    _groupId = widget.groupId;
    _items = widget.items?.toList() ?? [];
    _mode = _items.isEmpty ? SplitMode.equal : SplitMode.byItem;
    if (_items.isNotEmpty) _amount.text = _plain(_itemsTotal);
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    for (final c in [..._exact.values, ..._percent.values]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- Helpers ----------

  int get _itemsTotal => _items.fold(0, (a, i) => a + i.amountCents);
  int get _totalCents => parsePesosToCents(_amount.text) ?? 0;
  String get _myId => GroupService.instance.myId;

  /// 47000 → "470", 47050 → "470.50" (for filling text fields).
  static String _plain(int cents) =>
      cents % 100 == 0 ? '${cents ~/ 100}' : (cents / 100).toStringAsFixed(2);

  /// 2500 basis points → "25", 3333 → "33.33".
  static String _plainPercent(int bp) =>
      bp % 100 == 0 ? '${bp ~/ 100}' : (bp / 100).toStringAsFixed(2);

  String _name(Person p) => p.id == _myId ? 'You' : p.name;

  /// Prepares the per-member inputs for [group]. Starts fresh when the
  /// group changes; adds anyone who joined while the form was open.
  void _setUp(Group group) {
    if (_setUpFor != group.id) {
      _setUpFor = group.id;
      _included.clear();
      _weights.clear();
      for (final c in [..._exact.values, ..._percent.values]) {
        c.dispose();
      }
      _exact.clear();
      _percent.clear();
      _category ??= group.category.name;
      final me = group.memberById(_myId);
      _payerId = (me ?? group.members.first).id;
    }
    for (final m in group.members) {
      if (_exact.containsKey(m.id)) continue;
      _included.add(m.id);
      _weights[m.id] = 1;
      _exact[m.id] = TextEditingController();
      _percent[m.id] = TextEditingController();
    }
  }

  /// Turns the inputs into shares (or an error) for [group].
  ({Map<String, int>? shares, String? error}) _split(Group group) {
    final ids = [for (final m in group.members) m.id];
    String? badField;
    final exact = <String, int>{};
    final percent = <String, int>{};
    for (final id in ids) {
      final e = _exact[id]!.text;
      final cents = e.trim().isEmpty ? 0 : parsePesosToCents(e);
      if (cents == null) badField = 'Check the amounts: numbers only';
      exact[id] = cents ?? 0;
      final bp = parsePercent(_percent[id]!.text);
      if (bp == null) badField = 'Check the percents: 0 to 100';
      percent[id] = bp ?? 0;
    }
    if (badField != null &&
        (_mode == SplitMode.exact || _mode == SplitMode.percent)) {
      return (shares: null, error: badField);
    }
    return buildShares(
      mode: _mode,
      totalCents: _totalCents,
      memberIds: ids,
      included: _included,
      exact: exact,
      percent: percent,
      weights: _weights,
      items: _items,
    );
  }

  // ---------- Actions ----------

  void _setMode(SplitMode mode) => setState(() {
    _mode = mode;
    // By item: the amount is the items' total.
    if (mode == SplitMode.byItem && _items.isNotEmpty) {
      _amount.text = _plain(_itemsTotal);
    }
  });

  /// "Fill in evenly" for Exact / Percent.
  void _fillEvenly(Group group) => setState(() {
    final ids = [for (final m in group.members) m.id];
    if (_mode == SplitMode.exact) {
      final even = splitByWeights(_totalCents, {for (final id in ids) id: 1});
      for (final id in ids) {
        _exact[id]!.text = _plain(even[id] ?? 0);
      }
    } else {
      final even = splitByWeights(10000, {for (final id in ids) id: 1});
      for (final id in ids) {
        _percent[id]!.text = _plainPercent(even[id] ?? 0);
      }
    }
  });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateUtils.dateOnly(DateTime.now()), // no future expenses
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// Add (index null) or edit an item with the Edit Item sheet.
  Future<void> _editItem(int? index) async {
    final result = await showEditItemSheet(
      context,
      index == null ? null : _items[index],
    );
    if (result == null) return;
    setState(() {
      if (result.deleted) {
        _items.removeAt(index!);
      } else if (index == null) {
        _items.add(result.item!);
      } else {
        _items[index] = result.item!;
      }
      _amount.text = _items.isEmpty ? '' : _plain(_itemsTotal);
    });
  }

  /// Choose who shares item [index] (nobody chosen = everyone).
  Future<void> _assignItem(Group group, int index) async {
    final item = _items[index];
    final chosen = item.assignedTo.toSet();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Who had ${item.name}?', style: AppText.title),
                const Text(
                  'Pick everyone who shares it. Nobody picked = everyone.',
                  style: AppText.caption,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in group.members)
                      FilterChip(
                        key: ValueKey('assign-${m.id}'),
                        avatar: Avatar(m, size: 22),
                        label: Text(_name(m)),
                        selected: chosen.contains(m.id),
                        selectedColor: mint,
                        checkmarkColor: green,
                        onSelected: (on) => setSheet(
                          () => on ? chosen.add(m.id) : chosen.remove(m.id),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Btn('Done', () => Navigator.pop(context, true)),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    setState(() {
      _items[index] = ExpenseItem(
        name: item.name,
        amountCents: item.amountCents,
        // Keep the group's member order, not the tap order.
        assignedTo: [
          for (final m in group.members)
            if (chosen.contains(m.id)) m.id,
        ],
        aiGenerated: item.aiGenerated,
        needsReview: item.needsReview,
      );
    });
  }

  Future<void> _save(Group group) async {
    setState(() => _triedSave = true);
    final formOk = _formKey.currentState!.validate();
    final split = _split(group);
    if (!formOk) return;
    if (split.error != null) {
      showAppToast(context, split.error!);
      return;
    }
    // AI items still marked "Needs review": the user decides, not the AI.
    final review = _mode == SplitMode.byItem
        ? _items.where((i) => i.needsReview).length
        : 0;
    if (review > 0) {
      final goOn = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Some items need review'),
          content: Text(
            '$review ${review == 1 ? 'item is' : 'items are'} marked '
            '"Needs review". Save anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Check items'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );
      if (goOn != true || !mounted) return;
    }

    final payer = group.memberById(_payerId ?? '') ?? group.members.first;
    final expense = GroupExpense.create(
      title: _title.text,
      paidById: payer.id,
      paidByName: payer.name,
      amountCents: _totalCents,
      shares: split.shares!,
      items: _mode == SplitMode.byItem ? _items : (widget.items ?? const []),
      category: _category ?? group.category.name,
      source: widget.source,
      splitMode: _mode.name,
      spentOn: _date,
    );

    setState(() => _saving = true);
    try {
      final id = await GroupService.instance.addExpense(group.id, expense);
      if (!mounted) return;
      // Replace the form with the saved expense, so Back goes home.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => SplitSummary(groupId: group.id, expenseId: id),
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

  // ---------- Validators ----------

  String? _validateTitle(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Enter what the expense was for';
    if (t.length > 60) return 'Keep it under 60 characters';
    return null;
  }

  String? _validateAmount(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Enter the amount';
    final cents = parsePesosToCents(v!);
    if (cents == null) return 'Use numbers only, like 2500.00';
    if (cents <= 0) return 'The amount must be more than ₱0';
    if (cents > maxExpenseCents) return 'That looks too big. Check the amount';
    return null;
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Group>>(
    stream: _groups,
    builder: (context, snapshot) {
      final groups = snapshot.data ?? const <Group>[];
      final group = groups.isEmpty
          ? null
          : groups.firstWhere(
              (g) => g.id == _groupId,
              orElse: () => groups.first,
            );
      if (group != null && group.members.isNotEmpty) _setUp(group);
      return AppPage(
        'Add Expense',
        AsyncStateView<List<Group>>(
          snapshot: snapshot,
          isEmpty: (list) => list.isEmpty,
          emptyIcon: Icons.groups_outlined,
          emptyMessage: 'Create or join a group first, then add expenses.',
          builder: (_) => _form(groups, group!),
        ),
        actions: [
          if (widget.items == null)
            IconButton(
              tooltip: 'Scan a receipt instead',
              icon: const Icon(Icons.document_scanner_outlined),
              onPressed: () => go(context, ScanReceipt(groupId: _groupId)),
            ),
        ],
        bottom: Btn(
          _saving ? 'Saving…' : 'Save Expense',
          group == null || _saving ? null : () => _save(group),
          key: const ValueKey('save-expense'),
        ),
      );
    },
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 12, color: muted)),
  );

  Widget _form(List<Group> groups, Group group) {
    final split = _split(group);
    final byItem = _mode == SplitMode.byItem;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.groupId == null) ...[
            _label('Group'),
            DropdownButtonFormField<String>(
              key: const ValueKey('expense-group'),
              initialValue: group.id,
              isExpanded: true,
              items: [
                for (final g in groups)
                  DropdownMenuItem(value: g.id, child: Text(g.name)),
              ],
              onChanged: (id) => setState(() {
                _groupId = id;
                _category = null; // take the new group's category
              }),
            ),
          ],
          _label('Expense name'),
          TextFormField(
            key: const ValueKey('expense-name'),
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'e.g. Samgyup House'),
            validator: _validateTitle,
          ),
          _label('Amount'),
          TextFormField(
            key: const ValueKey('expense-amount'),
            controller: _amount,
            readOnly: byItem, // By item: the items' total
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
            ],
            style: AppText.money(26, color: deep),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixText: '₱ ',
              prefixStyle: AppText.money(26, color: deep),
              suffixText: 'PHP',
              hintText: '0.00',
              helperText: byItem ? 'The total of the items below' : null,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: green, width: 1.5),
              ),
            ),
            validator: _validateAmount,
          ),
          _label('Paid by'),
          PayerPicker(
            members: group.members,
            payerId: _payerId ?? '',
            onChanged: (id) => setState(() => _payerId = id),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Date'),
                    InkWell(
                      key: const ValueKey('expense-date'),
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          suffixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                        child: Text(_dateText(_date)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Category'),
                    DropdownButtonFormField<String>(
                      key: ValueKey('expense-category-${group.id}'),
                      initialValue: _category ?? group.category.name,
                      isExpanded: true,
                      items: [
                        for (final c in groupCategories)
                          DropdownMenuItem(value: c.name, child: Text(c.name)),
                      ],
                      onChanged: (c) => setState(() => _category = c),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _label('Split'),
          _ModeTabs(mode: _mode, onChanged: _setMode),
          const SizedBox(height: 12),
          if (byItem) ..._itemList(group),
          _memberList(group, split.shares),
          if (_mode == SplitMode.exact || _mode == SplitMode.percent)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _fillEvenly(group),
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: const Text('Fill in evenly'),
              ),
            ),
          if (split.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: _triedSave ? errorFg : unpaidFg,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      split.error!,
                      key: const ValueKey('split-error'),
                      style: TextStyle(
                        fontSize: 12,
                        color: _triedSave ? errorFg : unpaidFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "Oct 28, 2026".
  static String _dateText(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  /// By item: the receipt lines, each with who shares it.
  List<Widget> _itemList(Group group) => [
    for (var i = 0; i < _items.length; i++)
      _ItemRow(
        item: _items[i],
        people: [for (final id in _items[i].assignedTo) ?group.memberById(id)],
        onAssign: () => _assignItem(group, i),
        onEdit: () => _editItem(i),
      ),
    Center(
      child: TextButton.icon(
        key: const ValueKey('add-item'),
        onPressed: () => _editItem(null),
        icon: const Icon(Icons.add, color: green),
        label: const Text(
          'Add item',
          style: TextStyle(color: green, fontWeight: FontWeight.w700),
        ),
      ),
    ),
    const SizedBox(height: 4),
  ];

  /// One row per member; the right side depends on the split mode.
  Widget _memberList(Group group, Map<String, int>? shares) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12)],
    ),
    child: Column(
      children: [
        for (final m in group.members)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Avatar(m, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name(m),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      // The resulting amount, for modes that compute it.
                      if (_mode != SplitMode.exact && shares != null)
                        Text(
                          formatMoney(shares[m.id] ?? 0),
                          key: ValueKey('share-${m.id}'),
                          style: AppText.caption,
                        ),
                    ],
                  ),
                ),
                _memberInput(m),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _memberInput(Person m) {
    switch (_mode) {
      case SplitMode.equal:
        return Checkbox(
          key: ValueKey('include-${m.id}'),
          value: _included.contains(m.id),
          activeColor: green,
          onChanged: (on) => setState(
            () => on! ? _included.add(m.id) : _included.remove(m.id),
          ),
        );
      case SplitMode.exact:
        return _SmallField(
          key: ValueKey('exact-${m.id}'),
          controller: _exact[m.id]!,
          prefix: '₱',
          onChanged: () => setState(() {}),
        );
      case SplitMode.percent:
        return _SmallField(
          key: ValueKey('percent-${m.id}'),
          controller: _percent[m.id]!,
          suffix: '%',
          onChanged: () => setState(() {}),
        );
      case SplitMode.shares:
        final w = _weights[m.id] ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'One share less',
              onPressed: w == 0
                  ? null
                  : () => setState(() => _weights[m.id] = w - 1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 24,
              child: Text(
                '$w',
                key: ValueKey('weight-${m.id}'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              key: ValueKey('more-${m.id}'),
              tooltip: 'One share more',
              onPressed: w >= 20
                  ? null
                  : () => setState(() => _weights[m.id] = w + 1),
              icon: const Icon(Icons.add_circle_outline, color: green),
            ),
          ],
        );
      case SplitMode.byItem:
        return const SizedBox.shrink(); // the amount shows under the name
    }
  }
}

/// Equal · By item · Exact · Percent · Shares, as soft pill tabs.
class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.mode, required this.onChanged});

  final SplitMode mode;
  final ValueChanged<SplitMode> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: mint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        for (final m in SplitMode.values)
          Expanded(
            child: Semantics(
              button: true,
              selected: m == mode,
              child: GestureDetector(
                key: ValueKey('mode-${m.name}'),
                onTap: () => onChanged(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: m == mode ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: m == mode
                        ? const [
                            BoxShadow(color: Color(0x14000000), blurRadius: 6),
                          ]
                        : null,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      m.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: m == mode ? ink : muted,
                        fontWeight: m == mode
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Narrow grey input on the right of a member row (₱470.00 / 25 %).
class _SmallField extends StatelessWidget {
  const _SmallField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.prefix,
    this.suffix,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? prefix, suffix;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 112,
    child: TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.]'))],
      style: const TextStyle(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: background,
        hintText: '0',
        prefixText: prefix,
        suffixText: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
      ),
    ),
  );
}

/// One receipt line in "By item": name, price, and who shares it.
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.people,
    required this.onAssign,
    required this.onEdit,
  });

  final ExpenseItem item;
  final List<Person> people;
  final VoidCallback onAssign, onEdit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onAssign,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.needsReview ? unpaidFg : border,
              width: item.needsReview ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (people.isEmpty)
                          const Pill('Everyone', icon: Icons.groups_outlined)
                        else
                          for (final p in people.take(5))
                            Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Avatar(p, size: 20),
                            ),
                        if (item.needsReview) ...[
                          const SizedBox(width: 6),
                          const Pill.needsReview(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                formatMoney(item.amountCents),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              IconButton(
                tooltip: 'Edit item',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18, color: muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
