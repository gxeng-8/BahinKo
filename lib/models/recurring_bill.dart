/// A bill that repeats on a schedule.
library;

class RecurringBill {
  RecurringBill(this.name, this.schedule, this.amount, this.enabled);

  final String name;
  final String schedule;
  final String amount;
  bool enabled;
}
