/// Rounded mint square with a green icon, used for quick actions
/// (Scan, Add, Settle Up), group categories, and list-item leading icons.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/theme/app_colors.dart';

class IconTile extends StatelessWidget {
  const IconTile(
    this.icon, {
    super.key,
    this.label,
    this.onTap,
    this.size = 48,
  });

  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: mint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: green, size: size * 0.45),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(label!, style: const TextStyle(fontSize: 11, color: ink)),
        ],
      ],
    ),
  );
}
