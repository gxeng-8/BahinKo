/// Light-green note with an icon, used for trust/helper messages such as
/// "Receipts are processed securely and can be deleted anytime."
library;

import 'package:flutter/material.dart';

import 'package:bahinko/theme/app_colors.dart';

class InfoBanner extends StatelessWidget {
  const InfoBanner(
    this.text, {
    super.key,
    this.icon = Icons.verified_user_outlined,
    this.color = bannerBg,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: deep),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, color: deep)),
        ),
      ],
    ),
  );
}
