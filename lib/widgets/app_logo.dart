/// The BahinKo logo (the same art as the app icon).
library;

import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/logos/bahinko.png',
    width: size,
    height: size,
    semanticLabel: 'BahinKo logo',
  );
}
