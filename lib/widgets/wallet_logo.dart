/// The GCash / Maya logos, used wherever the app names a wallet
/// (Profile chips, Pay buttons, payment dialogs).
///
/// GCash: the round "G" mark. Maya: the green wordmark on its black
/// badge (green on white is too faint to read at small sizes).
/// Anything else (e.g. "Cash") gets a plain money icon.
library;

import 'package:flutter/material.dart';

class WalletLogo extends StatelessWidget {
  const WalletLogo(this.provider, {super.key, this.size = 20});

  /// 'GCash', 'Maya' or 'Cash' (any capitalization).
  final String provider;

  /// Height in pixels. The Maya badge is wider than tall.
  final double size;

  @override
  Widget build(BuildContext context) => switch (provider.toLowerCase()) {
    'gcash' => Image.asset(
      'assets/logos/gcash_mark.png',
      width: size,
      height: size,
      semanticLabel: 'GCash',
    ),
    'maya' => Container(
      height: size,
      width: size * 1.9,
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.22,
        vertical: size * 0.26,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Image.asset('assets/logos/maya.png', semanticLabel: 'Maya'),
    ),
    _ => Icon(Icons.payments_outlined, size: size),
  };
}
