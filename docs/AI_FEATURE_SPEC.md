# AI Feature Specification: Receipt Scanner

*BahinKo, CC 207B Final Project. This section goes into the software documentation.*

## 1. What the feature does

The user photographs a restaurant or store receipt. BahinKo lists every item with its price, plus the service charge and VAT, so the group can split the bill without typing anything. Items the AI is unsure about are marked **"Needs review"**, and the user can fix, remove, or add any item before splitting.

**Screens:** Scan Receipt (Figma 7) → Scanning (8) → Assign Items (9) → Edit Item sheet (10).

## 2. AI service, model, and packages

| Part | What we use | Version |
|---|---|---|
| Text recognition (on the phone, offline) | Google ML Kit Text Recognition, `google_mlkit_text_recognition` | 0.15.1 |
| Item extraction (cloud AI) | **Gemini 3.5 Flash-Lite** via **Firebase AI Logic** (Gemini Developer API), `firebase_ai` | 5.2.0 |
| Request protection | Firebase App Check, `firebase_app_check` (debug provider; Play Integrity when published) | 0.5.2 |
| Fallback parser | Our own rule-based parser (`utils/receipt_parser.dart`) | — |

**Why this model:** reading a receipt is a simple task, so we chose the fastest, lowest-cost Gemini model. Older Gemini 2.5 models are closed to new projects (checked November 2026).

**Code:** `lib/services/receipt_ai_service.dart` (Gemini call, prompt, JSON schema), `lib/services/receipt_scanner.dart` (pipeline, checks, fallbacks).

## 3. Inputs and prompt

**Input:** the text that ML Kit read from the photo, after removing personal data (see §7). **The photo itself is never sent.**

**System instruction (summary; the full text is in `GeminiReceiptAi.systemPrompt`):**
- The input is OCR text from Philippine receipts: fix obvious OCR typos and merge items broken across lines.
- For each item, return the **line total** (e.g. "Rice x5 @ 50.00 → 250.00").
- Return the service charge, VAT, discount, and total separately. Prices in the Philippines usually **already include VAT**, so set `vat` only if it's added on top.
- Give a **confidence** for each item. If any digit of the price was guessed, confidence must be **below 0.6**.
- Ignore subtotal, cash, change, codes, TIN, addresses, and dates. **Never invent items**, and return no items if the text isn't a receipt.

**Structured output:** the request sets `responseMimeType: application/json` and a `responseSchema`, so Gemini must answer in exactly this shape:
```json
{ "storeName": "…", "items": [{ "name": "…", "price": 0.0, "confidence": 0.0 }],
  "serviceCharge": 0.0, "vat": 0.0, "discount": 0.0, "total": 0.0 }
```
`temperature: 0` gives the same answer for the same receipt.

## 4. Sample outputs (real Gemini results, November 23, 2026)

| Receipt (OCR text) | Gemini output | App result |
|---|---|---|
| **Samgyup House** (OCR typo "S0JU X3") | 4 items, "SOJU X3" (typo fixed), service ₱250, VAT ₱350, total ₱2,500 | ✅ Adds up exactly |
| **Fast food** ("2 @ 85.00" quantities, pie name on 2 lines, cash/change, senior discount, card number) | Chickenjoy ₱170, Spaghetti ₱65, Peach Mango Pie ₱120 (lines merged), discount ₱13, total ₱342. Cash and change were ignored. | ✅ Matches. The app says "This receipt has a ₱13.00 discount. Edit the item it applies to." |
| **Grocery** (item codes, abbreviations, "VATable sales / VAT amount" lines) | 4 items, codes removed, VAT = 0 (already included), total ₱445.25 | ✅ Adds up exactly |
| **Badly scanned** ("15S.00", "1?5.00") | Carrot cake ₱155 and Latte ₱175, each at **confidence 0.50** | ⚠️ Both marked **Needs review**, plus "Items add up to ₱450.00, but the receipt says ₱350.00" |
| **Not a receipt** (a meeting reminder) | No items | ✅ "No items found. Retake the photo or enter the items manually." |

**Response time:** usually 2–5 seconds; occasionally 10–25 seconds when Google's servers are busy.

## 5. How failures are handled (graceful failure)

```
photo → OCR on the phone ──(no text)──────────────→ "No text found. Retake in good light…"
      → mask personal data
      → Gemini (15 s limit, 1 retry if it fails fast)
           ├─ OK → our checks ──(unusable)──┐
           ├─ timeout ─────────────────────┤
           └─ error / quota / no internet ──┤
                                            ▼
                         basic rule-based parser ──(nothing)──→ "No items found…"
                         + orange banner                       [Retake] [Enter manually]
                         "…so basic detection was used.
                          Please check every item."
```

| Situation | What the user sees |
|---|---|
| Waiting | Moving scan line + "Reading your receipt…" → "Organizing items with AI…" |
| AI unsure about an item | Orange border + **Needs review** pill; "N items need review: tap to fix" |
| Items ≠ printed total | Banner: "Items add up to ₱X, but the receipt says ₱Y. Check the items before splitting." |
| Discount on receipt | Banner telling the user to apply it to the right person's item |
| AI slow, down, out of quota, or no internet | Basic detection is used, with a banner saying so (label "Basic detection" instead of "AI-detected") |
| Nothing found at all | Error screen with **Retake photo** and **Enter manually** |
| Confirm with unreviewed items | Dialog: "Some items need review. Split anyway?" |
| Web/Windows (no phone camera OCR) | Scan button disabled with "Receipt scanning works in the Android app"; manual entry still works |

## 6. Known failure cases and limits

- **Discounts aren't split automatically.** Senior and PWD discounts belong to one person, so the app asks the user to apply them.
- **Guessed digits:** on blurry receipts Gemini may guess a digit (e.g. "15S" → 155). These are flagged for review, but the user must check them.
- **Handwritten or faded thermal receipts:** ML Kit may read little or nothing, which leads to "No text found".
- **Free-plan limits:** the Gemini free tier allows only a few requests per minute. Many scans in a row hit the limit ("quota exceeded"), and the app falls back to basic detection.
- **Busy servers:** Google sometimes returns "high demand". The app retries once, then falls back.
- **Item names** are sometimes left abbreviated ("SGR WHT 1KG"). Users can rename them in the Edit sheet.
- **Store names** with OCR errors aren't always fixed ("K4P3 B4R4K0").

## 7. Why AI is the right tool here

Receipt layouts differ for every shop: columns, abbreviations, quantity formats ("Rice x5", "2 @ 85.00"), items split across lines, VAT shown differently, and OCR typos. Our rule-based parser only handles "name … price" on one line. On the fast-food receipt it can't join "PEACH MANGO / PIE", it reads the senior discount and the card number as items, and it can't tell VAT-inclusive from VAT-exclusive receipts. Writing rules for every format is impossible. A language model reads the receipt the way a person would, and our own checks (totals, confidence) catch its mistakes. We keep the rule-based parser as the fallback, so the app still works without the AI.

## 8. Security and privacy (RA 10173)

- **No API keys in the code or repo.** Firebase AI Logic keeps the Gemini key on Google's side.
- **App Check is enforced:** requests without a valid App Check token are refused, so nobody can use our AI quota from a script. The team's debug token lives in `lib/secrets.dart`, which isn't in git.
- **Data minimization:** only the receipt **text** is sent, never the photo. Before sending, `redactForAi()` masks long number sequences (card, account, phone, TIN) and email addresses. No names are sent.
- **Not stored by us:** the receipt text isn't saved in our database; only the final items the user confirms are saved with the expense. AI monitoring (which can log prompts) was left **off** on purpose.
- **Labeled and correctable:** AI results show an **"AI-detected"** label, unsure items are flagged, and every item can be edited, removed, or added before anything is saved.

## 9. Tests

`test/receipt_ai_test.dart` (17 tests, fake AI, no internet needed):
- reading the AI's JSON, and rejecting bad answers;
- masking card numbers, phone numbers and emails while keeping prices;
- flagging low-confidence items, the totals-mismatch warning, and the discount message;
- the fallbacks (AI error, timeout, unusable answer, nothing found) and the retry when the AI is busy;
- the screens: Scanning → Assign Items with labels, fixing an item in the Edit sheet, the error screen, and the "Split anyway?" dialog.
