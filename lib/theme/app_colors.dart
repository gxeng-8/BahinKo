/// BahinKo color tokens, taken from the Figma hi-fi prototype.
/// Use these names instead of raw hex values so the whole app stays consistent.
library;

import 'package:flutter/material.dart';

// ---- Brand ----
const green = Color(0xFF0A9B7A); // primary buttons, links, selected states
const greenLight = Color(0xFF12A883); // top of gradients
const deep = Color(0xFF064E3B); // dark text on light bg, bottom of gradients
const mint = Color(0xFFE8F7F0); // soft fills: chips, icon tiles
const lime = Color(0xFFA7F3A0); // accent (recurring bill card)

// ---- Member avatar colors ----
const orange = Color(0xFFE8834A);
const purple = Color(0xFF7C5CD6);

// ---- Neutrals ----
const ink = Color(0xFF10201B); // main body text
const muted = Color(0xFF6B7C76); // secondary text / captions
const border = Color(0xFFDDE7E3); // card and input outlines
const background = Color(0xFFF6F8F7); // screen background

// ---- Status (pills like "Paid", "Unpaid", "Needs review") ----
const paidBg = Color(0xFFDDF5E6);
const paidFg = Color(0xFF0A7A55);
const unpaidBg = Color(0xFFFFEBD2);
const unpaidFg = Color(0xFFB8610A);
const errorFg = Color(0xFFD03A2B);

// ---- Banners ("Receipts are processed securely…") ----
const bannerBg = Color(0xFFDDF5DF);

/// The diagonal green gradient used on headers, hero cards and primary buttons.
const brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [greenLight, deep],
);
