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
import 'package:bahinko/theme/app_colors.dart';

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
}

/// Error with a message that's safe to show the user.
class GroupFailure implements Exception {
  const GroupFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The current user as a group member. Shown as "You".
// STEP 5: replace "You" with the user's real name when they join a group.
Person ownerPerson(String uid) =>
    Person('You', 'YO', deep, 'Group creator', 'Settled', id: uid);

/// 5-character invite code without look-alike characters (no 0/O, 1/I).
String generateInviteCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = Random.secure();
  return List.generate(5, (_) => chars[rng.nextInt(chars.length)]).join();
}
