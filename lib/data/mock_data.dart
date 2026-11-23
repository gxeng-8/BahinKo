/// Sample data: used by widget tests (via InMemoryGroupService) and by the
/// receipt/settle screens that aren't connected to Firestore yet.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/models/person.dart';
import 'package:bahinko/models/receipt_line_item.dart';
import 'package:bahinko/theme/app_colors.dart';

// ---------- People ----------

const people = [
  Person('Mia', 'MI', green, 'Paid the bill', 'Paid', id: 'mia'),
  Person('Jun', 'JU', orange, 'GCash', 'Owes ₱220', id: 'jun'),
  Person('Ana', 'AN', purple, 'Maya', 'Paid', id: 'ana'),
  Person('Leo', 'LE', deep, 'Cash', 'Owes ₱430', id: 'leo'),
  Person(
    'You',
    'YO',
    Color(0xFF5ED38A),
    'GCash',
    'Owes ₱490',
    id: 'me', // same as InMemoryGroupService.myUid
  ),
];

/// The current user in the sample data.
final you = people.last;

/// Members of the sample group "Dinner at Jaro".
// TODO(M3/M4): the receipt and settle screens still read this list.
// Switch them to GroupService.instance.watchGroup(groupId) instead.
final ValueNotifier<List<Person>> groupMembers = ValueNotifier(people);

// ---------- Receipt sample ----------

const items = [
  ReceiptLineItem('Pork Belly set', 89000),
  ReceiptLineItem('Rice x5', 25000),
  ReceiptLineItem('Iced Tea x2', 30000),
  ReceiptLineItem('Soju', 42000),
  ReceiptLineItem('Service and tax', 59000),
];

const shares = [49000, 61000, 52000, 43000, 40000];
