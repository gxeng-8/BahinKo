/// One item on a receipt: name and price in centavos.
library;

class ReceiptLineItem {
  const ReceiptLineItem(this.name, this.amountInCents);

  final String name;
  final int amountInCents;
}
