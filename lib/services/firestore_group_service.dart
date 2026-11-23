/// Saves and loads groups in Cloud Firestore.
///
/// Data layout (see firestore.rules for who may read/write what):
///   groups/{groupId}
///     name, category, inviteCode, createdBy, createdAt,
///     memberIds: [uid, ...]         ← app users; used for security + queries
///     members:   [{id, name, ...}]  ← everyone shown in the app, incl. guests
///     totalCents, expenseCount, unpaidCount   ← summary for the Home cards
///     lastJoinCode                  ← proof of the code, written when joining
///   groups/{groupId}/expenses/{expenseId}
///     title, paidBy, splitWays, amountCents, unpaidCount, createdAt
///   invites/{code}
///     groupId, groupName, createdBy ← lets non-members find a group by code
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/services/auth_service.dart';
import 'package:bahinko/services/group_service.dart';

class FirestoreGroupService implements GroupService {
  /// How long to wait for the server.
  static const serverTimeout = Duration(seconds: 10);

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection('invites');

  /// The signed-in user's ID. Every query needs it.
  String get _uid {
    final uid = AuthService.instance.uid;
    if (uid == null) {
      throw const GroupFailure('You are signed out. Restart the app.');
    }
    return uid;
  }

  // ---------- Reads (streams) ----------

  @override
  Stream<List<Group>> watchMyGroups() => _groups
      // Only groups whose memberIds list contains me. The security rules
      // require this filter, so users can never list other people's groups.
      .where('memberIds', arrayContains: _uid)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map(_groupFromDoc).toList();
        // Sort newest first on the phone (sorting in the query would need a
        // composite index for array-contains + orderBy).
        list.sort(
          (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
            a.createdAt ?? DateTime.now(),
          ),
        );
        return list;
      })
      .transform(_friendlyErrors());

  @override
  Stream<Group> watchGroup(String groupId) => _groups
      .doc(groupId)
      .snapshots()
      .map((doc) {
        if (!doc.exists) {
          throw const GroupFailure('This group no longer exists.');
        }
        return _groupFromDoc(doc);
      })
      .transform(_friendlyErrors());

  @override
  Stream<List<GroupExpense>> watchExpenses(String groupId) => _groups
      .doc(groupId)
      .collection('expenses')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snap) => [for (final d in snap.docs) GroupExpense.fromMap(d.data())],
      )
      .transform(_friendlyErrors());

  // ---------- Writes ----------

  @override
  Future<Group> createGroup({
    required String name,
    required GroupCategory category,
    required List<Person> others,
  }) async {
    final uid = _uid;
    final doc = _groups.doc(); // new document with a random ID
    final members = [
      appUserPerson(
        uid,
        AuthService.instance.displayName,
        role: 'Group creator',
      ),
      ...others,
    ];

    // Try up to 3 invite codes: if a code is already taken by another
    // group, the rules reject the invite write and we pick a new code.
    for (var attempt = 1; ; attempt++) {
      final code = generateInviteCode();
      // A batch saves the group AND its invite together: both or neither.
      final batch = _db.batch()
        ..set(doc, {
          'name': name.trim(),
          'category': category.name,
          'inviteCode': code,
          'createdBy': uid,
          'memberIds': [uid],
          'members': [for (final m in members) m.toMap()],
          'totalCents': 0,
          'expenseCount': 0,
          'unpaidCount': 0,
          // The server fills in its own time (phones' clocks can be wrong).
          'createdAt': FieldValue.serverTimestamp(),
        })
        ..set(_invites.doc(code), {
          'groupId': doc.id,
          'groupName': name.trim(),
          'createdBy': uid,
        });
      try {
        await _waitForServer(batch.commit());
        return Group(
          id: doc.id,
          name: name.trim(),
          category: category,
          members: members,
          inviteCode: code,
          createdBy: uid,
        );
      } on FirebaseException catch (e) {
        final codeTaken = e.code == 'permission-denied' && attempt < 3;
        if (!codeTaken) throw _toFailure(e);
      }
    }
  }

  @override
  Future<void> addGuest(String groupId, String name) async {
    final guest = personFromName(
      name,
      id: 'guest-${DateTime.now().millisecondsSinceEpoch}',
    );
    try {
      // arrayUnion adds to the list on the server without overwriting
      // members that someone else added at the same moment.
      await _waitForServer(
        _groups.doc(groupId).update({
          'members': FieldValue.arrayUnion([guest.toMap()]),
        }),
      );
    } on FirebaseException catch (e) {
      throw _toFailure(e);
    }
  }

  @override
  Future<String> joinGroup(String code, String yourName) async {
    final uid = _uid;
    try {
      // 1) Find the group. Anyone signed in may read invites/{code}, but
      //    only if they know the code (listing all invites is blocked).
      final invite = await _invites.doc(code).get().timeout(serverTimeout);
      if (!invite.exists) {
        throw GroupFailure(
          'No group found with code $code. Check the code and try again.',
        );
      }
      final groupId = invite.data()!['groupId'] as String;

      // 2) Already a member? Then the rules let us read the group.
      if (await _canRead(groupId)) return groupId;

      // 3) Join: add my ID and my name card. The rules only allow this
      //    exact change, and only with the right code in lastJoinCode.
      final me = appUserPerson(uid, yourName);
      await _waitForServer(
        _groups.doc(groupId).update({
          'memberIds': FieldValue.arrayUnion([uid]),
          'members': FieldValue.arrayUnion([me.toMap()]),
          'lastJoinCode': code,
        }),
      );
      return groupId;
    } on TimeoutException {
      throw const GroupFailure(
        "Can't reach the server. Check your internet connection.",
      );
    } on FirebaseException catch (e) {
      throw _toFailure(e);
    }
  }

  @override
  Future<void> ensureInvite(Group group) async {
    // Only the creator may publish the code (see firestore.rules).
    if (group.inviteCode.isEmpty ||
        group.createdBy != AuthService.instance.uid) {
      return;
    }
    try {
      await _invites.doc(group.inviteCode).set({
        'groupId': group.id,
        'groupName': group.name,
        'createdBy': group.createdBy,
      });
    } catch (_) {
      // Not critical: it will be retried the next time Invite is opened.
    }
  }

  // ---------- Helpers ----------

  /// True if the current user may read the group (i.e. is a member).
  Future<bool> _canRead(String groupId) async {
    try {
      final doc = await _groups.doc(groupId).get().timeout(serverTimeout);
      return doc.exists;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false; // not a member yet
      rethrow;
    }
  }

  /// Converts a Firestore document into a [Group].
  Group _groupFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final members = (data['members'] as List<dynamic>? ?? [])
        .map((m) => Person.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
    return Group(
      id: doc.id,
      name: data['name'] as String? ?? 'Untitled group',
      category: categoryNamed(data['category'] as String? ?? 'Custom'),
      members: members,
      inviteCode: data['inviteCode'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      totalCents: (data['totalCents'] as num?)?.toInt() ?? 0,
      expenseCount: (data['expenseCount'] as num?)?.toInt() ?? 0,
      unpaidCount: (data['unpaidCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Waits for a write to reach the server.
  ///
  /// Firestore saves writes on the phone first and syncs them later, so if
  /// the server is slow or offline we stop waiting after [serverTimeout]:
  /// the change is already visible in the app and will upload on its own.
  /// Real errors (e.g. permission denied) are rethrown for the caller.
  Future<void> _waitForServer(Future<void> write) async {
    try {
      await write.timeout(serverTimeout);
    } on TimeoutException {
      // Saved locally; Firestore will sync it when the connection returns.
    }
  }

  /// Turns Firestore errors in a stream into user-friendly [GroupFailure]s.
  StreamTransformer<T, T> _friendlyErrors<T>() =>
      StreamTransformer.fromHandlers(
        handleError: (error, stack, sink) => sink.addError(_toFailure(error)),
      );

  GroupFailure _toFailure(Object error) {
    if (error is GroupFailure) return error;
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return const GroupFailure("You don't have access to this group.");
        case 'unavailable':
          return const GroupFailure(
            "Can't reach the server. Check your internet connection.",
          );
      }
    }
    return const GroupFailure('Something went wrong. Please try again.');
  }
}
