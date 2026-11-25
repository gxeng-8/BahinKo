/// Figma frame 1 "Onboarding": first-run welcome screen.
///
/// REFERENCE SCREEN: shows how to build a screen from the design system.
/// * Colors come from theme/app_colors.dart (never raw hex in screens).
/// * Fonts come from AppText in theme/app_theme.dart.
/// * Buttons use the shared [Btn] widget.
/// * Big pieces are split into small private widgets (_Logo, _PerksCard)
///   so build() stays short and readable.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/screens/auth/app_lock_screen.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/widgets/btn.dart';

class Onboarding extends StatelessWidget {
  const Onboarding({super.key});

  /// Selling points listed in the translucent card.
  static const perks = [
    'Scan receipts and list items automatically',
    'Assign who ordered what',
    'Track payments and send polite reminders',
    'Settle with GCash or Maya',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: brandGradient),
      child: Stack(
        children: [
          // Decorative soft circles in the top-right corner (from Figma).
          const Positioned(top: -60, right: -60, child: _Circle(220)),
          const Positioned(top: 90, right: -90, child: _Circle(160)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
              child: Column(
                children: [
                  const _Logo(),
                  const SizedBox(height: 20),
                  const Text(
                    'Bahinko nang tama, bayad nang kaunti.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Split bills with friends without the awkward math',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 28),
                  const _PerksCard(perks: perks),
                  const Spacer(),
                  Btn(
                    'Get Started',
                    // Next: set up the app-lock PIN, then the main app.
                    // pushReplacement: users can't go "back" to onboarding.
                    () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const AppLockScreen()),
                    ),
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 12, color: Colors.white70),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'We never hold your money. Payments redirect to GCash or Maya.',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// White app-icon tile next to the "BahinKo" wordmark.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.receipt_long, color: green, size: 30),
      ),
      const SizedBox(width: 12),
      Text('BahinKo', style: AppText.display(36, color: Colors.white)),
    ],
  );
}

/// Translucent card listing the app's main features with check marks.
class _PerksCard extends StatelessWidget {
  const _PerksCard({required this.perks});

  final List<String> perks;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white24),
    ),
    child: Column(
      children: [
        for (final perk in perks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: lime,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.check, size: 16, color: deep),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    perk,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Faint white circle used as background decoration.
class _Circle extends StatelessWidget {
  const _Circle(this.size);

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.06),
    ),
  );
}
