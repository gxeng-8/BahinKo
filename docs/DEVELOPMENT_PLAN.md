# BahinKo: System Development Plan (CC 207B Final Project)

**App:** BahinKo, a group bill-splitting app (scan a receipt, assign items, split, settle up)
**Framework:** Flutter (Android first; web/Windows as demo fallback)
**Plan start:** Nov 23, 2026. Timeline below assumes **4 weeks**; stretch or compress the weeks to fit the real deadline.

---

## 1. Where the project stands now

| Area | Current state | Gap vs. requirements |
|---|---|---|
| UI screens | ~20 screens built (Onboarding, Home, Group, Scan, Manual Entry, Camera, Assign, Split Summary, Settle Up, Recurring Bills, Ledger, History, Stats, Members, Privacy) | Mostly matches prototypes ✅ |
| AI feature | On-device OCR via `google_mlkit_text_recognition` + regex `receipt_parser.dart` | Needs AI labeling, user override, fallback, and a stronger "why AI" story |
| Code organization | **3,210 lines in `lib/main.dart`** | ❌ Must split into `screens/`, `services/`, `models/`, `widgets/` |
| Data persistence | Hard-coded mock data (`people`, `items`, `shares`) | ❌ No storage at all |
| Async states | A few spinners | ❌ Need loading / empty / error states on every data screen |
| Forms & validation | 3 `validator:`s exist | ⚠️ Polish error messages; make one "showcase" form |
| Comments | Sparse | ❌ Required on every significant class/method |
| Git | Repo has **no commits**, single branch | ❌ Need feature branches + reviewed PRs from **all** members |
| README | Default Flutter template | ❌ Needs setup and run instructions |
| Tests | 3 test files | ✅ Keep and extend |

**Conclusion:** the UI is the easy part and it's mostly done. The remaining work is **architecture, persistence, AI hardening, and visible collaboration history.**

---

## 2. Core features (scope)

The minimum is 3 to 6 core features depending on team size. Login, splash, About, and Settings **don't count**. Below are 7 candidates. Pick at least your required number plus one as a buffer.

| # | Core feature | Input → processing → result | Existing screens |
|---|---|---|---|
| F1 | **AI Receipt Scanner** (AI feature) | Photo → OCR + AI item extraction → editable list of items and prices | `ScanReceipt`, `CameraCapture` |
| F2 | **Create bill / manual entry** | Form (items, prices, payer) → validated → saved bill | `ManualReceiptEntry` |
| F3 | **Assign items & split** | Tap items per member → compute shares (equal, by item, + service/tax) → split summary | `AssignItems`, `SplitSummary` |
| F4 | **Settle up & track payments** | Mark paid, attach proof, send reminder → balances update | `SettleUp`, payment dialogs |
| F5 | **Group & member management** | Create group, add/invite members → persisted group | `GroupDetail`, `Members`, `InviteMembers` |
| F6 | **Recurring bills** | Form (name, amount, cycle) → schedule → auto-listed dues | `RecurringBills` |
| F7 | **History, ledger & stats** | Search/filter past bills → per-person ledger + charts | `ActivityHistory`, `PersonalLedger`, `Statistics` |

---

## 3. Target architecture

### 3.1 Folder structure (required: organized by purpose)

```
lib/
├── main.dart                  # runApp + Firebase init only
├── app.dart                   # MaterialApp, theme, routes
├── routes.dart                # named routes table
├── models/                    # Person, Group, Bill, ReceiptItem, Payment, RecurringBill
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart # CRUD for groups/bills/payments
│   ├── ocr_service.dart       # ML Kit wrapper (existing receipt_ocr*.dart)
│   ├── ai_receipt_service.dart# Gemini structuring + timeout + fallback
│   └── split_calculator.dart  # pure Dart share math (unit-tested)
├── state/                     # ChangeNotifiers / providers per feature
├── screens/
│   ├── onboarding/  home/  group/  scan/  bill/  settle/  recurring/  history/  settings/
├── widgets/                   # Avatar, Box, Btn, Pill, AppPage, + AsyncStateView, AiBadge
├── theme/                     # app_colors.dart, app_theme.dart
└── utils/                     # currency formatting, validators, receipt_parser.dart
```

### 3.2 Tech stack (recommended)

| Need | Package | Why |
|---|---|---|
| State management | `provider` | Simple, course-friendly, easy to defend |
| Navigation | Named routes (or `go_router`) | Smooth, explicit navigation for the matrix |
| Auth | `firebase_auth` | Email/anonymous sign-in; identifies group members |
| Database | `cloud_firestore` | Persistence + real-time sync across group members, offline cache built in |
| Proof-of-payment images | `firebase_storage` + `image_picker` | Upload GCash/Maya screenshots |
| OCR (on-device AI) | `google_mlkit_text_recognition` (already in) | Reads text off the receipt photo, works offline |
| AI structuring | `firebase_ai` (Firebase AI Logic → Gemini) | Turns messy OCR text into clean items. **No API key lives in the app or repo.** |
| Camera | `camera` (already in) | Receipt capture |
| Charts | `fl_chart` | Statistics screen |
| Local prefs | `shared_preferences` | Onboarding-seen flag, last group |

> Alternative if Firebase setup is a blocker: `hive`/`sqflite` for local persistence. You lose multi-user sync, but it still satisfies requirement (d).

### 3.3 Firestore data model

```
users/{uid}                 name, initials, color, paymentMethod
groups/{groupId}            name, memberIds[], createdBy, createdAt
  bills/{billId}            title, payerId, totalCents, serviceTaxCents,
                            source: "ai" | "manual", aiEdited: bool, createdAt
    items/{itemId}          name, amountCents, assignedTo[], aiGenerated: bool
  payments/{paymentId}      fromId, toId, amountCents, method, proofUrl, status, paidAt
  recurring/{id}            name, amountCents, cycle, nextDue
```

Store money as **integer centavos** (already done in the code; keep it).

---

## 4. AI feature specification (draft for the docs)

**Feature:** AI Receipt Scanner (F1)

**Pipeline**
1. User snaps or picks a receipt photo.
2. **ML Kit OCR (on-device)** extracts raw text.
3. **Gemini via Firebase AI Logic** receives *only the OCR text* (not the image, not names) with a prompt such as:
   > "Extract line items from this restaurant receipt. Return JSON: `{items:[{name, price}], serviceCharge, tax, total}`. Prices in PHP. Ignore header, address, VAT ID, and change lines."
4. The JSON is validated: items must have a positive price, and the sum must be within ±2% of the total. Otherwise the result counts as unusable.
5. Results are shown with an **"✨ AI-detected"** badge. Every row is editable or deletable, and users can add items they missed.

**Graceful failure (requirement c)**

| Situation | Behavior |
|---|---|
| Processing | Step indicator: "Reading receipt…" → "Organizing items…" |
| Gemini timeout (>10 s) / no internet / quota | Fall back to the existing **regex `receipt_parser.dart`**, plus a banner: "AI unavailable, used basic detection" |
| OCR finds nothing / bad JSON / totals don't match | Message "Couldn't read this receipt" with **Retake** and **Enter manually** buttons (→ F2) |
| Camera not supported (web/Windows) | Hide camera and go straight to manual entry |

**Why AI instead of plain logic:** receipts differ in layout, abbreviations, multi-line items, and quantity formats ("Rice x5", "2 @ 150.00"). Regex breaks on unseen formats. OCR + LLM generalizes. Keep the regex parser as the baseline so you can **show the difference in the demo.**

**Privacy (RA 10173):** only the text is sent, never the photo. No names, phone numbers, or locations are sent. Receipt images are not stored unless the user attaches them as payment proof. A Privacy screen (already exists) explains this. Users can delete bills and their account.

**Security:** add `firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`, `.env`, and `*.keystore` to `.gitignore`, and give teammates the files privately. Enable **Firebase App Check** to protect the AI endpoint.

---

## 5. Minimum technical requirements checklist

| Req. | How BahinKo meets it | Where |
|---|---|---|
| a. Value / Layout / Interaction / Navigation widgets | Text, Image, Icon / Column, Row, Stack, ListView, GridView / Buttons, TextFormField, Checkbox, Dismissible / Navigator, BottomNavigationBar, Dialogs, BottomSheets | All screens |
| b. Smooth navigation | Named routes, `Hero` on bill cards, bottom nav `Shell` keeps state with `IndexedStack` | `routes.dart`, `Shell` |
| c. Form + validation | **Manual Receipt Entry**: required fields, price regex, ≥1 item, inline error text, disabled Save until valid. Also Add Member and Add Recurring Bill | `screens/bill/manual_entry_screen.dart` |
| d. Persistence | Firestore (+ offline cache), `shared_preferences` | `services/` |
| e. Async loading / empty / error | Reusable `AsyncStateView` widget used for every `StreamBuilder`/`FutureBuilder` | `widgets/async_state_view.dart` |
| f. Folders + comments | Structure in §3.1; `///` doc comment on each class and public method | Everywhere |

---

## 6. Team roles (feature ownership)

Each member **owns a vertical slice** (screen → state → service), so everyone has substantial commits they can explain in the Individual Code Defense.

| Member | Owns | Also responsible for |
|---|---|---|
| **M1 – Lead** | Refactor/architecture, auth, F5 Groups & Members | Repo setup, PR reviews, README, final merge PR |
| **M2** | **F1 AI Receipt Scanner** (OCR + Gemini + fallback) | AI Feature Spec section of the docs |
| **M3** | F2 Manual entry form + F3 Assign & Split (`split_calculator` + tests) | Forms/validation row of the Topic Matrix |
| **M4** | F4 Settle Up (payments, proof upload, reminders) | Presentation deck + demo video |
| **M5** | F6 Recurring bills + F7 History/Ledger/Stats | Screenshots, Topic Coverage Matrix |

*Smaller team?* For 4 members, merge M5 into M3/M4 and drop F7 or F6. For 3 members, ship F1 to F4 (4 features). For 2 members, ship F1 to F3.

---

## 7. Timeline (4 weeks)

### Week 1: Foundation (Nov 23 – Nov 29)
- [ ] M1: Initial commit of current code to `main`; create the class-org fork; set branch protection (1 review required)
- [ ] M1: Fix `.gitignore` for Firebase/secret files; create Firebase project; share config privately
- [ ] **All:** Refactor: each member moves *their own screens* out of `main.dart` into `screens/` (this gives everyone early commits)
- [ ] M1: Add `models/`, `provider`, named routes, `AsyncStateView`
- [ ] M3: Extract share math into `split_calculator.dart` + unit tests
- **Exit criteria:** app runs identically to now, `main.dart` < 50 lines

### Week 2: Persistence & core flows (Nov 30 – Dec 6)
- [ ] M1: Auth + Firestore service; F5 create group / add members persisted
- [ ] M2: `ocr_service` + `ai_receipt_service` (Gemini call, JSON validation, timeout)
- [ ] M3: Manual entry form saving bills; Assign & Split reading from Firestore
- [ ] M4: Payments collection; mark paid; balances computed from data
- [ ] M5: Recurring bills CRUD
- **Exit criteria:** no more mock data on F1 to F5 screens

### Week 3: AI hardening & polish (Dec 7 – Dec 13)
- [ ] M2: Fallback chain, AI badge, editable results, failure messages; test on 10+ real receipts (log results for "known failure cases")
- [ ] M4: Proof-of-payment upload, reminder sheet
- [ ] M5: History search/filter, ledger, stats charts
- [ ] **All:** Loading/empty/error states on every screen; doc comments; widget tests for your feature
- [ ] Check the UI against the hi-fi prototype and fix differences
- **Exit criteria:** feature freeze, full demo runs end-to-end on a real phone

### Week 4: Docs, presentation, defense prep (Dec 14 – Dec 20)
- [ ] Documentation (section owners in §6); AI Usage Log filled in **as you go**, not at the end
- [ ] Individual reflections (**each member writes their own, no AI**)
- [ ] Slides (5–10 min): problem → client → features → screenshots → live demo → limitations/future
- [ ] Record backup demo video
- [ ] **Code-defense drill:** each member explains their files and practices a live change (add a form field, change a navigation target)
- [ ] Final PR to the main org repo

---

## 8. Git workflow

- Branches: `feature/ai-scanner`, `feature/settle-up`, `refactor/split-screens`, `fix/…`
- Commits: `feat(scan): add Gemini fallback to regex parser`. Keep them small and frequent, **spread across all weeks** (graders read the history).
- PRs: one feature per PR, with at least 1 teammate review and a short description + screenshot. No direct pushes to `main`.
- Note: the current local repo root is the parent `BahinKo/` folder, with the Flutter app nested inside it and an unrelated `.github/modernize/` folder. **Make the Flutter project folder the repo root** when pushing to the class org.

---

## 9. Documentation outline (maps 1:1 to the rubric)

1. Overview & Introduction: name, purpose, target client, tech stack **with versions** (`flutter --version`, `pubspec.lock`)
2. Functional Requirements: packages + purpose, lo-/hi-fi prototypes, core features with screenshots, **Topic Coverage Matrix**, AI Feature Spec (§4)
3. Future Enhancements: limitations + roadmap
4. Appendix A: AI Usage Log (Member | Date | Tool | Purpose | Generated | What was changed)
5. Appendix B: Individual reflections (~½ page each: what I built, one bug I fixed, what I'd do differently)

**Target client (suggestion):** a real barkada, dorm, or student org that splits bills, e.g., "WVSU dormers sharing utility bills and group meals." Interview 3 to 5 of them and quote their pain points ("chasing GCash payments", "manual computation of service charge") in the Background slide.

---

## 10. Known limitations (draft) & future work

- **Limitations:** OCR struggles with faded thermal receipts and handwritten bills; AI needs internet; payments are *recorded* only, not processed; camera scanning is mobile-only.
- **Future:** GCash/Maya deep links, push-notification reminders, multi-currency for travel, AI spending insights ("you spent 40% on food this month"), Tagalog/Hiligaynon receipt support.

---

## 11. Top risks

| Risk | Mitigation |
|---|---|
| Firebase setup eats Week 2 | M1 sets it up in Week 1; Hive fallback |
| Only 1–2 people commit | Feature-ownership table; each member refactors their own screens in Week 1 |
| AI demo fails live (Wi-Fi) | Fallback is part of the design, so demo it on purpose; backup video |
| Members can't explain AI-assisted code | Log every AI use; do a defense drill in Week 4 |
| Secrets committed | `.gitignore` before the first push; App Check; run `git log -p \| grep -i key` before the final PR |
