/// Small rounded status label, e.g. "Paid", "Unpaid", "Needs review".
library;

import 'package:flutter/material.dart';

import 'package:bahinko/theme/app_colors.dart';

class Pill extends StatelessWidget {
  final String text;
  final Color bg, fg;
  final IconData? icon;

  const Pill(
    this.text, {
    super.key,
    this.bg = mint,
    this.fg = green,
    this.icon,
  });

  /// Green "Paid" pill.
  const Pill.paid({super.key, this.text = 'Paid'})
    : bg = paidBg,
      fg = paidFg,
      icon = null;

  /// Orange "Unpaid" pill. Custom text: `Pill.unpaid(text: '3 unpaid')`.
  const Pill.unpaid({super.key, this.text = 'Unpaid'})
    : bg = unpaidBg,
      fg = unpaidFg,
      icon = null;

  /// Orange warning pill shown when the AI is unsure about a receipt item.
  const Pill.needsReview({super.key, this.text = 'Needs review'})
    : bg = unpaidBg,
      fg = unpaidFg,
      icon = Icons.warning_amber_rounded;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: TextStyle(
            color: fg,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
