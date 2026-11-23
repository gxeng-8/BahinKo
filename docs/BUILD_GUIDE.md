# BahinKo Build Guide: Figma → Flutter

This guide turns the Figma hi-fi prototype (frames 1–25) into working screens that also meet the CC 207B requirements. Read it together with [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md).

> **Ground rule (course AI policy):** each member builds their own screens. AI help is allowed for snippets and debugging but **must go in the AI Usage Log**, and you must be able to explain and live-edit every line in the Individual Code Defense. Do not have AI generate whole screens.

---

## 0. What's already done

| Done | Where |
|---|---|
| Code split into `screens/ models/ widgets/ utils/ theme/ data/` | `lib/` |
| **Design system**: colors, fonts, input style from Figma | `lib/theme/app_colors.dart`, `lib/theme/app_theme.dart` |
| Fonts bundled offline (LilitaOne titles, Poppins body) | `assets/fonts/`, `pubspec.yaml` |
| Shared Figma components (see §1) | `lib/widgets/` |
| **Reference screen**: Frame 1 Onboarding rebuilt to match Figma | `lib/screens/onboarding/onboarding_screen.dart` |
| **M1 UI (mock data)**: Shell (4 tabs), Home (3), App Lock (2), Create Group (4), Group Detail (5), Members (21), Invite (22) | `lib/screens/shell.dart`, `home/`, `auth/`, `group/`; tests in `test/group_screens_test.dart` |
| Group model + sample groups; `formatMoney()` ("₱1,060.00") | `lib/models/group.dart`, `lib/data/mock_data.dart`, `lib/utils/currency.dart` |

Because `AppPage`, `Btn`, and `Pill` were restyled, **every existing screen already picked up** the new title font, round back button, gradient buttons, and rounded inputs. What's left per screen is the layout and content of each frame.

⚠️ **Confirm fonts:** in Figma, click a title, then open **Inspect** and read the font name. If it isn't Lilita One / Poppins, swap the `.ttf` files and change `displayFont`/`bodyFont` in `app_theme.dart`.

---

## 1. Design system cheat sheet

**Rule: no raw hex colors or ad-hoc text styles inside screens.** Use these:

| Need | Use |
|---|---|
| Colors | `green`, `deep`, `mint`, `lime`, `ink`, `muted`, `border`, `background`, `paidBg/paidFg`, `unpaidBg/unpaidFg`, `errorFg`, `bannerBg` |
| Green gradient (headers, hero cards) | `BoxDecoration(gradient: brandGradient)` |
| Title text | `AppText.title`, `AppText.display(36, color: Colors.white)` |
| Section heading / money / caption | `AppText.section`, `AppText.money(28)`, `AppText.caption` |
| Standard page (title + back + bottom buttons) | `AppPage('Assign Items', body, bottom: Btn(...))` |
| Primary / secondary button | `Btn('Save', onSave)` / `Btn('Not yet', onTap, outlined: true)`; `Btn('X', null)` = disabled |
| Two buttons side by side (Figma 5, 11) | `Row(children: [Expanded(child: Btn(.., outlined: true)), SizedBox(width: 12), Expanded(child: Btn(..))])` |
| Status pill | `Pill.paid()`, `Pill.unpaid(text: '3 unpaid')`, `Pill.needsReview()`, `Pill('Split equally')` |
| White card | `Box(child)` |
| Green info note | `InfoBanner('Receipts are processed securely…')` |
| "Members ..... See all" | `SectionHeader('Members', actionText: 'See all', onAction: ...)` |
| Mint icon square (+ label) | `IconTile(Icons.receipt_long, label: 'Scan', onTap: ...)` |
| Member avatar | `Avatar(person, size: 36)` |
| Toast (15b, 23b) | `showAppToast(context, 'Reminder sent to Jun')` |
| Loading / empty / error | `AsyncStateView(snapshot: snap, builder: ..., isEmpty: ..., onRetry: ...)` |
| Round back button on green header | `RoundBackButton(onDark: true)` |

### Recipe: building one screen
1. Open the Figma frame next to the code. Break it into **blocks** top to bottom (header, card, list, bottom buttons).
2. Make each block a **small private widget** (`_HeroCard`, `_MemberRow`) in the same file. See `onboarding_screen.dart`.
3. Use `AppPage` unless the frame has a full green header (Home, Scan).
4. Start with **mock data**. Once your service exists, switch to a `FutureBuilder`/`StreamBuilder` + `AsyncStateView`.
5. Add a `///` comment at the top of the file and above each class/method that does real work.
6. Run `dart format lib && dart analyze` (should report 0 issues) and `flutter test`.
7. Commit on your feature branch and open a PR.

---

## 2. Screen map: who builds what

Legend: **R** = restyle an existing file · **N** = new file · ⭐ = counts toward a course requirement

| # | Figma frame | File | | Owner | Requirement it covers |
|---|---|---|---|---|---|
| 1 | Onboarding | `screens/onboarding/onboarding_screen.dart` | ✅ done | — | Layout/Value widgets |
| 2 | App Lock (PIN) | `screens/auth/app_lock_screen.dart` | N | M1 | ⭐ Form validation, persistence (secure storage) |
| 3 | Home + bottom nav | `screens/home/home_screen.dart`, `screens/shell.dart` | R | M1 | ⭐ Navigation, async states |
| 4 | Create Group | `screens/group/create_group_screen.dart` | N | M1 | ⭐ **Core feature F5**, form validation |
| 5 | Group Detail | `screens/group/group_detail_screen.dart` | R | M1 | ⭐ Firestore stream + async states |
| 6 | Add Expense | `screens/bill/add_expense_screen.dart` (replaces `manual_receipt_entry_screen.dart`) | N | M3 | ⭐ **Core feature F2**, best validation showcase |
| 7 | Scan Receipt | `screens/scan/scan_receipt_screen.dart` | R | M2 | ⭐ **AI feature F1** |
| 8 | Scanning | `screens/scan/scanning_screen.dart` | N | M2 | ⭐ AI loading state |
| 9 | Assign Items | `screens/bill/assign_items_screen.dart` | R | M2 | ⭐ AI labeling ("Needs review") |
| 10 | Edit Item (sheet) | `screens/bill/widgets/edit_item_sheet.dart` | N | M2 | ⭐ AI override (responsible use) |
| 11 | Split Summary | `screens/bill/split_summary_screen.dart` | R | M3 | ⭐ **Core feature F3** |
| 12 | Settle Up | `screens/settle/settle_up_screen.dart` | R | M4 | ⭐ **Core feature F4** |
| 13 / 13-Maya | Payment Handoff: Opening | `screens/settle/payment_handoff_screen.dart` | R (from `payment_dialogs.dart`) | M4 | Async + external app launch |
| 13b | Payment Handoff: Confirm | same file | R | M4 | State change |
| 14 | Payment Proof | `screens/settle/payment_proof_screen.dart` (from dialog) | R | M4 | ⭐ Form + image upload |
| 15 / 15b | Reminder sheet + toast | `screens/settle/widgets/reminder_sheet.dart` | R | M4 | Interaction widgets |
| 16 | Recurring Bills | `screens/recurring/recurring_bills_screen.dart` | R | M5 | ⭐ **Core feature F6** |
| 17 | Add Recurring Bill | `screens/recurring/add_recurring_bill_screen.dart` (replaces `widgets/add_recurring_bill_dialog.dart`) | R | M5 | ⭐ Form validation |
| 18 | Statistics | `screens/stats/statistics_screen.dart` | R | M5 | Charts, async states |
| 19 | Personal Ledger | `screens/history/personal_ledger_screen.dart` | R | M5 | ⭐ **F7** filter records |
| 20 | Activity History | `screens/history/activity_history_screen.dart` | R | M5 | ⭐ **F7** filter + grouped list |
| 21 | Members | `screens/group/members_screen.dart` | R | M1 | ⭐ **F5** search members |
| 22 | Invite | `screens/group/invite_members_screen.dart` | R | M1 | ⭐ **F5** QR/link + guest form |
| 23 / 23b | Report Preview + toast | `screens/bill/report_preview_screen.dart` | N | M3 | Export PDF/CSV |
| 24 | Profile & Settings | `screens/settings/profile_screen.dart` | N | M3 | Persistence (settings toggles) |
| 25 | Privacy & Trust | `screens/settings/privacy_screen.dart` | R | M5 | ⭐ RA 10173 / responsible AI |

*Smaller team?* Merge M5 into M3 and M4. The AI owner (M2) stays separate either way.

---

## 3. Frame-by-frame notes

Only the details that are easy to miss are listed here. Everything else, copy from Figma.

### M1: App shell, groups, profile
- **2 App Lock:** a custom keypad, so no TextField. A 3×4 `GridView` of round white keys, 4 dots that fill as you type, a fingerprint key, and a backspace key.
  - *Validation:* wrong PIN → shake the dots + show the error text "Incorrect PIN, 2 tries left".
  - Store a **hash** of the PIN with `flutter_secure_storage`, never the plain PIN.
  - Fingerprint: `local_auth`.
  - Only show this screen when "App lock" is on in Profile (24).
- **3 Home:**
  - Green header with net balance and two chips ("Owed to you" green, "You owe" orange).
  - A white quick-action card **overlapping** the header: `Stack` + `Positioned`, or `Transform.translate(offset: Offset(0, -30))`.
  - Categories: `GridView.count(crossAxisCount: 4)` of `IconTile`s.
  - Active Groups: horizontal `ListView` of gradient cards.
  - **Bottom nav (Shell):** Home · Stats · [Scan FAB] · History · Profile. The current Shell has only 2 tabs. Use `BottomAppBar` + `FloatingActionButtonLocation.centerDocked`, and keep tab state with `IndexedStack`.
- **4 Create Group:**
  - 2×2 template cards (Trip / Household / Dinner or Event / Custom). Tapping one selects it (green border + check) and pre-fills the Category.
  - Wrap the inputs in a `Form`. Validators: name required, 3–40 characters; at least 1 member besides you.
  - Saves to Firestore `groups/`, then navigates to Group Detail.
- **5 Group Detail:**
  - Gradient hero card: total, "2 expenses" and "3 unpaid" pills.
  - Expenses list from a Firestore **stream** → wrap in `AsyncStateView` (empty: "No expenses yet. Add one or scan a receipt.").
  - Activity feed. Bottom row: `Settle Up` (outlined) + `+ Add Expense`.
- **21 Members:**
  - "+" in the app bar (`AppPage(actions: [...])`) → Invite (22).
  - **Search field** "Search members" filters the list as you type: keep the query in state and filter with `name.toLowerCase().contains(query.toLowerCase())`. Empty result → "No members match 'xyz'".
  - Each row: avatar, name, payment method subtitle ("GCash · paid the bill"), and a status pill on the right: `Pill.paid(text: 'Paid the bill')`, `Pill.unpaid(text: 'Owes ₱220.00')`, `Pill.paid()`, and an outlined grey "Guest" pill for members without the app ("Guest · no app needed").
  - Green card at the bottom: people icon, "Invite friends", "Friends can join by link or QR code. Guests without the app can be added." + `Btn('Copy invite link', ...)`.
- **22 Invite:**
  - White card: group name "Dinner at Jaro", "Scan to join · 5 members", a **QR code** (`qr_flutter`: `QrImageView(data: inviteUrl)`), and the short link in a grey chip under it.
  - `Btn('Copy invite link')` → `Clipboard.setData` + `showAppToast(context, 'Link copied')`. `Btn('Share via Messenger', outlined: true)` → `share_plus` (opens the system share sheet; Messenger appears there).
  - "or" divider, then **"Add a guest instead"**: a small `Form` with a Guest name field (required, 2–30 chars, letters/spaces only), caption "Guests can view their share through a link. No install needed.", and an Add guest button. The guest is saved to the group with `isGuest: true`.
  - Invite link: generate a short random code per group (store it in `groups/{id}.inviteCode`). Opening the link on another phone is a stretch goal; for the demo, QR + copy is enough.

### M2: AI receipt scanner (the AI feature)
- **7 Scan Receipt:**
  - Green header; camera preview inside a white card with **corner brackets**: a `CustomPainter`, or 4 `Positioned` L-shaped containers.
  - "Scan Receipt" button; "or" divider; "Enter Manually" (outlined) → Frame 6.
  - `InfoBanner` about secure processing.
  - On web/Windows (no camera), hide the camera and show only Enter Manually.
- **8 Scanning:**
  - An animated green line sweeping over the receipt image (`AnimationController` + `AnimatedBuilder` moving a `Positioned` line), plus a spinner.
  - Show the stage: "Reading your receipt…" (ML Kit OCR), then "Organizing items…" (Gemini).
  - Timeout after 10 s → fall back to the regex parser. Total failure → error card with **Retake** / **Enter manually**.
- **9 Assign Items:**
  - Header text "Scanned 6 items from Samgyup House".
  - Orange warning banner `InfoBanner('1 needs review – tap any item to edit', icon: Icons.warning_amber_rounded, color: unpaidBg)`.
  - Items the AI is unsure about get an **orange border + `Pill.needsReview()`**.
  - A small "✨ AI-detected" label on the list header. **This is the "AI content is labeled" requirement.**
  - Bottom bar: Total + "Confirm Split".
- **10 Edit Item sheet:** `showModalBottomSheet(isScrollControlled: true)`.
  - Fields: name, price (validate: required, > 0, max 2 decimals), avatar multi-select with check badges, Split chips (Equal / Custom).
  - "Flag this item" + Save. Saving sets `aiEdited = true`. **This is the "user can correct/override AI" requirement.**
- **Service code:**
  - `services/ocr_service.dart`: move `utils/receipt_ocr*.dart` here.
  - `services/ai_receipt_service.dart`: send Gemini only the OCR text, ask for JSON `{items:[{name, price, confidence}], serviceCharge, vat, total}`.
  - Mark an item **needs review** if `confidence < 0.7`, the price failed to parse, or the item sum ≠ total.

### M3: Expenses, split, report
- **6 Add Expense:** **the main form-validation showcase.**
  - Fields: Expense name, Amount (large ₱ field), Paid by (avatar selector), Date (`showDatePicker`), Category (dropdown).
  - Split mode: `SegmentedButton` with Equal / By item / Exact / Percent / Shares. Each member row shows their computed amount; it's editable in Exact/Percent/Shares mode.
  - Validators:
    - name required
    - amount > 0 with 2 decimals max (reuse `parsePesosToCents`)
    - Exact amounts **must add up to the total**: show a red "₱120.00 left to assign" under the list
    - Percent must total 100
  - Disable Save (`Btn('Save Expense', null)`) until the form is valid.
- **11 Split Summary:**
  - Receipt-styled card with **zigzag top/bottom edges** (`ClipPath` with a custom `CustomClipper`).
  - Monospace-ish rows of items, service charge, VAT, TOTAL, then "EACH PERSON PAYS" with avatars.
  - Share icon in the app bar. Bottom: Download report (outlined) → 23, Settle Up → 12.
- **23 Report Preview:**
  - A document-styled card: two tables (expenses, per person) built with `Table`.
  - Export PDF (`pdf` + `printing`), Export CSV (`csv` + `path_provider`/`share_plus`).
  - Afterwards: `showAppToast(context, 'Report saved to Downloads')`.
- Keep share math in `utils/split_calculator.dart` and **unit-test it** (an easy code-defense win).
- **24 Profile:**
  - User card with **masked** wallet numbers ("0917 ••• 4521"; privacy).
  - `SwitchListTile`s for Auto-delete receipt photos / Offline mode, saved with `shared_preferences`.
  - Log out in red (`errorFg`).

### M4: Settle up & payments
- **12 Settle Up:**
  - Top banner "Smart settle: 4 transfers instead of 6". This is a **debt-simplification algorithm** (greedy: match the biggest debtor with the biggest creditor). It's normal logic, not AI; implement it in `utils/settle_calculator.dart`.
  - "You pay" cards: Pay with GCash (filled) / Pay with Maya (outlined) / Paid in cash / Upload proof.
  - "Pays you" cards: Send neutral reminder. A Partial payment shows a `LinearProgressIndicator` + "₱200.00 paid · ₱195.00 left".
- **13 Payment Handoff:**
  - Big mint circle, wallet icon, "Opening GCash…" + spinner, an amount card with a "Prefilled" pill, the banner "BahinKo only redirects you…", and Cancel. Same screen for Maya via a parameter.
  - Launch the app with `url_launcher`.
  - **Honest limitation:** GCash/Maya don't offer public deep links that pre-fill an amount. Copy the amount to the clipboard (`Clipboard.setData`) and say so. Put this in Known Limitations.
- **13b Confirm:** shown when the user returns to the app (`WidgetsBindingObserver.didChangeAppLifecycleState == resumed`).
  - "Yes, I paid" → payment `status: pending_confirmation`.
  - "Not yet" → back.
- **14 Payment Proof:** full screen, not a dialog.
  - Amount paid field + "Pay part of it (partial payment)" checkbox. Validation: amount > 0 and ≤ what you owe; partial unchecked ⇒ amount must equal the full share.
  - Dashed upload box (`image_picker`; for the dashed border, a `CustomPainter` or the `dotted_border` package) showing the file name/size + "Replace image".
  - Optional reference no. (digits only: `FilteringTextInputFormatter.digitsOnly`).
  - "What Carla sees" preview card. Submit uploads to Firebase Storage. Show a spinner, and an error + retry on failure.
- **15 Reminder sheet:**
  - Bottom sheet with a message preview, the note "Neutral and polite. The notification preview won't show the amount.", and a `Switch` for "Remind again 1 day before due date".
  - Send → `showAppToast(context, 'Reminder sent to Jun')` (15b).

### M5: Recurring, history/stats, privacy
- **16 Recurring Bills:**
  - Lime-gradient group card ("Boarding House Bills · ₱15,600 a month · 4 members" + stacked avatars).
  - "This month" list: icon tile, name, "Every month · your share ₱3,000", due text, status pill (Paid / Unpaid / **Varies** for electricity).
  - "+ Add recurring bill" (outlined) → Frame 17.
  - Banner "Members get a polite reminder 3 days before each due date."
- **17 Add Recurring Bill:** a full screen now, not a dialog. Move the logic out of `add_recurring_bill_dialog.dart` into a new screen and delete the dialog.
  - Fields in a `Form`: Bill name (required), Amount (required, > 0, reuse `parsePesosToCents`), a "Varies each month" `Switch` (when on, the amount becomes an *estimate* and the list shows `≈₱2,200` + "Varies").
  - Repeats: Weekly / Monthly `ChoiceChip`s. Due date: a tappable field ("Every 15th of the month") that opens a day picker; its text changes with Weekly ("Every Monday").
  - Split rule: "Equal · ₱150 each" (recomputed live from amount ÷ selected members) / Custom.
  - Members: avatar multi-select with check badges. **Validate at least 1 member is selected** (show red text under the row, since it isn't a TextField).
  - "Remind members 3 days before the due date" `Switch`. Save pops back and returns the new bill: `Navigator.pop(context, bill)`.
- **18 Statistics:**
  - Header "Total owed to you" + big `AppText.money(32)`.
  - "Overview" card with a "Month ▾" dropdown and a **grouped bar chart** (Mar–Oct, two bars per month: Paid = `green`, Owed to you = `lime`) with a legend. Use `fl_chart`'s `BarChart` with two `BarChartRodData` per group.
  - Two tiles side by side: "Collected ₱970.00" (dark: `deep`) and "Paid out ₱3,000.00" (`brandGradient`).
  - "Spending by category · October": rows with name, %, and a `LinearProgressIndicator` (rounded via `ClipRRect`).
  - Compute everything from Firestore bills (sum by month/category). Wrap in `AsyncStateView`; empty state: "No spending yet this month."
- **19 Personal Ledger:**
  - Hero card (`brandGradient`): "Net across all groups ₱710.00", plus "Owed to you ₱1,060.00" / "You owe ₱350.00" pills.
  - **Filter chips** All / You owe / Owed to you / Settled (`ChoiceChip`, one selected). This is the F7 "filter records" proof.
  - Rows: avatar, name, "Dinner at Jaro · Oct 28", amount on the right: **green "+₱845.00"** when they owe you and **red "−₱350.00"** when you owe, with a Paid / Unpaid / Partial pill below.
  - Empty result per filter: "Nothing here. You're all settled up 🎉".
- **20 Activity History:**
  - Filter chips All / Edits / Payments / Reminders.
  - List **grouped by day** with headers "Today · Oct 30", "Yesterday · Oct 29", "Oct 28". Build it by grouping events by date (`intl`'s `DateFormat`), then a `ListView` that inserts a header whenever the date changes.
  - Each row: avatar, bold sentence ("Leo paid ₱200.00 of ₱395.00"), grey subtitle ("Dinner at Jaro · 9:12 AM"), and a trailing icon tile by type (receipt = payment, bell = reminder, check = confirmed, red flag = flagged for review, pencil = edit, plus = added).
  - Edit events show **old → new** price chips: old in red with `TextDecoration.lineThrough`, new in green.
  - Data: an `activity` subcollection under each group, written whenever someone pays, edits, flags, or reminds.
- **25 Privacy & Trust:**
  - Shield icon tile, "Your money and data stay yours.", 4 cards (Clear privacy policy · Encrypted data · We never hold your money · You control your receipts), and a chip "GCash · Maya payment redirect only".
  - Add one more line about the AI: *"Only receipt text (never the photo) is sent to the AI."*

---

## 4. Build order (matches the 4-week plan)

| Week | Everyone | M1 | M2 | M3 | M4 | M5 |
|---|---|---|---|---|---|---|
| **1** UI | Restyle your frames with mock data | Shell (5-tab nav), Home, App Lock UI, Firebase project | Scan, Scanning (animation only) | Add Expense form + validation | Settle Up, Handoff screens | Recurring + Add Recurring (17), Privacy |
| **2** Data | Swap mock data for services | `auth_service`, `firestore_service`, Create Group, Group Detail stream, Members search (21) | `ocr_service`, `ai_receipt_service` | Save expense; Split Summary from Firestore | Payments collection, `settle_calculator` | Recurring CRUD, Ledger (19) + Activity (20) filters |
| **3** Harden | `AsyncStateView` everywhere, comments, tests | Invite QR + guest form (22), PIN hashing | Fallback chain, Needs-review, Edit sheet | Report PDF/CSV, Profile (24) | Proof upload, reminders | Stats charts (18) |
| **4** Ship | Docs, slides, demo video, defense drill | README, final PR | AI spec + failure-case log | Topic matrix rows | Deck + video | Screenshots |

### Packages to add when you reach them
Run `flutter pub add <name>` (it picks a compatible version), then record the version in the docs' Tech Stack table.

| Who | Packages |
|---|---|
| M1 | `firebase_core`, `firebase_auth`, `cloud_firestore`, `provider`, `flutter_secure_storage`, `local_auth`, `qr_flutter`, `share_plus` |
| M2 | `firebase_ai` (Gemini via Firebase AI Logic, **no API key in code**); `google_mlkit_text_recognition` and `camera` are already installed |
| M3 | `intl`, `pdf`, `printing`, `csv`, `path_provider`, `share_plus`, `shared_preferences` |
| M4 | `url_launcher`, `image_picker`, `firebase_storage` |
| M5 | `fl_chart`, `intl` |

Firebase setup (M1, once): `dart pub global activate flutterfire_cli` → `flutterfire configure`. Then add `lib/firebase_options.dart`, `android/app/google-services.json`, and `ios/Runner/GoogleService-Info.plist` to **`.gitignore`** and share them privately with teammates.

---

## 5. Requirement checklist → where it's proven

Use this to fill in the **Topic Coverage Matrix** in the documentation (update the file names if yours differ).

| Course topic | Where applied (planned) | Brief description |
|---|---|---|
| Layout widgets | `home_screen.dart` (Home), `split_summary_screen.dart` | Stack/Positioned overlapping card, GridView categories, ClipPath receipt |
| Value widgets | `onboarding_screen.dart`, `pill.dart`, `avatar.dart` | Text/Icon/Image, status pills, avatars |
| Interaction widgets | `add_expense_screen.dart`, `edit_item_sheet.dart`, `reminder_sheet.dart` | SegmentedButton, TextFormField, Switch, Checkbox, bottom sheets |
| Navigation & routing | `shell.dart`, `app.dart` routes | Bottom nav with IndexedStack, push/pushReplacement, modal sheets |
| Forms & validation | `add_expense_screen.dart`, `create_group_screen.dart`, `add_recurring_bill_screen.dart`, `payment_proof_screen.dart` | Required/format/sum validators, inline errors, disabled submit |
| Search & filter (core feature F7) | `members_screen.dart`, `personal_ledger_screen.dart`, `activity_history_screen.dart` | Live text search; ChoiceChip filters; date-grouped list |
| Async / API calls | `ai_receipt_service.dart`, `group_detail_screen.dart` | Gemini call with timeout; Firestore streams via `AsyncStateView` |
| Data persistence | `firestore_service.dart`, Profile (shared_preferences), App Lock (secure storage) | Cloud + local storage |
| AI-powered feature | `scan_receipt_screen.dart` → `scanning_screen.dart` → `assign_items_screen.dart` | OCR + Gemini structuring, Needs-review labels, editable, regex fallback |

**Minimum technical requirements (a–f):** a ✔ widgets above · b ✔ Shell + routes · c ✔ Add Expense · d ✔ Firestore/prefs · e ✔ `AsyncStateView` · f ✔ folders + `///` comments.

---

## 6. Git workflow per member

```bash
git checkout main && git pull
git checkout -b feature/add-expense           # one branch per screen/feature
# ...build...
dart format lib && dart analyze && flutter test
git add lib/screens/bill/add_expense_screen.dart
git commit -m "feat(expense): add split modes and sum validation"
git push -u origin feature/add-expense
# Open a PR on GitHub → a teammate reviews → merge
```

Commit small and often, every week. Graders read the history, and code you committed yourself is what you'll defend.

---

## 7. Definition of done (per screen)
- [ ] Matches the Figma frame (compare side by side; take a screenshot for the docs)
- [ ] Uses theme tokens/widgets, no raw hex
- [ ] Real data + loading/empty/error states (where data is loaded)
- [ ] Validation with clear error text (where there's input)
- [ ] `///` comments on the file and important classes/methods
- [ ] `dart analyze` → 0 issues; `flutter test` passes
- [ ] AI help (if any) logged in the AI Usage Log
- [ ] Merged through a reviewed PR
