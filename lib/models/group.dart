/// Group-related models: a group's category, its expenses, and the group
/// itself. These are plain, immutable Dart classes with no Firebase code;
/// the services convert them to and from Firestore documents.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/models/person.dart';

/// What kind of group this is (Trip, Boarding, Dinner…). Used by the Home
/// category grid, the Create Group dropdown, and the group's icon.
class GroupCategory {
  const GroupCategory(this.name, this.icon, this.hint);

  final String name;
  final IconData icon;

  /// Typical expenses, shown in the dropdown ("Transport, Food, Lodging").
  final String hint;
}

/// All categories, in the order shown on the Home screen grid.
const groupCategories = [
  GroupCategory('Dinner', Icons.restaurant_outlined, 'Food, Drinks, Service'),
  GroupCategory('Boarding', Icons.home_outlined, 'Rent, WiFi, Electricity'),
  GroupCategory('Trips', Icons.flight_outlined, 'Transport, Food, Lodging'),
  GroupCategory('Utilities', Icons.bolt_outlined, 'Water, Electricity, Gas'),
  GroupCategory('Subscriptions', Icons.repeat, 'Streaming, Apps, Memberships'),
  GroupCategory('Groceries', Icons.shopping_cart_outlined, 'Food, Supplies'),
  GroupCategory('Bills', Icons.receipt_long_outlined, 'Any shared bill'),
  GroupCategory('Custom', Icons.add, 'Start from scratch'),
];

/// Looks up a category by name; falls back to "Custom".
GroupCategory categoryNamed(String name) => groupCategories.firstWhere(
  (c) => c.name == name,
  orElse: () => groupCategories.last,
);

/// One expense inside a group (e.g. "Samgyup House ₱2,500").
/// Stored in Firestore at groups/{groupId}/expenses/{expenseId}.
class GroupExpense {
  const GroupExpense({
    required this.title,
    required this.paidBy,
    required this.splitWays,
    required this.amountCents,
    required this.unpaidCount,
    this.icon = Icons.receipt_long_outlined,
  });

  final String title;
  final String paidBy;
  final int splitWays;

  /// Money is always stored as whole centavos to avoid rounding errors.
  final int amountCents;

  /// How many members still owe money for this expense (0 = all settled).
  final int unpaidCount;
  final IconData icon;

  /// Builds an expense from a Firestore map (safe defaults for gaps).
  factory GroupExpense.fromMap(Map<String, dynamic> map) => GroupExpense(
    title: map['title'] as String? ?? 'Expense',
    paidBy: map['paidBy'] as String? ?? '',
    splitWays: (map['splitWays'] as num?)?.toInt() ?? 1,
    amountCents: (map['amountCents'] as num?)?.toInt() ?? 0,
    unpaidCount: (map['unpaidCount'] as num?)?.toInt() ?? 0,
  );
}

/// A group of people who split bills together ("Dinner at Jaro").
/// Stored in Firestore at groups/{groupId}.
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.category,
    required this.members,
    required this.inviteCode,
    this.createdBy = '',
    this.totalCents = 0,
    this.expenseCount = 0,
    this.unpaidCount = 0,
    this.createdAt,
  });

  final String id;
  final String name;
  final GroupCategory category;
  final List<Person> members;

  /// Short code used in the invite link and QR code.
  final String inviteCode;

  /// Summary numbers kept on the group itself, so the Home cards don't
  /// have to load every expense (updated whenever an expense changes).
  final int totalCents;
  final int expenseCount;
  final int unpaidCount;

  /// Null for a moment after creation, until the server sets the time.
  final DateTime? createdAt;

  /// User ID of the person who created the group (may delete it and
  /// publish its invite code).
  final String createdBy;

  String get inviteLink => 'https://bahinko.app/j/$inviteCode';

  /// Returns a copy with a different member list (groups are immutable).
  Group copyWith({List<Person>? members}) => Group(
    id: id,
    name: name,
    category: category,
    members: members ?? this.members,
    inviteCode: inviteCode,
    createdBy: createdBy,
    totalCents: totalCents,
    expenseCount: expenseCount,
    unpaidCount: unpaidCount,
    createdAt: createdAt,
  );
}
