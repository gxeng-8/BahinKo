/// Sample data used until the Firestore backend is connected.
///
/// BACKEND STEP: these lists will be replaced by `FirestoreService` streams.
/// Screens read data through [groups] / [Group.members], so only this file
/// and the service need to change.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/models/receipt_line_item.dart';
import 'package:bahinko/theme/app_colors.dart';

// ---------- People ----------

const people = [
  Person('Mia', 'MI', green, 'Paid the bill', 'Paid'),
  Person('Jun', 'JU', orange, 'GCash', 'Owes ₱220'),
  Person('Ana', 'AN', purple, 'Maya', 'Paid'),
  Person('Leo', 'LE', deep, 'Cash', 'Owes ₱430'),
  Person('You', 'YO', Color(0xFF5ED38A), 'GCash', 'Owes ₱490'),
];

/// The current user, used as the default first member of new groups.
final you = people.last;

/// Members of the sample group "Dinner at Jaro".
final ValueNotifier<List<Person>> groupMembers = ValueNotifier(people);

const memberColors = [green, orange, purple, deep, Color(0xFF5ED38A)];

/// Builds a new [Person] from a typed name: initials from the first and
/// last word ("Rico Santos" → "RS"), and the next color in [memberColors].
Person personFromName(String name, {int colorIndex = 0, String pay = 'Guest'}) {
  final normalizedName = name.trim();
  final nameParts = normalizedName.split(RegExp(r'\s+'));
  final initials = nameParts.length > 1
      ? '${nameParts.first[0]}${nameParts.last[0]}'
      : nameParts.first.substring(0, min(2, nameParts.first.length));
  final color = memberColors[colorIndex % memberColors.length];
  return Person(normalizedName, initials.toUpperCase(), color, pay, 'Unpaid');
}

/// Adds a guest member by name to [to] (defaults to the sample group).
void addMember(String name, {ValueNotifier<List<Person>>? to}) {
  final list = to ?? groupMembers;
  list.value = [
    ...list.value,
    personFromName(name, colorIndex: list.value.length),
  ];
}

// ---------- Groups ----------

/// The sample group shown on Home and used as the default by group screens.
final demoGroup = Group(
  id: 'dinner-jaro',
  name: 'Dinner at Jaro',
  category: categoryNamed('Dinner'),
  members: groupMembers,
  inviteCode: 'DJ7Q2',
  expenses: const [
    GroupExpense(
      title: 'Samgyup House',
      paidBy: 'You',
      splitWays: 5,
      amountCents: 250000,
      unpaidCount: 3,
      icon: Icons.restaurant_outlined,
    ),
    GroupExpense(
      title: 'Milk Tea Run',
      paidBy: 'Mia',
      splitWays: 3,
      amountCents: 45000,
      unpaidCount: 0,
      icon: Icons.local_cafe_outlined,
    ),
  ],
);

/// All of the user's groups. Home listens to this, so a group created on the
/// Create Group screen appears immediately.
final ValueNotifier<List<Group>> groups = ValueNotifier([
  demoGroup,
  Group(
    id: 'boarding-house',
    name: 'Boarding House Bills',
    category: categoryNamed('Boarding'),
    members: ValueNotifier(people.sublist(1, 5)),
    inviteCode: 'BH4K9',
    expenses: const [
      GroupExpense(
        title: 'Rent',
        paidBy: 'Carla',
        splitWays: 4,
        amountCents: 1200000,
        unpaidCount: 1,
        icon: Icons.home_outlined,
      ),
    ],
  ),
]);

/// Creates a group, adds it to [groups], and returns it.
Group addGroup({
  required String name,
  required GroupCategory category,
  required List<Person> members,
}) {
  final group = Group(
    id: '${DateTime.now().millisecondsSinceEpoch}',
    name: name.trim(),
    category: category,
    members: ValueNotifier(members),
    inviteCode: _randomCode(),
  );
  groups.value = [...groups.value, group];
  return group;
}

/// 5-character invite code without look-alike characters (no 0/O, 1/I).
String _randomCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = Random();
  return List.generate(5, (_) => chars[rng.nextInt(chars.length)]).join();
}

// ---------- Receipt sample ----------

const items = [
  ReceiptLineItem('Pork Belly set', 89000),
  ReceiptLineItem('Rice x5', 25000),
  ReceiptLineItem('Iced Tea x2', 30000),
  ReceiptLineItem('Soju', 42000),
  ReceiptLineItem('Service and tax', 59000),
];

const shares = [49000, 61000, 52000, 43000, 40000];
