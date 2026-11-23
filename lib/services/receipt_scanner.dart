/// The full receipt-scanning pipeline (the app's AI feature):
///
///   photo ──► 1. on-device OCR (ML Kit) ──► text
///         ──► 2. AI (Gemini) organizes the text into items ──► checked
///         ──► fallback A: basic regex parser if the AI fails or times out
///         ──► fallback B: ScanFailure → the screen offers manual entry
///
/// Graceful failure (course requirement c): every step has a time limit,
/// every error becomes a plain-language message, and there is always a
/// way forward (basic detection or typing the items).
library;

import 'dart:async';

import 'package:bahinko/models/expense.dart';
import 'package:bahinko/services/receipt_ai_service.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/receipt_ocr.dart';
import 'package:bahinko/utils/receipt_parser.dart';

/// Which step is running, shown on the Scanning screen (Figma 8).
enum ScanStage { reading, organizing }

/// Who produced the items: the AI, or the basic fallback parser.
enum ScanSource { ai, basic }

/// The scanner's answer: items ready for the Assign Items screen.
class ScanResult {
  const ScanResult({
    required this.storeName,
    required this.items,
    required this.source,
    this.warning,
  });

  final String storeName;

  /// Includes "Service charge" and "VAT" as items (split among everyone).
  final List<ExpenseItem> items;
  final ScanSource source;

  /// Shown in an orange banner, e.g. "2 items need review" or why the
  /// fallback was used. Null when everything looks right.
  final String? warning;

  int get totalCents => items.fold(0, (sum, i) => sum + i.amountCents);
  int get needsReviewCount => items.where((i) => i.needsReview).length;
}

/// A scan that produced nothing usable. [message] is safe to show.
class ScanFailure implements Exception {
  const ScanFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class ReceiptScanner {
  ReceiptScanner({
    this.customAi,
    Future<String?> Function(String imagePath)? ocr,
    this.aiTimeout = const Duration(seconds: 10),
  }) : _ocr = ocr ?? recognizeReceiptText;

  /// The scanner the app uses. Tests replace it (fake OCR and AI).
  static ReceiptScanner instance = ReceiptScanner();

  /// Items the AI is less sure about than this get "Needs review".
  static const reviewBelowConfidence = 0.7;

  /// Optional AI to use instead of Gemini (tests pass a fake).
  final ReceiptAi? customAi;
  final Future<String?> Function(String imagePath) _ocr;
  final Duration aiTimeout;

  // Created on first use, so building a ReceiptScanner never touches Firebase.
  ReceiptAi get ai => customAi ?? (_gemini ??= GeminiReceiptAi());
  static GeminiReceiptAi? _gemini;

  /// Scans a receipt photo. [onStage] tells the UI what's happening.
  /// Throws [ScanFailure] if nothing usable was found.
  Future<ScanResult> scanImage(
    String imagePath, {
    void Function(ScanStage stage)? onStage,
  }) async {
    onStage?.call(ScanStage.reading);
    String? text;
    try {
      text = await _ocr(imagePath).timeout(const Duration(seconds: 20));
    } on UnsupportedError {
      throw const ScanFailure(
        'Receipt scanning works in the Android app. Enter the items manually.',
      );
    } on TimeoutException {
      throw const ScanFailure('Reading the photo took too long. Try again.');
    } catch (_) {
      throw const ScanFailure("Couldn't read the photo. Try again.");
    }
    if (text == null || text.trim().length < 5) {
      throw const ScanFailure(
        'No text found. Retake the photo in good light with the whole '
        'receipt in view.',
      );
    }
    onStage?.call(ScanStage.organizing);
    return analyzeText(text);
  }

  /// Steps 2+: AI first, then the basic parser. Public so it can be
  /// tested without a camera.
  Future<ScanResult> analyzeText(String text) async {
    String reason;
    try {
      // Privacy: mask card/phone numbers and emails BEFORE any AI sees it.
      final answer = await ai.extract(redactForAi(text)).timeout(aiTimeout);
      final checked = reviewAiReceipt(answer);
      if (checked != null) return checked;
      reason = "The AI's answer didn't look right";
    } on TimeoutException {
      reason = 'The AI took too long';
    } catch (_) {
      reason = 'The AI is unavailable right now';
    }

    // Fallback A: the basic rule-based parser.
    final basic = parseReceiptItems(text);
    if (basic.isEmpty) {
      throw const ScanFailure(
        'No items found on this receipt. Retake the photo or enter the '
        'items manually.',
      );
    }
    return ScanResult(
      storeName: 'Scanned receipt',
      source: ScanSource.basic,
      items: [
        for (final (name, cents) in basic)
          ExpenseItem(name: name, amountCents: cents),
      ],
      warning: '$reason, so basic detection was used. Please check every item.',
    );
  }
}

/// Checks the AI's answer before the app trusts it.
///
/// Returns null if it's unusable (nothing found, or mostly missing prices)
/// so the scanner falls back. Otherwise marks shaky items "Needs review"
/// and warns when the items don't add up to the receipt's total.
ScanResult? reviewAiReceipt(AiReceipt answer) {
  final named = answer.items.where((i) => i.name.isNotEmpty).toList();
  if (named.isEmpty) return null;
  final missingPrice = named.where((i) => i.priceCents <= 0).length;
  if (missingPrice * 2 > named.length) return null; // mostly unreadable

  final items = <ExpenseItem>[
    for (final i in named)
      ExpenseItem(
        name: i.name,
        amountCents: i.priceCents < 0 ? 0 : i.priceCents,
        aiGenerated: true,
        needsReview:
            i.priceCents <= 0 ||
            i.confidence < ReceiptScanner.reviewBelowConfidence,
      ),
    if (answer.serviceChargeCents > 0)
      ExpenseItem(
        name: 'Service charge',
        amountCents: answer.serviceChargeCents,
        aiGenerated: true,
      ),
    if (answer.vatCents > 0)
      ExpenseItem(name: 'VAT', amountCents: answer.vatCents, aiGenerated: true),
  ];

  final sum = items.fold(0, (s, i) => s + i.amountCents);
  final total = answer.totalCents;
  final review = items.where((i) => i.needsReview).length;
  String? warning;
  // Allow ₱1 or 1% difference for rounding on the receipt.
  if (total != null && total > 0 && (sum - total).abs() > _tolerance(total)) {
    warning =
        'Items add up to ${formatMoney(sum)}, but the receipt says '
        '${formatMoney(total)}. Check the items before splitting.';
  } else if (review > 0) {
    warning =
        '$review ${review == 1 ? 'item needs' : 'items need'} review: '
        'tap to fix.';
  }

  return ScanResult(
    storeName: answer.storeName,
    items: items,
    source: ScanSource.ai,
    warning: warning,
  );
}

int _tolerance(int totalCents) =>
    (totalCents / 100).round() < 100 ? 100 : (totalCents / 100).round();
