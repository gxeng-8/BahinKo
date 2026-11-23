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

import 'dart:math';

import 'package:bahinko/data/in_memory_group_service.dart';
import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/person.dart';

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
}

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
