/// A member of a group (an app user or a guest without the app).
library;

import 'dart:math';
import 'dart:ui';

import 'package:bahinko/theme/app_colors.dart';

class Person {
  final String name, initials, pay, status;
  final Color color;

  /// Firebase user ID for app users; a generated "guest-…" ID for guests.
  /// Empty for the built-in sample people.
  final String id;

  const Person(
    this.name,
    this.initials,
    this.color,
    this.pay,
    this.status, {
    this.id = '',
  });

  /// Converts to a plain map so it can be saved in Firestore.
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'initials': initials,
    'color': color.toARGB32(), // colors are stored as one int (0xAARRGGBB)
    'pay': pay,
    'status': status,
  };

  /// Rebuilds a Person from a Firestore map. Missing fields get safe
  /// defaults so one bad document can't crash the screen.
  factory Person.fromMap(Map<String, dynamic> map) => Person(
    map['name'] as String? ?? 'Member',
    map['initials'] as String? ?? '?',
    Color((map['color'] as num?)?.toInt() ?? 0xFF0A9B7A),
    map['pay'] as String? ?? '',
    map['status'] as String? ?? '',
    id: map['id'] as String? ?? '',
  );
}

/// Avatar colors, picked in turn for new members.
const memberColors = [green, orange, purple, deep, Color(0xFF5ED38A)];

/// Builds a [Person] from a typed name: initials from the first and last
/// word ("Rico Santos" → "RS") and a color from [memberColors].
Person personFromName(
  String name, {
  int? colorIndex,
  String id = '',
  String pay = 'Guest',
}) {
  final normalizedName = name.trim();
  final nameParts = normalizedName.split(RegExp(r'\s+'));
  final initials = nameParts.length > 1
      ? '${nameParts.first[0]}${nameParts.last[0]}'
      : nameParts.first.substring(0, min(2, nameParts.first.length));
  // Same name → same color on every phone. (Sum of character codes:
  // unlike hashCode, it's the same on every device.)
  final index =
      colorIndex ?? normalizedName.codeUnits.fold<int>(0, (a, b) => a + b);
  return Person(
    normalizedName,
    initials.toUpperCase(),
    memberColors[index % memberColors.length],
    pay,
    'Settled',
    id: id,
  );
}
