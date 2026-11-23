/// A [GroupService] that keeps groups in memory instead of Firestore.
///
/// Used by widget tests (they can't connect to Firebase) and as the
/// default before main() switches to FirestoreGroupService. It starts with
/// two sample groups so screens have something to show.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/services/group_service.dart';

/// ID of the sample "Dinner at Jaro" group (the default for group screens).
const demoGroupId = 'dinner-jaro';

class InMemoryGroupService implements GroupService {
  InMemoryGroupService() {
    // The sample group's members live in the shared `groupMembers` list
    // (the receipt screens still read it), so re-emit when it changes.
    groupMembers.addListener(_notifyAll);
  }

  static const myUid = 'me';

  final List<Group> _groups = [
    Group(
      id: demoGroupId,
      name: 'Dinner at Jaro',
      category: categoryNamed('Dinner'),
      members: const [], // read live from groupMembers, see [groups]
      inviteCode: 'DJ7Q2',
      totalCents: 295000,
      expenseCount: 2,
      unpaidCount: 3,
    ),
    Group(
      id: 'boarding-house',
      name: 'Boarding House Bills',
      category: categoryNamed('Boarding'),
      members: people.sublist(1, 5),
      inviteCode: 'BH4K9',
      totalCents: 1200000,
      expenseCount: 1,
      unpaidCount: 1,
    ),
  ];

  final Map<String, List<GroupExpense>> _expenses = {
    demoGroupId: const [
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
  };

  /// Callbacks of every open stream; called whenever data changes.
  final Set<VoidCallback> _listeners = {};

  /// Current groups (the sample group gets its live member list).
  List<Group> get groups => [
    for (final g in _groups)
      g.id == demoGroupId ? g.copyWith(members: groupMembers.value) : g,
  ];

  void _notifyAll() {
    for (final listener in _listeners.toList()) {
      listener();
    }
  }

  /// Turns a "read current value" function into a Stream that emits now
  /// and again after every change, like Firestore's snapshots().
  Stream<T> _watch<T>(T Function() read) {
    late final StreamController<T> controller;
    void push() {
      try {
        controller.add(read());
      } catch (e) {
        controller.addError(e);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        push();
        _listeners.add(push);
      },
      onCancel: () => _listeners.remove(push),
    );
    return controller.stream;
  }

  @override
  Stream<List<Group>> watchMyGroups() => _watch(() => groups);

  @override
  Stream<Group> watchGroup(String groupId) => _watch(
    () => groups.firstWhere(
      (g) => g.id == groupId,
      orElse: () => throw const GroupFailure('This group no longer exists.'),
    ),
  );

  @override
  Stream<List<GroupExpense>> watchExpenses(String groupId) =>
      _watch(() => _expenses[groupId] ?? const []);

  @override
  Future<Group> createGroup({
    required String name,
    required GroupCategory category,
    required List<Person> others,
  }) async {
    final group = Group(
      id: 'group-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      category: category,
      members: [ownerPerson(myUid), ...others],
      inviteCode: generateInviteCode(),
      createdAt: DateTime.now(),
    );
    _groups.insert(0, group); // newest first, like Firestore
    _notifyAll();
    return group;
  }

  @override
  Future<void> addGuest(String groupId, String name) async {
    if (groupId == demoGroupId) {
      final list = groupMembers.value;
      groupMembers.value = [
        ...list,
        personFromName(name, colorIndex: list.length),
      ]; // the groupMembers listener notifies the streams
      return;
    }
    final i = _groups.indexWhere((g) => g.id == groupId);
    if (i == -1) throw const GroupFailure('This group no longer exists.');
    final g = _groups[i];
    _groups[i] = g.copyWith(members: [...g.members, personFromName(name)]);
    _notifyAll();
  }
}
