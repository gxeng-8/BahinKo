/// The AI part of the receipt scanner: turns messy OCR text into clean,
/// structured receipt items using Gemini (through Firebase AI Logic).
///
/// WHY AI (for the docs / defense): receipts differ in layout, abbreviations,
/// multi-line items, and quantity formats ("Rice x5", "2 @ 150.00",
/// "PRK BLLY ST"). Fixed rules (regex) break on every new format; a
/// language model understands them. The regex parser is still kept as the
/// fallback when the AI is unavailable.
///
/// SECURITY: no API key in the app or repo. Firebase AI Logic signs the
/// request with the Firebase project, and the Gemini key stays on Google's
/// servers.
///
/// PRIVACY (RA 10173): only the receipt TEXT is sent, never the photo, and
/// long number sequences (card/account/phone numbers) and emails are masked
/// first by [redactForAi].
library;

import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

/// One item as the AI read it, before our own checks.
class AiReceiptItem {
  const AiReceiptItem(this.name, this.priceCents, this.confidence);

  final String name;
  final int priceCents;

  /// 0.0–1.0: how sure the AI is that it read this line correctly.
  final double confidence;
}

/// Everything the AI extracted from one receipt.
class AiReceipt {
  const AiReceipt({
    required this.storeName,
    required this.items,
    this.serviceChargeCents = 0,
    this.vatCents = 0,
    this.totalCents,
  });

  final String storeName;
  final List<AiReceiptItem> items;
  final int serviceChargeCents;
  final int vatCents;

  /// The TOTAL printed on the receipt, if the AI found one.
  final int? totalCents;
}

/// Anything that turns receipt text into an [AiReceipt]. Tests use a fake.
abstract class ReceiptAi {
  /// Throws on any failure (network, quota, bad answer); the scanner then
  /// falls back to the basic parser.
  Future<AiReceipt> extract(String receiptText);
}

/// The real thing: Gemini through Firebase AI Logic.
class GeminiReceiptAi implements ReceiptAi {
  /// A fast, low-cost model; reading receipts doesn't need a big one.
  static const modelName = 'gemini-2.5-flash';

  // Created lazily so tests never touch Firebase.
  late final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    model: modelName,
    systemInstruction: Content.system(systemPrompt),
    generationConfig: GenerationConfig(
      temperature: 0, // same receipt → same answer
      // Structured output: the model MUST answer with JSON in this shape,
      // so we never have to guess how to read its reply.
      responseMimeType: 'application/json',
      responseSchema: receiptSchema,
    ),
  );

  /// Instructions sent with every request.
  static const systemPrompt = '''
You read restaurant and store receipts from the Philippines.
The input is text from on-device OCR, so it may have typos, broken lines,
and merged columns.

Extract:
- storeName: the shop name at the top (or "Receipt" if unclear).
- items: every purchased line item, with the LINE TOTAL in pesos
  (for "Rice x5 @ 50.00  250.00" the price is 250.00). Fix obvious OCR
  typos in names ("P0RK" → "Pork"). Merge an item split across two lines.
- serviceCharge and vat: amounts if printed, else 0. Do NOT also list them
  as items.
- total: the final TOTAL / AMOUNT DUE printed on the receipt, or null.
- confidence for each item: 1.0 if clearly readable, lower if you had to
  guess the name or the price.

Ignore: subtotal, cash tendered, change, discounts lines, table numbers,
addresses, TIN/VAT registration numbers, dates, and thank-you messages.
Never invent items that aren't in the text.
''';

  /// The JSON shape Gemini must return.
  static final receiptSchema = Schema.object(
    properties: {
      'storeName': Schema.string(),
      'items': Schema.array(
        items: Schema.object(
          properties: {
            'name': Schema.string(),
            'price': Schema.number(description: 'Line total in pesos'),
            'confidence': Schema.number(minimum: 0, maximum: 1),
          },
        ),
      ),
      'serviceCharge': Schema.number(),
      'vat': Schema.number(),
      'total': Schema.number(nullable: true),
    },
    optionalProperties: ['total'],
  );

  @override
  Future<AiReceipt> extract(String receiptText) async {
    final response = await _model.generateContent([
      // Already privacy-masked by ReceiptScanner (see redactForAi).
      Content.text(receiptText),
    ]);
    final json = response.text;
    if (json == null || json.trim().isEmpty) {
      throw const FormatException('The AI returned an empty answer.');
    }
    return parseAiReceiptJson(json);
  }
}

/// Converts the AI's JSON answer into an [AiReceipt].
/// Throws [FormatException] if the answer isn't usable JSON.
AiReceipt parseAiReceiptJson(String json) {
  final data = jsonDecode(json);
  if (data is! Map<String, dynamic>) {
    throw const FormatException('The AI answer is not a JSON object.');
  }
  int cents(Object? pesos) =>
      pesos is num ? (pesos * 100).round() : 0; // ₱12.50 → 1250
  return AiReceipt(
    storeName: (data['storeName'] as String?)?.trim().isNotEmpty == true
        ? (data['storeName'] as String).trim()
        : 'Receipt',
    items: [
      for (final raw in data['items'] as List? ?? const [])
        if (raw is Map<String, dynamic>)
          AiReceiptItem(
            (raw['name'] as String? ?? '').trim(),
            cents(raw['price']),
            (raw['confidence'] as num?)?.toDouble().clamp(0, 1) ?? 0.5,
          ),
    ],
    serviceChargeCents: cents(data['serviceCharge']),
    vatCents: cents(data['vat']),
    totalCents: data['total'] is num ? cents(data['total']) : null,
  );
}

/// Masks personal data before the text leaves the phone:
/// long digit runs (card, account, phone, TIN numbers) and email addresses.
/// Prices like "1,250.00" are short and stay readable.
String redactForAi(String text) => text
    .replaceAll(RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'), '[email]')
    .replaceAll(RegExp(r'(?:\d[\s-]?){9,}\d'), '[number]');
