import 'package:bahinko/utils/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses item prices into cents and ignores receipt totals', () {
    expect(
      parseReceiptItems('''
        Cafe Latte 125.50
        2 Croissants ₱80
        Subtotal 205.50
        VAT 16.44
        Total PHP 221.94
      '''),
      [('Cafe Latte', 12550), ('Croissants', 8000)],
    );
  });

  test('skips dates, receipt numbers and other non-price numbers', () {
    expect(
      parseReceiptItems('''
        MANG INASAL JARO
        TIN 123-456-789-000
        Tel 033 320 1234
        OR No. 000123456
        SI# 00045
        Date: 11/24/2026  Time: 7:45PM
        Nov 24, 2026
        Table 12   Pax 4
        Cashier: Ana 0021
        2 PM1 Chicken Inasal 398.00
        Halo-Halo ₱95
        Rice 5 @ 20.00   100.00
        Cashew Chicken 180.00 V
        No. of items 4
        Subtotal 773.00
        TOTAL 773.00
        Cash 1,000.00
        Change 227.00
        VATable Sales 690.18
        VAT 82.82
        Thank you, come again!
      '''),
      [
        ('PM1 Chicken Inasal', 39800),
        ('Halo-Halo', 9500),
        ('Rice', 10000),
        ('Cashew Chicken', 18000),
      ],
    );
  });

  test('looksLikeNonItem catches labels but keeps real food names', () {
    for (final label in [
      'OR No.',
      'Date',
      'Receipt #',
      'Table',
      'Cash',
      'TIN',
      'Ref',
      '#0012',
      'Nov 24',
      'Time 7:45',
    ]) {
      expect(looksLikeNonItem(label), isTrue, reason: label);
    }
    for (final food in [
      'Cashew Chicken',
      'Noodles',
      'Ordinary Pizza',
      'Tapsilog',
      'Mango Shake',
      'Marlboro 2',
    ]) {
      expect(looksLikeNonItem(food), isFalse, reason: food);
    }
  });
}
