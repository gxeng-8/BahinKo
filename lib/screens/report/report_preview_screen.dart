/// Figma Frame 23 "Report Preview": a group's expenses and who has paid,
/// as a printable report, with Export CSV / Export PDF.
///
/// Built live from the group's ledger (expenses + payments), so it always
/// matches Settle Up. The numbers come from utils/group_report.dart; the
/// PDF is drawn by utils/report_pdf.dart. Exports open the phone's share
/// sheet (save to Files, Drive, Messenger, email…).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/group_report.dart';
import 'package:bahinko/utils/report_pdf.dart';
import 'package:bahinko/utils/settle_calculator.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/app_toast.dart';
import 'package:bahinko/widgets/async_state_view.dart';
import 'package:bahinko/widgets/btn.dart';

class ReportPreview extends StatefulWidget {
  const ReportPreview({super.key, required this.groupId});

  final String groupId;

  @override
  State<ReportPreview> createState() => _ReportPreviewState();
}

class _ReportPreviewState extends State<ReportPreview> {
  late Stream<GroupLedger> _ledger;

  /// Which export is running ('csv' / 'pdf'), to show a spinner.
  String? _exporting;

  @override
  void initState() {
    super.initState();
    _ledger = GroupService.instance.watchLedger(widget.groupId);
  }

  /// "Dinner at Jaro" → "dinner-at-jaro-report".
  String _fileName(GroupReport r) {
    final slug = r.groupName
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return '${slug.isEmpty ? 'group' : slug}-report';
  }

  Future<void> _export(GroupReport r, String kind) async {
    setState(() => _exporting = kind);
    try {
      final XFile file;
      if (kind == 'csv') {
        // BOM first so Excel reads ñ and other accents correctly.
        final bytes = utf8.encode('﻿${reportCsv(r)}');
        file = XFile.fromData(bytes, mimeType: 'text/csv');
      } else {
        file = XFile.fromData(
          await buildReportPdf(r),
          mimeType: 'application/pdf',
        );
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: ['${_fileName(r)}.$kind'],
          subject: '${r.groupName} expense report',
        ),
      );
    } catch (_) {
      if (mounted) {
        showAppToast(context, "Couldn't export the report. Try again.");
      }
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<GroupLedger>(
    stream: _ledger,
    builder: (context, snap) {
      final ledger = snap.data;
      final report = ledger == null
          ? null
          : buildGroupReport(ledger, myId: GroupService.instance.myId);
      final busy = _exporting != null;
      return AppPage(
        'Report Preview',
        onRefresh: () => setState(
          () => _ledger = GroupService.instance.watchLedger(widget.groupId),
        ),
        AsyncStateView<GroupLedger>(
          snapshot: snap,
          onRetry: () => setState(
            () => _ledger = GroupService.instance.watchLedger(widget.groupId),
          ),
          isEmpty: (l) => l.expenses.isEmpty,
          emptyIcon: Icons.description_outlined,
          emptyMessage: 'No expenses yet, so there is nothing to report.',
          builder: (_) => _ReportCard(report: report!),
        ),
        bottom: report == null || report.rows.isEmpty
            ? null
            : Row(
                children: [
                  Expanded(
                    child: Btn(
                      _exporting == 'csv' ? 'Exporting…' : 'Export CSV',
                      busy ? null : () => _export(report, 'csv'),
                      outlined: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Btn(
                      _exporting == 'pdf' ? 'Exporting…' : 'Export PDF',
                      busy ? null : () => _export(report, 'pdf'),
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

/// The white "paper" with the report on it.
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final GroupReport report;

  static const _head = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: deep,
  );

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: mint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long, color: green, size: 20),
              ),
              const SizedBox(width: 8),
              Text('BahinKo', style: AppText.display(18, color: deep)),
              const Spacer(),
              const Text('Expense Report', style: AppText.caption),
            ],
          ),
          const Divider(height: 24),
          Text(r.groupName, style: AppText.section.copyWith(fontSize: 18)),
          Text(r.subtitle, style: AppText.caption),
          const SizedBox(height: 14),
          _TableHeader(const ['DATE', 'EXPENSE', 'PAID BY', 'AMOUNT']),
          for (final row in r.rows)
            _Row(
              flex: const [2, 4, 2, 3],
              cells: [
                Text(shortDate(row.date), style: const TextStyle(fontSize: 12)),
                Text(row.title, style: const TextStyle(fontSize: 12)),
                Text(row.paidBy, style: const TextStyle(fontSize: 12)),
                Text(
                  formatMoney(row.amountCents),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          const Divider(height: 20),
          Row(
            children: [
              const Text('TOTAL', style: _head),
              const Spacer(),
              Text(
                formatMoney(r.totalCents),
                key: const ValueKey('report-total'),
                style: AppText.money(20, color: green),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Per person', style: AppText.section),
          const SizedBox(height: 8),
          _TableHeader(
            const ['NAME', 'SHARE', 'STATUS'],
            flex: const [3, 3, 4],
          ),
          for (final p in r.people)
            _Row(
              flex: const [3, 3, 4],
              cells: [
                Text(p.name, style: const TextStyle(fontSize: 12)),
                Text(
                  formatMoney(p.shareCents),
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  p.status,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.kind == StatusKind.good ? paidFg : unpaidFg,
                  ),
                ),
              ],
            ),
          const Divider(height: 24),
          const Text(
            'Shares follow how each expense was split (equal, by item, exact, '
            'percent or shares).',
            style: AppText.caption,
          ),
          const SizedBox(height: 6),
          const Text(
            'Payments are made in GCash, Maya or cash. BahinKo never holds '
            'money.',
            style: AppText.caption,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Generated by BahinKo · ${longDate(r.generatedAt)}',
              style: const TextStyle(fontSize: 10, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mint header row of a table.
class _TableHeader extends StatelessWidget {
  const _TableHeader(this.labels, {this.flex = const [2, 4, 2, 3]});

  final List<String> labels;
  final List<int> flex;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(
      color: mint,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            flex: flex[i],
            child: Text(
              labels[i],
              textAlign: i == labels.length - 1
                  ? TextAlign.right
                  : TextAlign.left,
              style: _ReportCard._head,
            ),
          ),
      ],
    ),
  );
}

/// One table row with columns sized by [flex].
class _Row extends StatelessWidget {
  const _Row({required this.flex, required this.cells});

  final List<int> flex;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cells.length; i++)
          Expanded(
            flex: flex[i],
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: cells[i],
            ),
          ),
      ],
    ),
  );
}
