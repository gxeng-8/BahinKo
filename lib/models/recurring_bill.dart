/// A bill that repeats on a schedule (Figma 16–17: Rent, WiFi…).
/// Stored at groups/{groupId}/recurring/{billId}.
///
/// The first four fields are what the current Recurring Bills screen
/// shows; the named ones are what gets saved in Firestore.
library;

import 'package:bahinko/utils/currency.dart';

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

  /// Builds a bill from real numbers; the display texts are made here.
  factory RecurringBill.create({
    required String name,
    required int amountCents,
    required int dayOfMonth,
    bool varies = false,
  }) => RecurringBill(
    name.trim(),
    'Every month on the ${ordinal(dayOfMonth)}',
    '${varies ? '≈' : ''}${formatMoney(amountCents)}',
    true,
    amountCents: amountCents,
    dayOfMonth: dayOfMonth,
    varies: varies,
  );

  /// 1 → "1st", 2 → "2nd", 11 → "11th", 22 → "22nd".
  static String ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }

  /// The next due date on or after [now]. Short months use their last day
  /// (a bill due on the 31st is due Feb 28/29).
  DateTime nextDue(DateTime now) {
    DateTime dueIn(int year, int month) {
      final last = DateTime(year, month + 1, 0).day;
      return DateTime(year, month, dayOfMonth > last ? last : dayOfMonth);
    }

    final today = DateTime(now.year, now.month, now.day);
    final thisMonth = dueIn(now.year, now.month);
    return thisMonth.isBefore(today)
        ? dueIn(now.year, now.month + 1)
        : thisMonth;
  }

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
