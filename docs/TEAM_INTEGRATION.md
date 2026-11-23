# Connecting your screens to the backend

**For:** M2–M5. **From:** M1 (backend).

The backend is ready: groups, members, expenses, payments, activity, and recurring bills are all saved in Firebase and shared live between phones. Your screens still use **sample data** (`items`, `shares`, `groupMembers` from `lib/data/mock_data.dart`). This guide shows exactly what to change in **your own files**, so the work and the commits are yours for the code defense.

Do it on your own branch (`feature/<your-screen>-backend`), open a PR, and ask M1 to review.

---

## 1. The one pattern you need

Every screen loads data the same way. Copy this.

```dart
class _MyScreenState extends State<MyScreen> {
  // 1) Create the stream ONCE in initState. Creating it in build() would
  //    open a new database listener every time the screen redraws.
  late Stream<List<GroupExpense>> _expenses;

  @override
  void initState() {
    super.initState();
    _expenses = GroupService.instance.watchExpenses(widget.groupId);
  }

  // 2) Retry button after an error: open a fresh stream.
  void _reload() => setState(
    () => _expenses = GroupService.instance.watchExpenses(widget.groupId),
  );

  @override
  Widget build(BuildContext context) => AppPage(
    'My Screen',
    // 3) StreamBuilder + AsyncStateView = loading / empty / error for free
    //    (course requirement e).
    StreamBuilder<List<GroupExpense>>(
      stream: _expenses,
      builder: (context, snapshot) => AsyncStateView<List<GroupExpense>>(
        snapshot: snapshot,
        onRetry: _reload,
        isEmpty: (list) => list.isEmpty,
        emptyMessage: 'No expenses yet.',
        builder: (list) => Column(children: [/* your UI using list */]),
      ),
    ),
  );
}
```

**Saving** data: `await` the service call in a `try`, show a loading label on the button, and show `e.message` on failure:

```dart
Future<void> _save() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _saving = true);
  try {
    await GroupService.instance.addExpense(widget.groupId, expense);
    if (!mounted) return;
    Navigator.pop(context);
    showAppToast(context, 'Expense saved');
  } on GroupFailure catch (e) {
    if (!mounted) return;
    setState(() => _saving = false);
    showAppToast(context, e.message); // already user-friendly
  }
}
// Button: Btn(_saving ? 'Saving…' : 'Save', _saving ? null : _save)
```

**Imports:** `package:bahinko/services/group_service.dart` and `package:bahinko/models/group.dart`. The latter also gives you `GroupExpense`, `ExpenseItem`, `Payment`, `ActivityEvent`, and the widgets in `lib/widgets/`.

**"Is this me?"** Compare IDs with `GroupService.instance.myId`. Don't compare names.

**Money** is always `int` centavos. Show it with `formatMoney(cents)` (e.g. "₱1,060.00") from `utils/currency.dart`, and parse typed text with `parsePesosToCents()`.

---

## 2. Every screen needs a `groupId`

Your screens don't know which group they're for yet. In your screen's constructor, add:

```dart
const SettleUp({super.key, this.groupId = demoGroupId, /* existing params */});
final String groupId;
```

`demoGroupId` (from `data/in_memory_group_service.dart`) keeps your existing tests working. Then, in your PR, update the call in [group_detail_screen.dart](../lib/screens/group/group_detail_screen.dart) to pass `groupId: g.id` (search for your screen's name there). It's a one-line change.

---

## 3. What each of you connects

### M2: AI scanner → Assign Items → save

| Where | Change |
|---|---|
| Scan result → `AssignItems` | Turn each scanned line into `ExpenseItem(name:, amountCents:, aiGenerated: true, needsReview: <AI unsure>)` and pass `items` plus `groupId` to `AssignItems`. |
| [assign_items_screen.dart](../lib/screens/bill/assign_items_screen.dart) | Get members from `GroupService.instance.watchGroup(groupId)` (pattern §1) instead of `groupMembers`. Items with `needsReview` get `Pill.needsReview()` and an orange border (Figma 9). |
| Edit Item sheet (Frame 10) | Saving changes the item. If the price changed, log it: `GroupService.instance.logActivity(groupId, ActivityEvent(type: 'edit', text: '$me edited Soju', oldCents: 42000, newCents: 45000))`. "Flag this item" → `type: 'flag'`. |
| **Confirm Split** | Build and save the expense: |

```dart
final expense = GroupExpense.create(
  title: storeName,                 // e.g. "Samgyup House"
  paidById: GroupService.instance.myId,
  paidByName: 'You',
  amountCents: total,
  shares: shares,                   // memberId → centavos, MUST add up to total
  items: items,
  category: 'Dinner',
  source: 'ai',                     // labels it as AI-generated
);
final expenseId = await GroupService.instance.addExpense(groupId, expense);
// then: SplitSummary(groupId: groupId, expenseId: expenseId)
```
If the shares don't add up, `addExpense` throws a `GroupFailure` like *"Shares add up to ₱2,499.99, but the total is ₱2,500.00"*. Show it as a toast.

### M3: Add Expense, Split Summary, Report, Profile

| Where | Change |
|---|---|
| Add Expense (Frame 6, replaces `manual_receipt_entry_screen.dart`) | After your form validates, use `GroupExpense.create(... source: 'manual')` + `addExpense()` (snippet above). Your split modes (Equal / By item / Exact / Percent / Shares) produce the `shares` map: memberId → centavos. Put that math in `utils/split_calculator.dart` and unit-test it. |
| [split_summary_screen.dart](../lib/screens/bill/split_summary_screen.dart) | Add `groupId` and `expenseId`. Stream `GroupService.instance.watchExpense(groupId, expenseId)` for the items, total and `shares`, and `watchGroup(groupId)` for member names and colors (match `Person.id` with the `shares` keys). |
| Report Preview (Frame 23) | Same two streams as Split Summary; export them to PDF/CSV. |
| Profile (Frame 24) | **Name:** `AuthService.instance.displayName` / `setDisplayName()`. **Toggles:** `SettingsService.instance` (`appLockEnabled`, `useFingerprint`, `autoDeleteReceipts`, `offlineMode`) has getters and setters, with an example at the top of [settings_service.dart](../lib/services/settings_service.dart). **Turning app lock off:** also call `AppLockService.instance.clearPin()`. Then swap `Privacy()` for your `ProfileScreen()` in [shell.dart](../lib/screens/shell.dart) (look for `TODO(M3)`). |

### M4: Settle Up & payments

| Where | Change |
|---|---|
| [settle_up_screen.dart](../lib/screens/settle/settle_up_screen.dart) | Stream three things: `watchGroup` (names), `watchExpenses` (who owes whom: each expense's `shares` are owed to its `paidById`), and `watchPayments` (minus what's been paid). Nest the StreamBuilders, or combine them in one helper. |
| Balances + **Smart settle** | Put the math in `utils/settle_calculator.dart`: balances per member, then the greedy "biggest debtor pays biggest creditor" rule for "4 transfers instead of 6". Unit-test it. It's normal logic, not AI. M1 will use your balance function for the Home header (`TODO` in `home_screen.dart`). |
| "Yes, I paid" (13b) / Submit proof (14) | `GroupService.instance.recordPayment(groupId, Payment(fromId: myId, fromName: 'You', toId: …, toName: …, amountCents: …, method: 'gcash', expenseId: …, reference: …))`. It's saved as **pending**. |
| Receiver's "Confirm" / "Paid in cash" | Confirm: `confirmPayment(groupId, payment, fullShare: !partial)`. The **security rules only let the receiver confirm** (or anyone, if the receiver is a guest without the app), so only show the button when `payment.toId == myId` or the receiver is a guest. |
| Reminder sheet (15) | After sending: `logActivity(groupId, ActivityEvent(type: 'reminder', text: 'You sent a reminder to Jun'))`. |

### M5: Recurring, Activity, Ledger, Stats

| Where | Change |
|---|---|
| [recurring_bills_screen.dart](../lib/screens/recurring/recurring_bills_screen.dart) | Replace the `_bills` list with `watchRecurring(groupId)`. **Add:** `addRecurring(groupId, RecurringBill(name, schedule, amountText, true, amountCents: …, dayOfMonth: …, varies: …))`. **Switch:** `setRecurringEnabled(groupId, bill.id, value)`. Your existing `RecurringBill(name, schedule, amount, enabled)` still works; the new fields are optional named ones. |
| [activity_history_screen.dart](../lib/screens/history/activity_history_screen.dart) | `watchActivity(groupId)` returns newest-first `ActivityEvent`s. Your filter chips map to `type`: Payments → `payment`/`confirm`, Reminders → `reminder`, Edits → `edit`/`flag`. Group them by `createdAt` day for the "Today / Yesterday" headers. Edits carry `oldCents`/`newCents` for the ₱420 → ₱450 chips. Expenses, payments, confirmations and joins are logged **automatically**. |
| [personal_ledger_screen.dart](../lib/screens/history/personal_ledger_screen.dart) | `watchMyGroups()` for the list of groups. Use M4's balance function on each group's expenses + payments. |
| [statistics_screen.dart](../lib/screens/stats/statistics_screen.dart) | Sum `watchExpenses(groupId)` by `createdAt` month (bar chart) and by `category` (progress bars). Use `AsyncStateView` with the empty message "No spending yet this month." |

---

## 4. Testing your screen (no Firebase needed)

Widget tests use the in-memory service automatically. It comes with a sample group (`demoGroupId`) that has two expenses with real `shares`:

```dart
setUp(() {
  groupMembers.value = people;
  GroupService.instance = InMemoryGroupService(); // fresh data each test
});

testWidgets('settle up lists who owes', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: SettleUp()));
  await tester.pump(); // let the stream deliver
  expect(find.text('Jun'), findsWidgets);
});
```
See `test/ledger_service_test.dart` for how each service method behaves.

---

## 5. Rules the database enforces

These are already live. If your save fails with *"You don't have access…"*, one of them is the reason:

- Only **group members** can read or write anything in the group.
- An expense needs a **title (1–60 characters)**, an **amount > 0**, and a `shares` map.
- A payment can't be **to yourself** or **₱0**. It can only be **created as pending**, unless the receiver records it.
- **Only the receiver confirms** a payment (anyone may confirm for a guest without the app).
- **Activity entries can't be edited or deleted** (honest history).

Questions → ask M1. Don't change files in `lib/services/` yourself; ask, so the rules and the in-memory version stay in sync.
