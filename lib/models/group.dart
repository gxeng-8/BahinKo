/// Group-related models: a group's category, its expenses, and the group
/// itself. These are plain, immutable Dart classes with no Firebase code;
/// the services convert them to and from Firestore documents.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/models/expense.dart';
import 'package:bahinko/models/person.dart';

export 'package:bahinko/models/expense.dart';

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
///
/// To create one, use [GroupExpense.create] (it fills in the counts) and
/// pass it to GroupService.addExpense().
class GroupExpense {
  const GroupExpense({
    this.id = '',
    required this.title,
    required this.paidBy,
    required this.splitWays,
    required this.amountCents,
    required this.unpaidCount,
    this.icon = Icons.receipt_long_outlined,
    this.category = 'Bills',
    this.paidById = '',
    this.items = const [],
    this.shares = const {},
    this.source = 'manual',
    this.splitMode = 'equal',
    this.spentOn,
    this.createdAt,
  });

  /// Builds a new expense and works out [splitWays] and [unpaidCount]
  /// from [shares] (everyone with a share except the payer still owes).
  factory GroupExpense.create({
    required String title,
    required String paidById,
    required String paidByName,
    required int amountCents,
    required Map<String, int> shares,
    List<ExpenseItem> items = const [],
    String category = 'Bills',
    String source = 'manual',
    String splitMode = 'equal',
    DateTime? spentOn,
  }) => GroupExpense(
    title: title.trim(),
    paidBy: paidByName,
    paidById: paidById,
    amountCents: amountCents,
    shares: shares,
    items: items,
    category: category,
    icon: categoryNamed(category).icon,
    source: source,
    splitMode: splitMode,
    spentOn: spentOn,
    splitWays: shares.length,
    unpaidCount: shares.entries
        .where((s) => s.key != paidById && s.value > 0)
        .length,
  );

  final String id;
  final String title;

  /// Name of the person who paid the bill (shown as "Paid by Mia").
  final String paidBy;
  final String paidById;
  final int splitWays;

  /// Money is always stored as whole centavos to avoid rounding errors.
  final int amountCents;

  /// How many members still owe money for this expense (0 = all settled).
  final int unpaidCount;
  final IconData icon;
  final String category;

  /// The receipt lines (empty for a quick "₱500 for groceries" expense).
  final List<ExpenseItem> items;

  /// What each member owes for this expense: memberId → centavos.
  /// Must add up to [amountCents] (the service checks this).
  final Map<String, int> shares;

  /// 'ai' if it came from the receipt scanner, otherwise 'manual'.
  final String source;

  /// How it was split: 'equal', 'byItem', 'exact', 'percent' or 'shares'
  /// (see utils/split_modes.dart). [shares] already holds the result.
  final String splitMode;

  /// The day the money was spent (the Date field). Null for old expenses;
  /// then [createdAt] is used.
  final DateTime? spentOn;
  final DateTime? createdAt;

  bool get fromAi => source == 'ai';

  /// The day to show: the Date field, or when it was saved.
  DateTime? get date => spentOn ?? createdAt;

  /// A copy with some fields changed (expenses are immutable).
  GroupExpense copyWith({String? id, int? unpaidCount, DateTime? createdAt}) =>
      GroupExpense(
        id: id ?? this.id,
        title: title,
        paidBy: paidBy,
        paidById: paidById,
        splitWays: splitWays,
        amountCents: amountCents,
        unpaidCount: unpaidCount ?? this.unpaidCount,
        icon: icon,
        category: category,
        items: items,
        shares: shares,
        source: source,
        splitMode: splitMode,
        spentOn: spentOn,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
    'title': title,
    'paidBy': paidBy,
    'paidById': paidById,
    'splitWays': splitWays,
    'amountCents': amountCents,
    'unpaidCount': unpaidCount,
    'category': category,
    'items': [for (final i in items) i.toMap()],
    'shares': shares,
    'source': source,
    'splitMode': splitMode,
    // Stored as "2026-10-28": a calendar day, no time zone surprises.
    if (spentOn != null) 'spentOn': _isoDay(spentOn!),
  };

  /// Builds an expense from a Firestore map (safe defaults for gaps).
  factory GroupExpense.fromMap(
    Map<String, dynamic> map, {
    String id = '',
    DateTime? createdAt,
  }) {
    final category = map['category'] as String? ?? 'Bills';
    return GroupExpense(
      id: id,
      title: map['title'] as String? ?? 'Expense',
      paidBy: map['paidBy'] as String? ?? '',
      paidById: map['paidById'] as String? ?? '',
      splitWays: (map['splitWays'] as num?)?.toInt() ?? 1,
      amountCents: (map['amountCents'] as num?)?.toInt() ?? 0,
      unpaidCount: (map['unpaidCount'] as num?)?.toInt() ?? 0,
      category: category,
      icon: categoryNamed(category).icon,
      items: [
        for (final i in map['items'] as List? ?? const [])
          ExpenseItem.fromMap(Map<String, dynamic>.from(i as Map)),
      ],
      shares: {
        for (final e in (map['shares'] as Map? ?? const {}).entries)
          e.key as String: (e.value as num).toInt(),
      },
      source: map['source'] as String? ?? 'manual',
      splitMode: map['splitMode'] as String? ?? 'equal',
      spentOn: DateTime.tryParse(map['spentOn'] as String? ?? ''),
      createdAt: createdAt,
    );
  }

  static String _isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
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
    this.memberIds = const [],
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

  /// IDs of members who have the app (signed-in accounts). Everyone else
  /// in [members] is a guest, so any member may confirm payments to them.
  final List<String> memberIds;

  /// True if [person] has no BahinKo account (added by name).
  bool isGuest(Person person) => !memberIds.contains(person.id);

  /// The member with this ID, or null.
  Person? memberById(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Opens BahinKo straight to "Join" on phones that have the app, and a
  /// small page with the code (and how to get the app) everywhere else.
  /// Hosted free on Firebase Hosting (see hosting/ and firebase.json).
  String get inviteLink => '$inviteLinkBase$inviteCode';

  static const inviteLinkHost = 'bahinko-303f2.web.app';
  static const inviteLinkBase = 'https://$inviteLinkHost/j/';

  /// Returns a copy with a different member list (groups are immutable).
  Group copyWith({List<Person>? members}) => Group(
    id: id,
    name: name,
    category: category,
    members: members ?? this.members,
    inviteCode: inviteCode,
    createdBy: createdBy,
    memberIds: memberIds,
    totalCents: totalCents,
    expenseCount: expenseCount,
    unpaidCount: unpaidCount,
    createdAt: createdAt,
  );
}
