// Tests for Report Preview (Figma 23), Profile (Figma 24), and editing /
// deleting expenses. Uses the in-memory sample group "Dinner at Jaro".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bahinko/data/in_memory_group_service.dart';
import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/group.dart';
import 'package:bahinko/screens/bill/split_summary_screen.dart';
import 'package:bahinko/screens/profile/profile_screen.dart';
import 'package:bahinko/screens/report/report_preview_screen.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/services/settings_service.dart';
import 'package:bahinko/services/wallet_service.dart';
import 'package:bahinko/utils/group_report.dart';
import 'package:bahinko/utils/report_pdf.dart';

void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<GroupReport> sampleReport() async => buildGroupReport(
  await GroupService.instance.watchLedger(demoGroupId).first,
  myId: 'me',
  now: DateTime(2026, 10, 30),
);

Payment paid(String from, String to, int cents) => Payment(
  fromId: from,
  fromName: from,
  toId: to,
  toName: to,
  amountCents: cents,
  status: 'confirmed',
);

void main() {
  setUp(() {
    groupMembers.value = people;
    GroupService.instance = InMemoryGroupService();
    WalletService.instance = WalletService();
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance = SettingsService();
  });

  group('report', () {
    test('rows, total and statuses match the Figma example', () async {
      await GroupService.instance.recordPayment(
        demoGroupId,
        paid('leo', 'me', 20000),
      );
      await GroupService.instance.recordPayment(
        demoGroupId,
        paid('ana', 'me', 62000),
      );
      final r = await sampleReport();
      expect(r.totalCents, 295000);
      expect(r.subtitle, 'Oct 28, 2026 · 5 members');
      expect(r.rows.map((x) => x.title), ['Samgyup House', 'Milk Tea Run']);
      final status = {for (final p in r.people) p.name: p.status};
      expect(status['You'], 'Paid the bill');
      expect(status['Mia'], 'Owes ₱20.00');
      expect(status['Jun'], 'Unpaid');
      expect(status['Ana'], 'Paid');
      expect(status['Leo'], 'Partial · ₱195.00 left');
      final share = {for (final p in r.people) p.name: p.shareCents};
      expect(share['Mia'], 47000);
    });

    test('CSV quotes commas and blocks spreadsheet formulas', () async {
      await GroupService.instance.addExpense(
        demoGroupId,
        GroupExpense.create(
          title: '=HYPERLINK("x"), drinks',
          paidById: 'me',
          paidByName: 'You',
          amountCents: 1000,
          shares: const {'me': 1000},
        ),
      );
      final csv = reportCsv(await sampleReport());
      expect(csv, contains('Date,Expense,Paid by,Amount (PHP)'));
      expect(csv, contains('2026-10-28,Samgyup House,You,2500.00'));
      expect(csv, contains('"\'=HYPERLINK(""x""), drinks"'));
      expect(csv, contains('Mia,470.00,Owes PHP 20.00'));
    });

    test('PDF export produces a real PDF file', () async {
      final bytes = await buildReportPdf(await sampleReport());
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    testWidgets('Report Preview shows the report and export buttons', (
      tester,
    ) async {
      tallScreen(tester);
      await tester.pumpWidget(
        const MaterialApp(home: ReportPreview(groupId: demoGroupId)),
      );
      await tester.pump();
      expect(find.text('Dinner at Jaro'), findsOneWidget);
      expect(find.text('₱2,950.00'), findsOneWidget);
      expect(find.text('Owes ₱20.00'), findsOneWidget);
      expect(find.text('Export CSV'), findsOneWidget);
      expect(find.text('Export PDF'), findsOneWidget);
    });
  });

  group('edit and delete', () {
    Future<void> openSummary(WidgetTester tester) async {
      tallScreen(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: SplitSummary(groupId: demoGroupId, expenseId: 'milktea'),
        ),
      );
      await tester.pump();
    }

    testWidgets('delete asks first, then removes it everywhere', (
      tester,
    ) async {
      await openSummary(tester);
      await tester.tap(find.byKey(const ValueKey('expense-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete expense'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Milk Tea Run?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-delete')));
      await tester.pumpAndSettle();

      final service = GroupService.instance;
      final left = await service.watchExpenses(demoGroupId).first;
      expect(left.map((e) => e.id), ['samgyup']);
      expect((await service.watchGroup(demoGroupId).first).totalCents, 250000);
      final log = await service.watchActivity(demoGroupId).first;
      expect(log.first.text, 'You deleted Milk Tea Run');
    });

    testWidgets('edit opens the form filled in and saves changes', (
      tester,
    ) async {
      await openSummary(tester);
      await tester.tap(find.byKey(const ValueKey('expense-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit expense'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Expense'), findsOneWidget);
      expect(find.text('Milk Tea Run'), findsOneWidget);
      expect(find.text('450'), findsOneWidget); // amount
      // Saved with Mia, You and Jun only: Ana and Leo are unticked.
      final ana = tester.widget<Checkbox>(
        find.byKey(const ValueKey('include-ana')),
      );
      expect(ana.value, isFalse);

      await tester.enterText(
        find.byKey(const ValueKey('expense-amount')),
        '600',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save-expense')));
      await tester.pumpAndSettle();

      final e = await GroupService.instance
          .watchExpense(demoGroupId, 'milktea')
          .first;
      expect(e.amountCents, 60000);
      expect(e.shares, {'mia': 20000, 'jun': 20000, 'me': 20000});
      final log = await GroupService.instance.watchActivity(demoGroupId).first;
      expect(log.first.text, 'You edited Milk Tea Run');
      expect(log.first.oldCents, 45000);
      expect(log.first.newCents, 60000);
      // Back on the summary, which already shows the new total.
      expect(find.text('Split Summary'), findsOneWidget);
      expect(find.text('₱600.00'), findsOneWidget);
    });

    testWidgets('an uneven "equal" expense opens on Exact, unchanged', (
      tester,
    ) async {
      tallScreen(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: SplitSummary(groupId: demoGroupId, expenseId: 'samgyup'),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('expense-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit expense'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('exact-jun')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-expense')));
      await tester.pumpAndSettle();
      final e = await GroupService.instance
          .watchExpense(demoGroupId, 'samgyup')
          .first;
      expect(e.shares['jun'], 69500); // not re-split
    });
  });

  group('profile', () {
    Future<void> openProfile(WidgetTester tester) async {
      tallScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: Profile()));
      await tester.pumpAndSettle();
    }

    testWidgets('shows name, group count and settings', (tester) async {
      await openProfile(tester);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('@you · 2 groups'), findsOneWidget);
      expect(find.text('App lock'), findsOneWidget);
      expect(find.text('Polite, 3 days before due dates'), findsOneWidget);
      expect(find.text('Syncing live'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('wallet number is validated, saved and masked', (tester) async {
      await openProfile(tester);
      await tester.tap(find.byKey(const ValueKey('wallet-GCash')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('wallet-number')),
        '12345',
      );
      await tester.tap(find.byKey(const ValueKey('wallet-save')));
      await tester.pump();
      expect(
        find.text('Enter a PH mobile number, like 0917 123 4567'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('wallet-number')),
        '+63 917-123-4821',
      );
      await tester.tap(find.byKey(const ValueKey('wallet-save')));
      await tester.pumpAndSettle();
      expect(find.text('GCash 0917 ••• 4821'), findsOneWidget);
      expect(await WalletService.instance.number('GCash'), '09171234821');
    });

    testWidgets('reminder tone and offline mode are saved', (tester) async {
      await openProfile(tester);
      await tester.tap(find.text('Reminder settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tone-Friendly')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // close the sheet
      await tester.pumpAndSettle();
      expect(find.text('Friendly, 3 days before due dates'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('offline')));
      await tester.pumpAndSettle();
      expect(SettingsService.instance.offlineMode, isTrue);
      expect(find.text('Last synced just now'), findsOneWidget);
    });

    testWidgets('log out warns before doing anything', (tester) async {
      await openProfile(tester);
      await tester.tap(find.byKey(const ValueKey('logout')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('will NOT get your groups back'),
        findsOneWidget,
      );
      await tester.tap(find.text('Stay logged in'));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
    });
  });

  test('phone numbers: normalize and mask', () {
    expect(normalizePhone('0917 123 4821'), '09171234821');
    expect(normalizePhone('639171234821'), '09171234821');
    expect(normalizePhone('0817 123 4821'), isNull); // not a mobile number
    expect(maskPhone('09171234821'), '0917 ••• 4821');
  });
}
