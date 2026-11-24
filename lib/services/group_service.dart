/// The contract for loading and saving groups.
///
/// Screens only talk to [GroupService.instance], never to Firestore
/// directly. Two implementations exist:
/// * [FirestoreGroupService]: the real app (set in main.dart).
/// * [InMemoryGroupService]: sample data for widget tests, which can't
///   use Firebase. It's the default until main() swaps in Firestore.
///
/// Reads return Streams, so screens update automatically when data
/// changes, even when another member edits the group on their phone.
library;

import 'dart:async';
import 'dart:math';

import 'package:bahinko/data/in_memory_group_service.dart';
import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/models/recurring_bill.dart';
import 'package:bahinko/utils/settle_calculator.dart';
import 'package:bahinko/utils/stream_utils.dart';

abstract class GroupService {
  /// The service the whole app uses. main() replaces it with Firestore.
  static GroupService instance = InMemoryGroupService();

  /// All groups the current user is a member of, newest first.
  Stream<List<Group>> watchMyGroups();

  /// One group. Emits a [GroupFailure] error if it doesn't exist.
  Stream<Group> watchGroup(String groupId);

  /// A group's expenses, newest first.
  Stream<List<GroupExpense>> watchExpenses(String groupId);

  /// Creates a group with the current user plus [others] as members.
  Future<Group> createGroup({
    required String name,
    required GroupCategory category,
    required List<Person> others,
  });

  /// Adds a guest (someone without the app) to a group by name.
  Future<void> addGuest(String groupId, String name);

  /// Joins the group with this invite [code] as [yourName].
  /// Returns the group's ID. If you're already a member, just returns it.
  Future<String> joinGroup(String code, String yourName);

  /// Makes sure the group's invite code can be looked up (for groups
  /// created before invite codes were published). Safe to call often.
  Future<void> ensureInvite(Group group);

  /// The current user's member ID: compare with Person.id / Payment.toId
  /// to show "You", and use it as the payer/receiver of your own payments.
  String get myId;

  // ---------- Expenses (M2 scanner, M3 Add Expense / Split Summary) ----------

  /// One expense, live (e.g. for Split Summary).
  Stream<GroupExpense> watchExpense(String groupId, String expenseId);

  /// Saves a new expense, adds it to the group's totals, and logs it in the
  /// activity feed. Build it with [GroupExpense.create]. Throws a
  /// [GroupFailure] if it's invalid (see [checkExpense]). Returns its ID.
  Future<String> addExpense(String groupId, GroupExpense expense);

  /// Replaces expense [old] with [updated] (same ID), fixes the group's
  /// total, and logs "Renz edited Samgyup House" (with old → new amount).
  /// Balances recalculate by themselves. Throws [GroupFailure] if invalid.
  Future<void> updateExpense(
    String groupId,
    GroupExpense old,
    GroupExpense updated,
  );

  /// Deletes [expense], takes it out of the group's totals, and logs it.
  /// Payments already recorded are kept (they are real money that moved).
  Future<void> deleteExpense(String groupId, GroupExpense expense);

  // ---------- Payments (M4 Settle Up) ----------

  /// All payments in the group, newest first.
  Stream<List<Payment>> watchPayments(String groupId);

  /// Saves a payment ("Yes, I paid" / "Paid in cash") and logs it.
  /// Status 'pending' = waiting for the receiver to confirm.
  /// A receiver recording cash they got may save it as 'confirmed'.
  Future<void> recordPayment(String groupId, Payment payment);

  /// The receiver confirms they got the money. If [fullShare] is true and
  /// the payment is for an expense, that member no longer counts as unpaid.
  Future<void> confirmPayment(
    String groupId,
    Payment payment, {
    bool fullShare = true,
  });

  // ---------- Activity feed (M5 Activity History) ----------

  /// The group's activity, newest first.
  Stream<List<ActivityEvent>> watchActivity(String groupId);

  /// Adds an event the service doesn't log by itself: reminders sent,
  /// items flagged, prices edited.
  Future<void> logActivity(String groupId, ActivityEvent event);

  // ---------- Recurring bills (M5 Frames 16–17) ----------

  Stream<List<RecurringBill>> watchRecurring(String groupId);
  Future<void> addRecurring(String groupId, RecurringBill bill);
  Future<void> setRecurringEnabled(String groupId, String billId, bool enabled);

  // ---------- Offline mode (Profile, Frame 24) ----------

  /// Offline: stop talking to the server. Changes are kept on the phone
  /// and sent when you go back online. Does nothing where unsupported.
  Future<void> setOffline(bool offline) async {}

  // ---------- Balances (Settle Up, Home, Group Detail) ----------

  /// Saves how many members still owe money (the "N unpaid" on cards).
  /// Screens that have the full ledger call this when it's out of date.
  Future<void> setUnpaidCount(String groupId, int count);

  /// The group, its expenses and its payments, together and live: what
  /// balances and smart settle are computed from.
  Stream<GroupLedger> watchLedger(String groupId) => combineLatest3(
    watchGroup(groupId),
    watchExpenses(groupId),
    watchPayments(groupId),
    GroupLedger.new,
  );

  /// Across ALL my groups: how much others owe me, and how much I owe
  /// (the Home header). Updates live as any group changes.
  Stream<({int owedToYou, int youOwe})> watchMyTotals() {
    late final StreamController<({int owedToYou, int youOwe})> out;
    StreamSubscription<List<Group>>? groupsSub;
    final ledgerSubs = <String, StreamSubscription<GroupLedger>>{};
    final ledgers = <String, GroupLedger>{};

    void emit() {
      var owed = 0, owe = 0;
      for (final ledger in ledgers.values) {
        final mine = ledger.balances[myId] ?? 0;
        if (mine > 0) owed += mine;
        if (mine < 0) owe -= mine;
      }
      out.add((owedToYou: owed, youOwe: owe));
    }

    out = StreamController(
      onListen: () {
        groupsSub = watchMyGroups().listen((groups) {
          final ids = {for (final g in groups) g.id};
          // Stop listening to groups I left; start on new ones.
          for (final id in ledgerSubs.keys.toList()) {
            if (!ids.contains(id)) {
              ledgerSubs.remove(id)!.cancel();
              ledgers.remove(id);
            }
          }
          for (final id in ids) {
            ledgerSubs.putIfAbsent(
              id,
              () => watchLedger(id).listen((ledger) {
                ledgers[id] = ledger;
                emit();
              }, onError: (_) {}), // one broken group shouldn't hide the rest
            );
          }
          if (ids.isEmpty) emit();
        }, onError: out.addError);
      },
      onCancel: () async {
        await groupsSub?.cancel();
        await Future.wait(ledgerSubs.values.map((s) => s.cancel()));
      },
    );
    return out.stream;
  }
}

/// Checks an expense before saving. Throws [GroupFailure] with a message
/// the screen can show. (Screens should also validate their forms; this
/// is the last safety net so bad data never reaches the database.)
void checkExpense(GroupExpense e) {
  if (e.title.trim().isEmpty) {
    throw const GroupFailure('Give the expense a name.');
  }
  if (e.amountCents <= 0) {
    throw const GroupFailure('The amount must be more than ₱0.');
  }
  if (e.paidById.isEmpty) throw const GroupFailure('Choose who paid.');
  if (e.shares.isEmpty) {
    throw const GroupFailure('Choose who shares this expense.');
  }
  if (e.shares.values.any((s) => s < 0)) {
    throw const GroupFailure('Shares cannot be negative.');
  }
  final sum = e.shares.values.fold(0, (a, b) => a + b);
  if (sum != e.amountCents) {
    throw GroupFailure(
      "Shares add up to ${_peso(sum)}, but the total is "
      "${_peso(e.amountCents)}.",
    );
  }
}

/// Checks a payment before saving.
void checkPayment(Payment p) {
  if (p.amountCents <= 0) {
    throw const GroupFailure('The amount must be more than ₱0.');
  }
  if (p.fromId.isEmpty || p.toId.isEmpty || p.fromId == p.toId) {
    throw const GroupFailure('Choose who paid and who received it.');
  }
}

String _peso(int cents) =>
    '₱${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

/// Error with a message that's safe to show the user.
class GroupFailure implements Exception {
  const GroupFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The current user as a group member, shown with their real name.
Person appUserPerson(String uid, String? name, {String role = 'App user'}) =>
    personFromName(
      (name == null || name.trim().isEmpty) ? 'You' : name,
      id: uid,
      pay: role,
    );

/// Characters used in invite codes: no look-alikes (0/O, 1/I).
const inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const inviteCodeLength = 5;

/// Random 5-character invite code, e.g. "DJ7Q2".
String generateInviteCode() {
  final rng = Random.secure();
  return List.generate(
    inviteCodeLength,
    (_) => inviteAlphabet[rng.nextInt(inviteAlphabet.length)],
  ).join();
}

/// Reads an invite code from what the user typed, pasted, or scanned:
/// a bare code ("dj7q2") or a full link ("https://bahinko.app/j/DJ7Q2").
/// Returns the code in capitals, or null if it isn't a valid code.
String? parseInviteCode(String input) {
  var text = input.trim().toUpperCase();
  // A link: take the part after the last "/".
  if (text.contains('/')) {
    text = text.split('/').where((s) => s.isNotEmpty).last;
  }
  final valid =
      text.length == inviteCodeLength &&
      text.split('').every(inviteAlphabet.contains);
  return valid ? text : null;
}
