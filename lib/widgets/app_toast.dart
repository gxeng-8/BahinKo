/// Small dark-green confirmation toast with a check icon,
/// e.g. "Reminder sent to Jun" (Figma 15b) or "Report saved to Downloads" (23b).
library;

import 'package:flutter/material.dart';

import 'package:bahinko/theme/app_colors.dart';

void showAppToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: deep,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: lime, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
