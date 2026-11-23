// Tests for the AI receipt feature: parsing the AI's answer, privacy
// masking, checking the answer, the fallback chain, and the screens.
// A fake AI and fake OCR are used, so no internet or camera is needed.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/screens/bill/assign_items_screen.dart';
import 'package:bahinko/screens/scan/scanning_screen.dart';
import 'package:bahinko/services/receipt_ai_service.dart';
import 'package:bahinko/services/receipt_scanner.dart';

/// Text like ML Kit would return for the Figma receipt.
const ocrText = '''
SAMGYUP HOUSE
Jaro, Iloilo City  Oct 28 2026
1 PORK BELLY SET     900.00
2 RICE X5            250.00
3 ICED TEA X2        300.00
4 S0JU X3            450.00
SERVICE CHARGE       250.00
VAT                  350.00
TOTAL              2,500.00
THANK YOU!
''';

/// A fake AI that returns a fixed answer, throws, or hangs.
class FakeAi implements ReceiptAi {
  FakeAi({this.answer, this.error, this.hang = false});
  final AiReceipt? answer;
  final Object? error;
  final bool hang;
  String? lastText;

  @override
  Future<AiReceipt> extract(String receiptText) async {
    lastText = receiptText;
    if (hang) return Completer<AiReceipt>().future; // never finishes
    if (error != null) throw error!;
    return answer!;
  }
}

/// An AI whose answer comes from a callback (to simulate flaky service).
class _FlakyAi implements ReceiptAi {
  _FlakyAi(this.next);
  final AiReceipt Function() next;

  @override
  Future<AiReceipt> extract(String receiptText) async => next();
}

const goodAnswer = AiReceipt(
  storeName: 'Samgyup House',
  items: [
    AiReceiptItem('Pork belly set', 90000, 0.98),
    AiReceiptItem('Rice x5', 25000, 0.95),
    AiReceiptItem('Iced tea x2', 30000, 0.93),
    AiReceiptItem('Soju x3', 45000, 0.55), // OCR said "S0JU": unsure
  ],
  serviceChargeCents: 25000,
  vatCents: 35000,
  totalCents: 250000,
);

void main() {
  group('parseAiReceiptJson', () {
    test('converts pesos to centavos and reads every field', () {
      final r = parseAiReceiptJson(
        '{"storeName":"Samgyup House","items":[{"name":"Rice x5",'
        '"price":250.5,"confidence":0.9}],"serviceCharge":25,"vat":0,'
        '"total":275.5}',
      );
      expect(r.storeName, 'Samgyup House');
      expect(r.items.single.priceCents, 25050);
      expect(r.serviceChargeCents, 2500);
      expect(r.totalCents, 27550);
    });

    test('rejects answers that are not JSON objects', () {
      expect(() => parseAiReceiptJson('[1,2]'), throwsFormatException);
      expect(
        () => parseAiReceiptJson('sorry, I cannot'),
        throwsFormatException,
      );
    });
  });

  test('redactForAi masks card/phone numbers and emails, keeps prices', () {
    final out = redactForAi(
      'CARD 4111 1111 1111 1111\nCall 09171234567\nmail me@x.com\n'
      'RICE 1,250.00',
    );
    expect(out, isNot(contains('4111')));
    expect(out, isNot(contains('09171234567')));
    expect(out, isNot(contains('me@x.com')));
    expect(out, contains('1,250.00'));
  });

  group('reviewAiReceipt', () {
    test('flags unsure items and adds service charge and VAT', () {
      final r = reviewAiReceipt(goodAnswer)!;
      expect(r.source, ScanSource.ai);
      expect(r.items.map((i) => i.name), contains('Service charge'));
      expect(r.items.map((i) => i.name), contains('VAT'));
      expect(r.totalCents, 250000);
      expect(r.needsReviewCount, 1);
      expect(r.items.firstWhere((i) => i.name == 'Soju x3').needsReview, true);
      expect(r.items.every((i) => i.aiGenerated), isTrue);
      expect(r.warning, '1 item needs review: tap to fix.');
    });

    test('warns when the items do not add up to the printed total', () {
      const wrong = AiReceipt(
        storeName: 'Cafe',
        items: [AiReceiptItem('Latte', 15000, 1)],
        totalCents: 30000,
      );
      expect(reviewAiReceipt(wrong)!.warning, contains('receipt says'));
    });

    test('explains a discount instead of a confusing total mismatch', () {
      const withDiscount = AiReceipt(
        storeName: 'Jolly Burger',
        items: [AiReceiptItem('Chickenjoy', 17000, 1)],
        discountCents: 1300,
        totalCents: 15700,
      );
      expect(reviewAiReceipt(withDiscount)!.warning, contains('discount'));
    });

    test('returns null (unusable) when nothing or mostly no prices', () {
      expect(
        reviewAiReceipt(const AiReceipt(storeName: 'x', items: [])),
        isNull,
      );
      expect(
        reviewAiReceipt(
          const AiReceipt(
            storeName: 'x',
            items: [AiReceiptItem('A', 0, 1), AiReceiptItem('B', 0, 1)],
          ),
        ),
        isNull,
      );
    });
  });

  group('ReceiptScanner fallback chain', () {
    test('uses the AI when it works, sending privacy-masked text', () async {
      final ai = FakeAi(answer: goodAnswer);
      final r = await ReceiptScanner(customAi: ai)
          .analyzeText('$ocrText\nCARD 4111111111111111');
      expect(r.source, ScanSource.ai);
      expect(ai.lastText, isNot(contains('4111111111111111')));
    });

    test('falls back to basic detection when the AI fails', () async {
      final r = await ReceiptScanner(
        customAi: FakeAi(error: Exception('quota')),
      ).analyzeText(ocrText);
      expect(r.source, ScanSource.basic);
      expect(r.items.map((i) => i.name), contains('PORK BELLY SET'));
      expect(r.warning, contains('unavailable'));
    });

    test('retries once when the AI fails fast (e.g. "model busy")', () async {
      var calls = 0;
      final flaky = _FlakyAi(() {
        calls++;
        if (calls == 1) throw Exception('high demand');
        return goodAnswer;
      });
      final r = await ReceiptScanner(customAi: flaky).analyzeText(ocrText);
      expect(r.source, ScanSource.ai);
      expect(calls, 2);
    });

    test('falls back when the AI takes too long (timeout)', () async {
      final r = await ReceiptScanner(
        customAi: FakeAi(hang: true),
        aiTimeout: const Duration(milliseconds: 50),
      ).analyzeText(ocrText);
      expect(r.source, ScanSource.basic);
      expect(r.warning, contains('took too long'));
    });

    test('falls back when the AI answer is unusable', () async {
      final r = await ReceiptScanner(
        customAi: FakeAi(
          answer: const AiReceipt(storeName: 'x', items: []),
        ),
      ).analyzeText(ocrText);
      expect(r.source, ScanSource.basic);
    });

    test('fails clearly when neither the AI nor the parser finds items', () {
      expect(
        ReceiptScanner(customAi: FakeAi(error: Exception('down')))
            .analyzeText('just some words'),
        throwsA(isA<ScanFailure>()),
      );
    });

    test('reports stages and rejects photos with no text', () async {
      final stages = <ScanStage>[];
      final scanner = ReceiptScanner(
        customAi: FakeAi(answer: goodAnswer),
        ocr: (_) async => ocrText,
      );
      await scanner.scanImage('photo.jpg', onStage: stages.add);
      expect(stages, [ScanStage.reading, ScanStage.organizing]);

      expect(
        ReceiptScanner(ocr: (_) async => '  ').scanImage('blank.jpg'),
        throwsA(isA<ScanFailure>()),
      );
    });
  });

  group('screens', () {
    setUp(() => groupMembers.value = people);

    testWidgets('Scanning → Assign Items shows AI label and Needs review', (
      tester,
    ) async {
      ReceiptScanner.instance = ReceiptScanner(
        customAi: FakeAi(answer: goodAnswer),
        ocr: (_) async => ocrText,
      );
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: ScanningScreen(imagePath: 'x.jpg')),
      );
      await tester.pump(); // scan finishes
      await tester.pump(const Duration(seconds: 1)); // page transition
      expect(find.byType(AssignItems), findsOneWidget);
      expect(find.text('AI-detected'), findsOneWidget);
      expect(find.text('Needs review'), findsOneWidget);

      // Fix the unsure item in the Edit Item sheet.
      await tester.tap(find.text('Soju x3'));
      await tester.pumpAndSettle(); // let the sheet finish sliding up
      await tester.enterText(
        find.byKey(const ValueKey('edit-item-price')),
        '450',
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-item-name')),
        'Soju x3',
      );
      await tester.tap(find.byType(Switch)); // un-flag
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Needs review'), findsNothing);
    });

    testWidgets('Scanning shows Retake / Enter manually when it fails', (
      tester,
    ) async {
      ReceiptScanner.instance = ReceiptScanner(ocr: (_) async => '');
      await tester.pumpWidget(
        const MaterialApp(home: ScanningScreen(imagePath: 'x.jpg')),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text("Couldn't scan this receipt"), findsOneWidget);
      expect(find.text('Retake photo'), findsOneWidget);
      expect(find.text('Enter manually'), findsOneWidget);
    });

    testWidgets('Confirm Split asks first when items still need review', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: AssignItems(scan: reviewAiReceipt(goodAnswer))),
      );
      await tester.pump(); // groups load, enabling Confirm Split
      await tester.tap(find.text('Confirm Split'));
      await tester.pumpAndSettle();
      expect(find.text('Some items need review'), findsOneWidget);
      expect(find.text('Split anyway'), findsOneWidget);
    });
  });
}
