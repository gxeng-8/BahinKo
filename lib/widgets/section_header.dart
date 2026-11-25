/// Section title with an optional green "See all" link on the right,
/// e.g. "Members ........ See all".
library;

import 'package:flutter/material.dart';

import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionText, this.onAction});

  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(title, style: AppText.section)),
        if (actionText != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionText!,
              style: const TextStyle(
                color: green,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    ),
  );
}
