/// Full-width buttons from the Figma prototype.
///
/// * Primary: green gradient fill, white text ("Scan Receipt", "Save Expense").
/// * Outlined: white fill, green border and text ("Enter Manually", "Settle Up").
library;

import 'package:flutter/material.dart';

import 'package:bahinko/theme/app_colors.dart';

class Btn extends StatelessWidget {
  final String text;

  /// Pass `null` to show the button as disabled (e.g. while a form is invalid).
  final VoidCallback? onTap;
  final bool outlined;

  /// Optional solid color that replaces the gradient (e.g. white on a green bg).
  final Color? color;
  final IconData? icon;

  const Btn(
    this.text,
    this.onTap, {
    super.key,
    this.outlined = false,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    final enabled = onTap != null;
    // White buttons (on green backgrounds) get green text; others get white.
    final fg = outlined || color == Colors.white ? green : Colors.white;

    final label = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: outlined ? Colors.white : color,
              gradient: outlined || color != null ? null : brandGradient,
              border: outlined ? Border.all(color: green, width: 1.5) : null,
            ),
            child: InkWell(borderRadius: radius, onTap: onTap, child: label),
          ),
        ),
      ),
    );
  }
}
