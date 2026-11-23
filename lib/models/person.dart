/// A member of a group (an app user or a guest without the app).
library;

import 'dart:ui';

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
