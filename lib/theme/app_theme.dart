/// App-wide ThemeData and text styles matching the Figma prototype.
///
/// Fonts (bundled in assets/fonts, declared in pubspec.yaml):
/// * LilitaOne: rounded display font for titles ("BahinKo", "Assign Items").
/// * Poppins: body text.
/// If your Figma file uses different fonts, check its Inspect panel, swap
/// the files in assets/fonts, and change [displayFont] / [bodyFont].
library;

import 'package:flutter/material.dart';

import 'package:bahinko/theme/app_colors.dart';

const displayFont = 'LilitaOne';
const bodyFont = 'Poppins';

/// Reusable text styles. Example: `Text('Assign Items', style: AppText.title)`.
class AppText {
  AppText._();

  /// Big brand/screen text ("BahinKo", "Welcome back").
  static TextStyle display(double size, {Color color = ink}) =>
      TextStyle(fontFamily: displayFont, fontSize: size, color: color);

  /// App bar titles ("Assign Items", "Settle Up").
  static const title = TextStyle(
    fontFamily: displayFont,
    fontSize: 20,
    color: deep,
  );

  /// Section headings ("Members", "Expenses", "This month").
  static const section = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: ink,
  );

  /// Large money amounts ("₱2,500.00").
  static TextStyle money(double size, {Color color = ink}) =>
      TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: color);

  /// Small grey helper text under titles and inside cards.
  static const caption = TextStyle(fontSize: 12, color: muted);
}

/// Builds the single ThemeData used by [MaterialApp].
ThemeData buildAppTheme() {
  // Rounded outlined input that turns green when focused (Figma "Amount" field).
  OutlineInputBorder outline(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: bodyFont,
    colorScheme: ColorScheme.fromSeed(seedColor: green, primary: green),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppText.title,
      iconTheme: IconThemeData(color: deep),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: const TextStyle(color: muted),
      border: outline(border),
      enabledBorder: outline(border),
      focusedBorder: outline(green, 1.5),
      errorBorder: outline(errorFg),
      focusedErrorBorder: outline(errorFg, 1.5),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: green,
      side: BorderSide(color: border),
      shape: StadiumBorder(),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: deep,
      shape: StadiumBorder(),
    ),
  );
}
