/// A bill that repeats on a schedule (Figma 16–17: Rent, WiFi…).
/// Stored at groups/{groupId}/recurring/{billId}.
///
/// The first four fields are what the current Recurring Bills screen
/// shows; the named ones are what gets saved in Firestore.
library;

class RecurringBill {
  RecurringBill(
    this.name,
    this.schedule,
    this.amount,
    this.enabled, {
    this.id = '',
    this.amountCents = 0,
    this.dayOfMonth = 1,
    this.varies = false,
  });

  final String id;
  final String name;

  /// Display text, e.g. "Every month" or "Due Nov 15".
  final String schedule;

  /// Display text, e.g. "₱1,400" (or "≈₱2,200" when [varies]).
  final String amount;
  bool enabled;

  /// The real numbers behind the display text.
  final int amountCents;
  final int dayOfMonth;

  /// True for bills like electricity whose amount changes monthly.
  final bool varies;

  Map<String, dynamic> toMap() => {
    'name': name,
    'schedule': schedule,
    'amount': amount,
    'enabled': enabled,
    'amountCents': amountCents,
    'dayOfMonth': dayOfMonth,
    'varies': varies,
  };

  factory RecurringBill.fromMap(String id, Map<String, dynamic> m) =>
      RecurringBill(
        m['name'] as String? ?? 'Bill',
        m['schedule'] as String? ?? '',
        m['amount'] as String? ?? '',
        m['enabled'] as bool? ?? true,
        id: id,
        amountCents: (m['amountCents'] as num?)?.toInt() ?? 0,
        dayOfMonth: (m['dayOfMonth'] as num?)?.toInt() ?? 1,
        varies: m['varies'] as bool? ?? false,
      );
}
