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
}
