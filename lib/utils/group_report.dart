/// The data behind Report Preview (Figma 23) and its CSV / PDF exports.
///
/// [buildGroupReport] turns a group's ledger into plain rows once, so the
/// screen, the CSV and the PDF always show the same numbers. No Flutter or
/// Firebase here: unit-tested in test/report_test.dart.
library;

import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/settle_calculator.dart';

/// One expense line: "Oct 28 · Samgyup House · You · ₱2,500.00".
class ReportRow {
  const ReportRow(this.date, this.title, this.paidBy, this.amountCents);

  final DateTime? date;
  final String title, paidBy;
  final int amountCents;
}

/// Green (all good) or orange (still owes) status text.
enum StatusKind { good, owes }

/// One person: their total share across all expenses, and their status.
class ReportPerson {
  const ReportPerson(this.name, this.shareCents, this.status, this.kind);

  final String name;
  final int shareCents;

  /// "Paid the bill", "Paid", "Unpaid", "Owes ₱20.00",
  /// "Partial · ₱195.00 left".
  final String status;
  final StatusKind kind;
}

class GroupReport {
  const GroupReport({
    required this.groupName,
    required this.subtitle,
    required this.rows,
    required this.totalCents,
    required this.people,
    required this.generatedAt,
  });

  final String groupName;

  /// "Oct 28 – Oct 30, 2026 · 5 members · Paid via GCash / Maya".
  final String subtitle;
  final List<ReportRow> rows;
  final int totalCents;
  final List<ReportPerson> people;
  final DateTime generatedAt;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Oct 28".
String shortDate(DateTime? d) =>
    d == null ? '—' : '${_months[d.month - 1]} ${d.day}';

/// "Oct 28, 2026".
String longDate(DateTime d) => '${shortDate(d)}, ${d.year}';

GroupReport buildGroupReport(
  GroupLedger ledger, {
  required String myId,
  DateTime? now,
}) {
  final group = ledger.group;
  String nameOf(String id) =>
      id == myId ? 'You' : group.memberById(id)?.name ?? 'Former member';

  // Oldest first reads like a statement.
  final expenses = ledger.expenses.toList()
    ..sort((a, b) => (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));
  final rows = [
    for (final e in expenses)
      ReportRow(
        e.date,
        e.title,
        e.paidById.isEmpty ? e.paidBy : nameOf(e.paidById),
        e.amountCents,
      ),
  ];

  // Subtitle: date range · member count · payment apps used.
  final dates = [for (final e in expenses) ?e.date];
  final parts = <String>[];
  if (dates.isNotEmpty) {
    dates.sort();
    final a = dates.first, b = dates.last;
    parts.add(
      shortDate(a) == shortDate(b) && a.year == b.year
          ? longDate(a)
          : a.year == b.year
          ? '${shortDate(a)} – ${longDate(b)}'
          : '${longDate(a)} – ${longDate(b)}',
    );
  }
  parts.add('${group.members.length} members');
  final apps = {
    for (final p in ledger.payments)
      if (p.method == 'gcash') 'GCash' else if (p.method == 'maya') 'Maya',
  };
  if (apps.isNotEmpty) {
    parts.add('Paid via ${(apps.toList()..sort()).join(' / ')}');
  }

  // Per person.
  final shareOf = <String, int>{};
  for (final e in ledger.expenses) {
    for (final s in e.shares.entries) {
      shareOf[s.key] = (shareOf[s.key] ?? 0) + s.value;
    }
  }
  final balances = ledger.balances;
  final ids = [
    for (final m in group.members) m.id,
    // People who left but still appear in old expenses.
    for (final id in shareOf.keys)
      if (group.memberById(id) == null) id,
  ];
  final people = <ReportPerson>[];
  for (final id in ids) {
    final share = shareOf[id] ?? 0;
    final bal = balances[id] ?? 0;
    final paidABill = ledger.expenses.any((e) => e.paidById == id);
    final paidBack = ledger.payments.any(
      (p) => p.isConfirmed && p.fromId == id,
    );
    final (String status, StatusKind kind) = bal >= 0
        ? (
            paidABill
                ? 'Paid the bill'
                : (share == 0 ? 'Nothing to pay' : 'Paid'),
            StatusKind.good,
          )
        : paidBack
        ? ('Partial · ${formatMoney(-bal)} left', StatusKind.owes)
        : paidABill
        ? ('Owes ${formatMoney(-bal)}', StatusKind.owes)
        : ('Unpaid', StatusKind.owes);
    people.add(ReportPerson(nameOf(id), share, status, kind));
  }

  return GroupReport(
    groupName: group.name,
    subtitle: parts.join(' · '),
    rows: rows,
    totalCents: ledger.expenses.fold(0, (a, e) => a + e.amountCents),
    people: people,
    generatedAt: now ?? DateTime.now(),
  );
}

/// The report as CSV (opens in Excel / Google Sheets). Amounts are plain
/// numbers ("2500.00") so spreadsheets can add them up.
String reportCsv(GroupReport r) {
  String cell(Object? v) {
    final s = '${v ?? ''}';
    // Quote cells with commas, quotes or line breaks; double any quotes.
    // Cells starting with = + - @ are prefixed with ' so a spreadsheet
    // never runs them as formulas (CSV injection).
    final safe = RegExp(r'^[=+\-@]').hasMatch(s) ? "'$s" : s;
    return RegExp(r'[",\n\r]').hasMatch(safe)
        ? '"${safe.replaceAll('"', '""')}"'
        : safe;
  }

  String money(int cents) => (cents / 100).toStringAsFixed(2);
  String iso(DateTime? d) => d == null
      ? ''
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
  String line(List<Object?> cells) => cells.map(cell).join(',');

  return [
    line(['BahinKo expense report', r.groupName]),
    line([r.subtitle]),
    '',
    line(['Date', 'Expense', 'Paid by', 'Amount (PHP)']),
    for (final row in r.rows)
      line([iso(row.date), row.title, row.paidBy, money(row.amountCents)]),
    line(['', 'TOTAL', '', money(r.totalCents)]),
    '',
    line(['Name', 'Share (PHP)', 'Status']),
    for (final p in r.people)
      line([p.name, money(p.shareCents), p.status.replaceAll('₱', 'PHP ')]),
    '',
    line(['Generated by BahinKo', iso(r.generatedAt)]),
  ].join('\r\n'); // CRLF: what Excel expects
}
