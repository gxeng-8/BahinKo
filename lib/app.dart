/// Root MaterialApp: theme, phone-width frame, and start screen.
library;

import 'package:flutter/material.dart';
import 'package:bahinko/screens/onboarding/onboarding_screen.dart';
import 'package:bahinko/theme/app_colors.dart';

class BahinKoApp extends StatelessWidget {
  const BahinKoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'BahinKo',
    theme: ThemeData(
      colorSchemeSeed: green,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF8FAF9),
    ),
    builder: (context, child) => LayoutBuilder(
      builder: (context, constraints) {
        final appWidth = constraints.maxWidth < 430
            ? constraints.maxWidth
            : 430.0;

        return ColoredBox(
          color: const Color(0xFFEFF3F1),
          child: Center(
            child: SizedBox(
              width: appWidth,
              height: constraints.maxHeight,
              child: child,
            ),
          ),
        );
      },
    ),
    home: const Onboarding(),
  );
}
