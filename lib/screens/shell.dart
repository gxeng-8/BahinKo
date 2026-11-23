/// Bottom navigation shell (Home / Stats) with the scan button.
library;

import 'package:flutter/material.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/screens/home/home_screen.dart';
import 'package:bahinko/screens/scan/scan_receipt_screen.dart';
import 'package:bahinko/screens/history/personal_ledger_screen.dart';
import 'package:bahinko/screens/stats/statistics_screen.dart';
import 'package:bahinko/screens/settings/privacy_screen.dart';
import 'package:bahinko/theme/app_colors.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: tab, children: const [Home(), Statistics()]),
    floatingActionButton: FloatingActionButton(
      backgroundColor: green,
      shape: const CircleBorder(),
      onPressed: () => go(context, const ScanReceipt()),
      child: const Icon(Icons.qr_code_scanner, color: Colors.white),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    bottomNavigationBar: BottomAppBar(
      shape: const CircularNotchedRectangle(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: Icon(
              Icons.home_outlined,
              color: tab == 0 ? green : Colors.grey,
            ),
            onPressed: () => setState(() => tab = 0),
          ),
          IconButton(
            icon: Icon(Icons.bar_chart, color: tab == 1 ? green : Colors.grey),
            onPressed: () => setState(() => tab = 1),
          ),
          const SizedBox(width: 48),
          IconButton(
            icon: const Icon(Icons.description_outlined, color: Colors.grey),
            onPressed: () => go(context, const PersonalLedger()),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.grey),
            onPressed: () => go(context, const Privacy()),
          ),
        ],
      ),
    ),
  );
}
