/// Sample data and the in-memory member list. Will be replaced by Firestore.
library;

import 'package:flutter/material.dart';
import 'package:bahinko/models/receipt_line_item.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/theme/app_colors.dart';

const people = [
  Person('Mia', 'MI', green, 'Paid the bill', 'Paid'),
  Person('Jun', 'JU', orange, 'GCash', 'Owes ₱220'),
  Person('Ana', 'AN', purple, 'Maya', 'Paid'),
  Person('Leo', 'LE', deep, 'Cash', 'Owes ₱430'),
  Person('You', 'YO', Color(0xFF5ED38A), 'GCash', 'Owes ₱490'),
];

final ValueNotifier<List<Person>> groupMembers = ValueNotifier(people);

const memberColors = [green, orange, purple, deep, Color(0xFF5ED38A)];

void addMember(String name) {
  final normalizedName = name.trim();
  final nameParts = normalizedName.split(RegExp(r'\s+'));
  final initials = nameParts.length > 1
      ? '${nameParts.first[0]}${nameParts.last[0]}'
      : nameParts.first.substring(
          0,
          nameParts.first.length < 2 ? nameParts.first.length : 2,
        );
  final color = memberColors[groupMembers.value.length % memberColors.length];
  groupMembers.value = [
    ...groupMembers.value,
    Person(normalizedName, initials.toUpperCase(), color, 'Guest', 'Unpaid'),
  ];
}

const items = [
  ReceiptLineItem('Pork Belly set', 89000),
  ReceiptLineItem('Rice x5', 25000),
  ReceiptLineItem('Iced Tea x2', 30000),
  ReceiptLineItem('Soju', 42000),
  ReceiptLineItem('Service and tax', 59000),
];

const shares = [49000, 61000, 52000, 43000, 40000];
