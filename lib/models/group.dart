/// Group-related models: a group's category, its expenses, and the group
/// itself. These are plain Dart classes; later the Firestore service will
/// build them from documents (see DEVELOPMENT_PLAN.md §3.3).
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
}

/// A group of people who split bills together ("Dinner at Jaro").
class Group {
  Group({
    required this.id,
    required this.name,
    required this.category,
    required this.members,
    required this.inviteCode,
    List<GroupExpense>? expenses,
  }) : expenses = expenses ?? [];

  final String id;
  final String name;
  final GroupCategory category;

  /// Members are in a ValueNotifier so screens rebuild when someone is added.
  final ValueNotifier<List<Person>> members;
  final List<GroupExpense> expenses;

  /// Short code used in the invite link and QR code.
  final String inviteCode;

  String get inviteLink => 'https://bahinko.app/j/$inviteCode';

  /// Total of all expenses, in centavos.
  int get totalCents => expenses.fold(0, (sum, e) => sum + e.amountCents);

  /// Number of member-payments still unpaid across all expenses.
  int get unpaidCount => expenses.fold(0, (sum, e) => sum + e.unpaidCount);
}
