# BahinKo

**Bahinko nang tama, bayad nang kaunti.** Split bills with friends without the awkward math.

BahinKo is a Flutter app for groups (barkadas, dormmates, boarding houses) who share expenses. Scan a receipt and the app lists the items, assign who ordered what, see each person's share, and track who has paid, with polite reminders and GCash/Maya hand-off.

*CC 207B Final Project, West Visayas State University CICT.*

---

## Features

| Feature | Status |
|---|---|
| Sign in (anonymous, no email/password), your name, 4-digit app lock with fingerprint | ✅ |
| Create groups from templates, invite by **QR code / link / code**, add guests without the app | ✅ |
| Live group data shared between phones (Firebase), with loading / empty / error states | ✅ |
| **AI receipt scanner**: on-device OCR + Gemini item extraction, "Needs review" flags, editable items, fallbacks ([spec](docs/AI_FEATURE_SPEC.md)) | ✅ |
| Save scanned/typed receipts to a group (split equally, choose who paid), live split summary | ✅ |
| Add Expense form: Equal / By item / Exact / Percent / Shares (Frame 6) | ✅ |
| Partial payments on Settle Up ("Pay part of it" / "Got part of it") | ✅ |
| Report Preview with PDF / CSV export (Frame 23) | ✅ |
| Profile & settings: app lock, wallets, reminders, offline mode, log out (Frame 24) | ✅ |
| Edit / delete an expense (logged in activity) | ✅ |
| Settle up from real balances: smart settle (fewest transfers), GCash/Maya/cash, receiver confirms, reminders; live Home balances | ✅ |
| Recurring bills, activity history, personal ledger, statistics | 🚧 M5 |

---

## Tech stack

| | Version |
|---|---|
| Flutter | 3.47.9 (stable) |
| Dart | 3.13.7 |
| Firebase: `firebase_core` / `firebase_auth` / `cloud_firestore` | 5.2.0 / 7.1.0 / 7.2.0 |
| Camera + on-device OCR: `camera` / `google_mlkit_text_recognition` | 0.12.2 / 0.15.1 |
| AI: `firebase_ai` (Gemini 3.5 Flash-Lite) / `firebase_app_check` | 5.2.0 / 0.5.2 |
| QR: `mobile_scanner` / `qr_flutter` | 7.5.0 / 4.1.0 |
| Security: `flutter_secure_storage` / `local_auth` / `crypto` | 11.2.0 / 3.0.2 / 3.0.8 |
| Storage & sharing: `shared_preferences` / `share_plus` | 2.5.6 / 13.3.1 |

Exact versions of everything are pinned in `pubspec.lock`.

---

## Setup

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) **3.47** or newer (`flutter --version`)
- Android Studio (for the Android SDK) or an Android phone with **USB debugging** on
- Node.js (only if you need to deploy database rules)

### 2. Get the code
```bash
git clone https://github.com/gxeng-8/BahinKo.git
cd BahinKo
flutter pub get
```

### 3. Add the Firebase config (not in git)
For security, Firebase config files are **not committed** (see `.gitignore`). Do one of these:

- **Option A (teammates):** ask the team lead for these three files and put them here:
  - `lib/firebase_options.dart`
  - `android/app/google-services.json`
  - `lib/secrets.dart`: the App Check token that lets your phone use the AI scanner
- **Option B:** if you've been added to the Firebase project:
  ```bash
  npm install -g firebase-tools
  firebase login
  dart pub global activate flutterfire_cli
  flutterfire configure --project=bahinko-303f2 --platforms=android,web --android-package-name=com.bahinko.app
  ```

Without these files the app won't compile. With Option B, also ask the lead for `lib/secrets.dart`.

### 4. Run
```bash
flutter devices          # list phones / browsers
flutter run              # Android phone (recommended: camera, fingerprint)
flutter run -d chrome    # quick check in the browser (no camera scanning of receipts)
```
On the phone: **Get Started → your name → create a PIN → Home**.

### 5. Test
```bash
dart analyze             # should print: No issues found!
flutter test             # widget + unit tests (no Firebase needed)
```

---

## Project structure

```
lib/
├── main.dart              # starts Firebase, picks the real services, runs the app
├── app.dart               # theme, first screen, re-lock after background
├── models/                # Group, Person, GroupExpense, Payment, ActivityEvent, …
├── services/              # backend: AuthService, GroupService (Firestore), AppLock, Settings
├── data/                  # sample data + in-memory GroupService used by tests
├── screens/               # one folder per feature (auth, home, group, bill, scan, settle, …)
├── widgets/               # shared UI: Btn, Pill, AppPage, AsyncStateView, InfoBanner, …
├── theme/                 # colors and text styles from the Figma prototype
└── utils/                 # currency, validators, split math, receipt parsing
test/                      # tests; services are swapped for in-memory fakes
docs/                      # development plan, Figma build guide, backend integration guide
firestore.rules            # database security rules
```

Screens never call Firebase directly. They use services (`GroupService.instance`, `AuthService.instance`), which tests replace with in-memory versions.

---

## Backend & security

- **Firebase Authentication (anonymous):** no email or phone collected, only a first name (Data Privacy Act, RA 10173).
- **Cloud Firestore**, with rules in [`firestore.rules`](firestore.rules):
  - only group members can read or change a group;
  - joining requires the group's invite code and lets you add only yourself;
  - only the receiver can confirm a payment;
  - activity history can't be edited.

  Deploy rule changes with:
  ```bash
  firebase deploy --only firestore:rules --project bahinko-303f2
  ```
- **App lock:** the PIN is stored only as a salted SHA-256 hash in encrypted device storage. 5 wrong tries pause the keypad for 30 seconds, and the pause survives restarts.
- **AI:** only receipt text is sent (never the photo), with card/phone numbers and emails masked. App Check is enforced, so only the real app can use the AI. See [`docs/AI_FEATURE_SPEC.md`](docs/AI_FEATURE_SPEC.md).
- **No secrets in git:** Firebase config files, `lib/secrets.dart` and keystores are in `.gitignore`.

---

## Documentation

- [`docs/DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md): scope, timeline, roles
- [`docs/BUILD_GUIDE.md`](docs/BUILD_GUIDE.md): Figma frames → screens, per member
- [`docs/TEAM_INTEGRATION.md`](docs/TEAM_INTEGRATION.md): connecting screens to the backend
- [`docs/AI_FEATURE_SPEC.md`](docs/AI_FEATURE_SPEC.md): the AI feature (model, prompt, sample outputs, failures, privacy)

## Team

| Member | Role |
|---|---|
| M1 (lead) | App shell, groups, invites, app lock, Firebase backend |
| M2 | AI receipt scanner |
| M3 | Add expense, split summary, reports, profile |
| M4 | Settle up and payments |
| M5 | Recurring bills, activity, ledger, statistics |

## Known limitations

- Invite links (`bahinko.app/j/…`) don't open the app yet. Paste the code/link or scan the QR code instead.
- GCash/Maya don't offer public links that pre-fill an amount; the amount is copied for you.
- With anonymous accounts there's no "Forgot PIN?" recovery; clearing the app's data starts fresh.
