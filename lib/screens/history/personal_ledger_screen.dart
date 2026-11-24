/// Figma Frame 18 "Personal Ledger": your balance, and every person who
/// owes you or whom you owe, across all your groups.
///
/// Live from every group's ledger. The header uses the same totals as the
/// Home header; the rows are each group's smart-settle transfers added up
/// per person (utils/insights.dart → buildPersonalLedger). Tap a person
/// to settle up.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/screens/settle/settle_up_screen.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/currency.dart';
import 'package:bahinko/utils/insights.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/utils/settle_calculator.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/async_state_view.dart';
import 'package:bahinko/widgets/avatar.dart';
import 'package:bahinko/widgets/box.dart';

class PersonalLedger extends StatefulWidget {
  const PersonalLedger({super.key});

  @override
  State<PersonalLedger> createState() => _PersonalLedgerState();
}

class _PersonalLedgerState extends State<PersonalLedger> {
  late Stream<List<GroupLedger>> _ledgers;

  @override
  void initState() {
    super.initState();
    _ledgers = GroupService.instance.watchAllLedgers();
  }

  @override
  Widget build(BuildContext context) {
    final myId = GroupService.instance.myId;
    return AppPage(
      'Personal Ledger',
      StreamBuilder<List<GroupLedger>>(
        stream: _ledgers,
        builder: (context, snap) => AsyncStateView<List<GroupLedger>>(
          snapshot: snap,
          onRetry: () => setState(
            () => _ledgers = GroupService.instance.watchAllLedgers(),
          ),
          builder: (ledgers) {
            final stats = buildStats(ledgers, myId);
            final lines = buildPersonalLedger(ledgers, myId);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BalanceCard(owed: stats.owedToYou, owe: stats.youOwe),
                const SizedBox(height: 4),
                if (lines.isEmpty)
                  const Box(
                    Column(
                      children: [
                        Icon(Icons.celebration_outlined, color: green),
                        SizedBox(height: 6),
                        Text(
                          "You're all square with everyone.",
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                for (final line in lines) _PersonRow(line: line),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Dark card: "Your balance ₱710.00" + owed / owe chips.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.owed, required this.owe});

  final int owed, owe;

  @override
  Widget build(BuildContext context) => Box(
    color: deep,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your balance', style: TextStyle(color: Colors.white70)),
        Text(
          formatMoney(owed - owe),
          key: const ValueKey('ledger-net'),
          style: AppText.money(32, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _chip('Owed to you', owed, const Color(0xFF74E4A7)),
            ),
            const SizedBox(width: 8),
            Expanded(child: _chip('You owe', owe, const Color(0xFFFFF3D6))),
          ],
        ),
      ],
    ),
  );

  Widget _chip(String label, int cents, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        Text(
          formatMoney(cents),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

/// "Jun · Owes you · Dinner at Jaro   +₱845.00".
class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.line});

  final LedgerLine line;

  @override
  Widget build(BuildContext context) {
    final owesMe = line.netCents > 0;
    final groupIds = line.groups.keys.toList();
    return Box(
      onTap: () => go(
        context,
        // One shared group: open it. Several: let Settle Up ask which.
        SettleUp(groupId: groupIds.length == 1 ? groupIds.first : null),
      ),
      Row(
        children: [
          Avatar(line.person, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.person.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${owesMe ? 'Owes you' : 'You owe'} · '
                  '${line.groups.values.map((g) => g.name).join(', ')}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Text(
            '${owesMe ? '+' : '-'}${formatMoney(line.netCents.abs())}',
            style: TextStyle(
              color: owesMe ? green : orange,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
