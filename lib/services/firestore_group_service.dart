/// Saves and loads groups in Cloud Firestore.
///
/// Data layout (see firestore.rules for who may read/write what):
///   groups/{groupId}
///     name, category, inviteCode, createdBy, createdAt,
///     memberIds: [uid, ...]         ← app users; used for security + queries
///     members:   [{id, name, ...}]  ← everyone shown in the app, incl. guests
///     totalCents, expenseCount, unpaidCount   ← summary for the Home cards
///   groups/{groupId}/expenses/{expenseId}
///     title, paidBy, splitWays, amountCents, unpaidCount, createdAt
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:bahinko/data/mock_data.dart' show personFromName;
import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/services/auth_service.dart';
import 'package:bahinko/services/group_service.dart';

class FirestoreGroupService implements GroupService {
  /// How long to wait for the server to confirm a write.
  static const writeTimeout = Duration(seconds: 10);

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

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
    final members = [ownerPerson(uid), ...others];
    final group = Group(
      id: doc.id,
      name: name.trim(),
      category: category,
      members: members,
      inviteCode: generateInviteCode(),
    );
    await _write(
      doc.set({
        'name': group.name,
        'category': category.name,
        'inviteCode': group.inviteCode,
        'createdBy': uid,
        'memberIds': [uid],
        'members': [for (final m in members) m.toMap()],
        'totalCents': 0,
        'expenseCount': 0,
        'unpaidCount': 0,
        // The server fills in its own clock time (phones' clocks can be wrong).
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
    return group;
  }

  @override
  Future<void> addGuest(String groupId, String name) {
    final guest = personFromName(name);
    final withId = Person(
      guest.name,
      guest.initials,
      guest.color,
      guest.pay,
      guest.status,
      id: 'guest-${DateTime.now().millisecondsSinceEpoch}',
    );
    // arrayUnion adds to the list on the server without overwriting
    // members that someone else added at the same moment.
    return _write(
      _groups.doc(groupId).update({
        'members': FieldValue.arrayUnion([withId.toMap()]),
      }),
    );
  }

  // ---------- Helpers ----------

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
      totalCents: (data['totalCents'] as num?)?.toInt() ?? 0,
      expenseCount: (data['expenseCount'] as num?)?.toInt() ?? 0,
      unpaidCount: (data['unpaidCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Waits for a write to reach the server.
  ///
  /// Firestore saves writes on the phone first and syncs them later, so if
  /// the server is slow or offline we stop waiting after [writeTimeout]:
  /// the change is already visible in the app and will upload on its own.
  /// Real errors (e.g. permission denied) become a [GroupFailure].
  Future<void> _write(Future<void> write) async {
    try {
      await write.timeout(writeTimeout);
    } on TimeoutException {
      // Saved locally; Firestore will sync it when the connection returns.
    } on FirebaseException catch (e) {
      throw _toFailure(e);
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
