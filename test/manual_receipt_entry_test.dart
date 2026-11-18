import 'package:bahinko/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manual receipt items flow through assignment and summary', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ScanReceipt()));

    await tester.tap(find.text('Enter manually'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to items'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an item name'), findsOneWidget);
    expect(find.text('Enter a price'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('receipt-store-name')),
      'Cafe',
    );
    await tester.enterText(
      find.byKey(const ValueKey('receipt-item-name-0')),
      'Coffee',
    );
    await tester.enterText(
      find.byKey(const ValueKey('receipt-item-price-0')),
      '1.239',
    );
    await tester.tap(find.text('Continue to items'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid price (max 2 decimals)'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('receipt-item-price-0')),
      '125.50',
    );
    await tester.ensureVisible(find.text('Add item'));
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('receipt-item-name-1')),
      'Cake',
    );
    await tester.enterText(
      find.byKey(const ValueKey('receipt-item-price-1')),
      '202.27',
    );
    await tester.tap(find.text('Continue to items'));
    await tester.pumpAndSettle();

    expect(find.text('2 items entered manually'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Cake'), findsOneWidget);
    expect(find.text('₱327.77'), findsOneWidget);

    await tester.tap(find.text('Confirm Split'));
    await tester.pumpAndSettle();

    expect(find.text('Cafe'), findsOneWidget);
    expect(find.text('₱327.77'), findsOneWidget);
    expect(find.text('₱65.56'), findsNWidgets(2));
    expect(find.text('₱65.55'), findsNWidgets(3));
  });
}
