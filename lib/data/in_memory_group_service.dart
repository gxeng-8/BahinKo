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
import 'package:bahinko/models/recurring_bill.dart';
import 'package:bahinko/services/group_service.dart';

/// ID of the sample "Dinner at Jaro" group (the default for group screens).
const demoGroupId = 'dinner-jaro';

class InMemoryGroupService extends GroupService {
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
      createdBy: myUid,
      memberIds: const [myUid], // everyone else is a guest here
      totalCents: 295000,
      expenseCount: 2,
      unpaidCount: 3,
    ),
    Group(
      id: 'boarding-house',
      name: 'Boarding House Bills',
      category: categoryNamed('Boarding'),
      members: people.sublist(0, 4), // Mia, Jun, Ana, Leo (not you)
      inviteCode: 'BH4K9',
      memberIds: const ['mia'],
      createdBy: 'someone-else', // you're not in this one: try joining it
      totalCents: 1200000,
      expenseCount: 1,
      unpaidCount: 1,
    ),
  ];

  final Map<String, List<GroupExpense>> _expenses = {
    demoGroupId: [
      GroupExpense(
        id: 'samgyup',
        title: 'Samgyup House',
        paidBy: 'You',
        paidById: myUid,
        splitWays: 5,
        amountCents: 250000,
        unpaidCount: 3,
        category: 'Dinner',
        icon: Icons.restaurant_outlined,
        spentOn: DateTime(2026, 10, 28),
        shares: const {
          'me': 47000,
          'mia': 32000,
          'jun': 69500,
          'ana': 62000,
          'leo': 39500,
        },
        items: const [
          ExpenseItem(name: 'Pork belly set', amountCents: 90000),
          ExpenseItem(name: 'Rice x5', amountCents: 25000),
          ExpenseItem(name: 'Iced tea x2', amountCents: 30000),
          ExpenseItem(name: 'Soju x3', amountCents: 45000),
          ExpenseItem(name: 'Service charge', amountCents: 25000),
          ExpenseItem(name: 'VAT', amountCents: 35000),
        ],
      ),
      GroupExpense(
        id: 'milktea',
        title: 'Milk Tea Run',
        paidBy: 'Mia',
        paidById: 'mia',
        splitWays: 3,
        amountCents: 45000,
        unpaidCount: 0,
        category: 'Dinner',
        icon: Icons.local_cafe_outlined,
        spentOn: DateTime(2026, 10, 28),
        shares: const {'mia': 15000, 'me': 15000, 'jun': 15000},
      ),
    ],
  };

  final Map<String, List<Payment>> _payments = {};
  final Map<String, List<ActivityEvent>> _activity = {};
  final Map<String, List<RecurringBill>> _recurring = {};
  int _nextId = 0;
  String _newId(String prefix) => '$prefix-${_nextId++}';

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
      members: [
        appUserPerson(myUid, null, role: 'Group creator'),
        ...others,
      ],
      inviteCode: generateInviteCode(),
      createdBy: myUid,
      memberIds: const [myUid],
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
        personFromName(name, colorIndex: list.length, id: _newId('guest')),
      ]; // the groupMembers listener notifies the streams
      return;
    }
    final i = _groups.indexWhere((g) => g.id == groupId);
    if (i == -1) throw const GroupFailure('This group no longer exists.');
    final g = _groups[i];
    _groups[i] = g.copyWith(
      members: [
        ...g.members,
        personFromName(name, id: _newId('guest')),
      ],
    );
    _notifyAll();
  }

  @override
  Future<String> joinGroup(String code, String yourName) async {
    final i = _groups.indexWhere((g) => g.inviteCode == code);
    if (i == -1) {
      throw GroupFailure(
        'No group found with code $code. Check the code and try again.',
      );
    }
    final g = groups[i];
    final alreadyIn = g.members.any((m) => m.id == myUid);
    if (!alreadyIn) {
      final me = appUserPerson(myUid, yourName);
      final base = _groups[i];
      _groups[i] = Group(
        id: base.id,
        name: base.name,
        category: base.category,
        members: g.id == demoGroupId ? base.members : [...base.members, me],
        inviteCode: base.inviteCode,
        createdBy: base.createdBy,
        memberIds: [...base.memberIds, myUid],
        totalCents: base.totalCents,
        expenseCount: base.expenseCount,
        unpaidCount: base.unpaidCount,
        createdAt: base.createdAt,
      );
      if (g.id == demoGroupId) {
        groupMembers.value = [...groupMembers.value, me];
      } else {
        _notifyAll();
      }
    }
    return g.id;
  }

  /// Nothing to publish: codes are looked up directly in memory.
  @override
  Future<void> ensureInvite(Group group) async {}

  @override
  String get myId => myUid;

  void _log(String groupId, ActivityEvent e) {
    _activity
        .putIfAbsent(groupId, () => [])
        .insert(
          0,
          ActivityEvent(
            id: _newId('event'),
            type: e.type,
            text: e.text,
            actorName: e.actorName,
            actorId: e.actorId.isEmpty ? myUid : e.actorId,
            forIds: e.forIds,
            amountCents: e.amountCents,
            oldCents: e.oldCents,
            newCents: e.newCents,
            createdAt: DateTime.now(),
          ),
        );
  }

  /// Replaces group [groupId] using [change] (groups are immutable).
  void _updateGroup(String groupId, Group Function(Group g) change) {
    final i = _groups.indexWhere((g) => g.id == groupId);
    if (i == -1) throw const GroupFailure('This group no longer exists.');
    _groups[i] = change(_groups[i]);
  }

  Group _withTotals(Group g, {int total = 0, int count = 0, int unpaid = 0}) =>
      Group(
        id: g.id,
        name: g.name,
        category: g.category,
        members: g.members,
        inviteCode: g.inviteCode,
        createdBy: g.createdBy,
        memberIds: g.memberIds,
        totalCents: g.totalCents + total,
        expenseCount: g.expenseCount + count,
        unpaidCount: g.unpaidCount + unpaid,
        createdAt: g.createdAt,
      );

  // ---------- Expenses ----------

  @override
  Stream<GroupExpense> watchExpense(String groupId, String expenseId) => _watch(
    () => (_expenses[groupId] ?? const <GroupExpense>[]).firstWhere(
      (e) => e.id == expenseId,
      orElse: () => throw const GroupFailure('This expense was deleted.'),
    ),
  );

  @override
  Future<String> addExpense(String groupId, GroupExpense expense) async {
    checkExpense(expense);
    final id = _newId('expense');
    final saved = expense.copyWith(id: id, createdAt: DateTime.now());
    _updateGroup(
      groupId,
      (g) => _withTotals(g, total: expense.amountCents, count: 1),
    );
    _expenses.putIfAbsent(groupId, () => []).insert(0, saved);
    _log(
      groupId,
      ActivityEvent(
        type: 'expense',
        actorName: 'You',
        forIds: expense.shares.keys.toList(),
        text: 'You added ${expense.title}',
        amountCents: expense.amountCents,
      ),
    );
    _notifyAll();
    return id;
  }

  @override
  Future<void> updateExpense(
    String groupId,
    GroupExpense old,
    GroupExpense updated,
  ) async {
    checkExpense(updated);
    final list = _expenses[groupId] ?? [];
    final i = list.indexWhere((x) => x.id == old.id);
    if (i == -1) throw const GroupFailure('This expense was deleted.');
    list[i] = updated.copyWith(id: old.id, createdAt: list[i].createdAt);
    _updateGroup(
      groupId,
      (g) => _withTotals(g, total: updated.amountCents - old.amountCents),
    );
    final changed = old.amountCents != updated.amountCents;
    _log(
      groupId,
      ActivityEvent(
        type: 'edit',
        actorName: 'You',
        forIds: {...old.shares.keys, ...updated.shares.keys}.toList(),
        text: 'You edited ${updated.title}',
        oldCents: changed ? old.amountCents : null,
        newCents: changed ? updated.amountCents : null,
      ),
    );
    _notifyAll();
  }

  @override
  Future<void> deleteExpense(String groupId, GroupExpense expense) async {
    final list = _expenses[groupId] ?? [];
    final before = list.length;
    list.removeWhere((x) => x.id == expense.id);
    if (list.length == before) {
      throw const GroupFailure('This expense was already deleted.');
    }
    _updateGroup(
      groupId,
      (g) => _withTotals(g, total: -expense.amountCents, count: -1),
    );
    _log(
      groupId,
      ActivityEvent(
        type: 'edit',
        actorName: 'You',
        forIds: expense.shares.keys.toList(),
        text: 'You deleted ${expense.title}',
        amountCents: expense.amountCents,
      ),
    );
    _notifyAll();
  }

  // ---------- Payments ----------

  @override
  Stream<List<Payment>> watchPayments(String groupId) =>
      _watch(() => List.of(_payments[groupId] ?? const <Payment>[]));

  @override
  Future<void> recordPayment(String groupId, Payment payment) async {
    checkPayment(payment);
    _payments
        .putIfAbsent(groupId, () => [])
        .insert(
          0,
          Payment(
            id: _newId('payment'),
            fromId: payment.fromId,
            fromName: payment.fromName,
            toId: payment.toId,
            toName: payment.toName,
            amountCents: payment.amountCents,
            method: payment.method,
            status: payment.status,
            expenseId: payment.expenseId,
            reference: payment.reference,
            createdAt: DateTime.now(),
          ),
        );
    _log(
      groupId,
      ActivityEvent(
        type: 'payment',
        actorName: payment.fromName,
        actorId: payment.fromId,
        forIds: [payment.toId],
        text: '${payment.fromName} paid ${payment.toName}',
        amountCents: payment.amountCents,
      ),
    );
    _notifyAll();
  }

  @override
  Future<void> confirmPayment(
    String groupId,
    Payment payment, {
    bool fullShare = true,
  }) async {
    final list = _payments[groupId] ?? [];
    final i = list.indexWhere((p) => p.id == payment.id);
    if (i == -1) throw const GroupFailure('This payment was deleted.');
    final p = list[i];
    list[i] = Payment(
      id: p.id,
      fromId: p.fromId,
      fromName: p.fromName,
      toId: p.toId,
      toName: p.toName,
      amountCents: p.amountCents,
      method: p.method,
      status: 'confirmed',
      expenseId: p.expenseId,
      reference: p.reference,
      createdAt: p.createdAt,
    );
    if (fullShare && p.expenseId != null) {
      _updateGroup(groupId, (g) => _withTotals(g, unpaid: -1));
      final expenses = _expenses[groupId] ?? [];
      final e = expenses.indexWhere((x) => x.id == p.expenseId);
      if (e != -1) {
        final x = expenses[e];
        expenses[e] = x.copyWith(unpaidCount: x.unpaidCount - 1);
      }
    }
    _log(
      groupId,
      ActivityEvent(
        type: 'confirm',
        actorName: p.toName,
        actorId: p.toId,
        forIds: [p.fromId],
        text: "${p.toName} confirmed ${p.fromName}'s payment",
        amountCents: p.amountCents,
      ),
    );
    _notifyAll();
  }

  // ---------- Activity ----------

  @override
  Stream<List<ActivityEvent>> watchActivity(String groupId) =>
      _watch(() => List.of(_activity[groupId] ?? const <ActivityEvent>[]));

  @override
  Future<void> logActivity(String groupId, ActivityEvent event) async {
    _log(groupId, event);
    _notifyAll();
  }

  // ---------- Recurring bills ----------

  @override
  Stream<List<RecurringBill>> watchRecurring(String groupId) => _watch(
    () =>
        List.of(_recurring[groupId] ?? const <RecurringBill>[])
          ..sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth)),
  );

  @override
  Future<void> addRecurring(String groupId, RecurringBill bill) async {
    if (bill.name.trim().isEmpty) {
      throw const GroupFailure('Give the bill a name.');
    }
    _recurring
        .putIfAbsent(groupId, () => [])
        .add(
          RecurringBill(
            bill.name,
            bill.schedule,
            bill.amount,
            bill.enabled,
            id: _newId('bill'),
            amountCents: bill.amountCents,
            dayOfMonth: bill.dayOfMonth,
            varies: bill.varies,
          ),
        );
    _notifyAll();
  }

  @override
  Future<void> setRecurringEnabled(
    String groupId,
    String billId,
    bool enabled,
  ) async {
    final bill = (_recurring[groupId] ?? const <RecurringBill>[]).firstWhere(
      (b) => b.id == billId,
      orElse: () => throw const GroupFailure('This bill was deleted.'),
    );
    bill.enabled = enabled;
    _notifyAll();
  }

  @override
  Future<void> deleteRecurring(String groupId, String billId) async {
    _recurring[groupId]?.removeWhere((b) => b.id == billId);
    _notifyAll();
  }

  @override
  Future<void> leaveAllGroups() async {
    _groups.clear();
    _notifyAll();
  }

  @override
  Future<void> setUnpaidCount(String groupId, int count) async {
    final i = _groups.indexWhere((g) => g.id == groupId);
    if (i == -1) return;
    final g = _groups[i];
    if (g.unpaidCount == count) return;
    _groups[i] = _withTotals(g, unpaid: count - g.unpaidCount);
    _notifyAll();
  }
}
