/// Figma Frame 19 "Statistics" (Stats tab): what you're owed, money in
/// and out, your share per month, and spending by category.
///
/// Built live from every group's ledger (GroupService.watchAllLedgers),
/// so it matches Home and Settle Up. The numbers come from
/// utils/insights.dart (buildStats), which is unit-tested.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/screens/history/personal_ledger_screen.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/insights.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/widgets/async_state_view.dart';
import 'package:bahinko/widgets/box.dart';
import 'package:bahinko/widgets/btn.dart';
import 'package:bahinko/widgets/pill.dart';

/// Light green for the second bar series.
const _lightGreen = Color(0xFF5ED38A);

class Statistics extends StatefulWidget {
  const Statistics({super.key});

  @override
  State<Statistics> createState() => _StatisticsState();
}

class _StatisticsState extends State<Statistics> {
  late Stream<SpendingStats> _stats;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    final service = GroupService.instance;
    _stats = service.watchAllLedgers().map(
      (ledgers) => buildStats(ledgers, service.myId),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text('Statistics', style: AppText.title)),
          const SizedBox(height: 16),
          StreamBuilder<SpendingStats>(
            stream: _stats,
            builder: (context, snap) => AsyncStateView<SpendingStats>(
              snapshot: snap,
              onRetry: () => setState(_listen),
              isEmpty: (s) => s.isEmpty,
              emptyIcon: Icons.bar_chart,
              emptyMessage:
                  'No expenses yet. Add one and your spending shows here.',
              builder: (s) => _StatsBody(stats: s),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});

  final SpendingStats stats;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final biggest = s.months.fold(
      1, // avoid dividing by zero when every month is empty
      (m, b) =>
          [m, b.myShareCents, b.iPaidCents].reduce((a, c) => a > c ? a : c),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Total owed to you', style: AppText.caption),
        Text(
          formatMoney(s.owedToYou),
          key: const ValueKey('stats-owed'),
          style: AppText.money(32, color: deep),
        ),
        if (s.youOwe > 0) Pill.unpaid(text: 'You owe ${formatMoney(s.youOwe)}'),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('Overview', style: AppText.section),
            const Spacer(),
            const _Legend(green, 'Your share'),
            const SizedBox(width: 10),
            const _Legend(_lightGreen, 'You paid'),
          ],
        ),
        const SizedBox(height: 8),
        Box(
          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final m in s.months)
                  Semantics(
                    label:
                        '${_months[m.month.month - 1]}: your share '
                        '${formatMoney(m.myShareCents)}, you paid '
                        '${formatMoney(m.iPaidCents)}',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _Bar(m.myShareCents / biggest, green),
                            const SizedBox(width: 3),
                            _Bar(m.iPaidCents / biggest, _lightGreen),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _months[m.month.month - 1],
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _Tile(
                'Collected',
                s.collected,
                deep,
                Icons.arrow_downward,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Tile('Paid out', s.paidOut, green, Icons.arrow_upward),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Spending by category', style: AppText.section),
              const Text('Your share, all groups', style: AppText.caption),
              const SizedBox(height: 10),
              if (s.categories.isEmpty)
                const Text('Nothing yet.', style: AppText.caption),
              for (final (i, c) in s.categories.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(
                          c.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: c.percent / 100,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                          color: const [green, deep, orange, purple][i % 4],
                          backgroundColor: mint,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${c.percent}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Btn(
          'Open Personal Ledger',
          () => go(context, const PersonalLedger()),
          outlined: true,
        ),
      ],
    );
  }
}

/// One bar; [fraction] is 0–1 of the chart height.
class _Bar extends StatelessWidget {
  const _Bar(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    // At least 2px so an empty month still shows a stub.
    height: (130 * fraction).clamp(2, 130).toDouble(),
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(radius: 4, backgroundColor: color),
      const SizedBox(width: 4),
      Text(label, style: AppText.caption),
    ],
  );
}

/// Dark tile: "Collected ₱4,820.00".
class _Tile extends StatelessWidget {
  const _Tile(this.label, this.cents, this.color, this.icon);

  final String label;
  final int cents;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.white,
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 20),
        Text(label, style: const TextStyle(color: Colors.white70)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatMoney(cents),
            style: AppText.money(20, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
