/// Models for money inside a group: receipt items, payments, and the
/// activity feed. Plain Dart classes; the services convert them to and
/// from Firestore maps with toMap()/fromMap().
///
/// All money is whole centavos (int) to avoid rounding errors.
library;

/// One line on a receipt ("Pork belly set ₱900").
/// Stored inside the expense document's `items` list.
class ExpenseItem {
  const ExpenseItem({
    required this.name,
    required this.amountCents,
    this.assignedTo = const [],
    this.aiGenerated = false,
    this.needsReview = false,
  });

  final String name;
  final int amountCents;

  /// Member IDs who share this item. Empty = split among everyone.
  final List<String> assignedTo;

  /// True if the AI scanner produced this line (shown with an AI label).
  final bool aiGenerated;

  /// True if the AI was unsure (Figma 9: orange "Needs review").
  final bool needsReview;

  Map<String, dynamic> toMap() => {
    'name': name,
    'amountCents': amountCents,
    'assignedTo': assignedTo,
    'aiGenerated': aiGenerated,
    'needsReview': needsReview,
  };

  factory ExpenseItem.fromMap(Map<String, dynamic> m) => ExpenseItem(
    name: m['name'] as String? ?? 'Item',
    amountCents: (m['amountCents'] as num?)?.toInt() ?? 0,
    assignedTo: List<String>.from(m['assignedTo'] as List? ?? const []),
    aiGenerated: m['aiGenerated'] as bool? ?? false,
    needsReview: m['needsReview'] as bool? ?? false,
  );
}

/// A payment from one member to another ("Jun paid ₱350 to You").
/// Stored at groups/{groupId}/payments/{paymentId}.
class Payment {
  const Payment({
    this.id = '',
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
    required this.amountCents,
    this.method = 'cash',
    this.status = 'pending',
    this.expenseId,
    this.reference,
    this.createdAt,
  });

  final String id;
  final String fromId, fromName, toId, toName;
  final int amountCents;

  /// 'gcash', 'maya', or 'cash'.
  final String method;

  /// 'pending' (payer says they paid) or 'confirmed' (receiver got it).
  final String status;

  /// The expense this pays for, if any.
  final String? expenseId;

  /// Optional GCash/Maya reference number (Figma 14).
  final String? reference;
  final DateTime? createdAt;

  bool get isConfirmed => status == 'confirmed';

  Map<String, dynamic> toMap() => {
    'fromId': fromId,
    'fromName': fromName,
    'toId': toId,
    'toName': toName,
    'amountCents': amountCents,
    'method': method,
    'status': status,
    'expenseId': expenseId,
    'reference': reference,
  };

  factory Payment.fromMap(
    String id,
    Map<String, dynamic> m, {
    DateTime? createdAt,
  }) => Payment(
    id: id,
    fromId: m['fromId'] as String? ?? '',
    fromName: m['fromName'] as String? ?? '',
    toId: m['toId'] as String? ?? '',
    toName: m['toName'] as String? ?? '',
    amountCents: (m['amountCents'] as num?)?.toInt() ?? 0,
    method: m['method'] as String? ?? 'cash',
    status: m['status'] as String? ?? 'pending',
    expenseId: m['expenseId'] as String?,
    reference: m['reference'] as String?,
    createdAt: createdAt,
  );
}

/// One line in the activity feed (Figma 20), e.g. "Leo paid ₱200.00".
/// Stored at groups/{groupId}/activity/{eventId}. Written automatically by
/// the service for expenses, payments and joins; screens can also log
/// reminders, flags and edits with GroupService.logActivity().
class ActivityEvent {
  const ActivityEvent({
    this.id = '',
    required this.type,
    required this.text,
    this.actorName = '',
    this.actorId = '',
    this.forIds = const [],
    this.amountCents,
    this.oldCents,
    this.newCents,
    this.createdAt,
  });

  final String id;

  /// 'expense', 'payment', 'confirm', 'reminder', 'edit', 'flag', 'join'.
  /// Activity History's filter chips (Edits / Payments / Reminders) use it.
  final String type;

  /// Ready-to-show sentence: "Jun edited Soju".
  final String text;
  final String actorName;

  /// Who did it, and who it concerns (e.g. the person reminded, the payer
  /// whose payment was confirmed). Used for the bell's notifications.
  /// Empty on entries saved before notifications existed.
  final String actorId;
  final List<String> forIds;
  final int? amountCents;

  /// For edits: old and new price (shown as ₱420 → ₱450 chips).
  final int? oldCents, newCents;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
    'type': type,
    'text': text,
    'actorName': actorName,
    'actorId': actorId,
    'forIds': forIds,
    'amountCents': amountCents,
    'oldCents': oldCents,
    'newCents': newCents,
  };

  factory ActivityEvent.fromMap(
    String id,
    Map<String, dynamic> m, {
    DateTime? createdAt,
  }) => ActivityEvent(
    id: id,
    type: m['type'] as String? ?? 'edit',
    text: m['text'] as String? ?? '',
    actorName: m['actorName'] as String? ?? '',
    actorId: m['actorId'] as String? ?? '',
    forIds: List<String>.from(m['forIds'] as List? ?? const []),
    amountCents: (m['amountCents'] as num?)?.toInt(),
    oldCents: (m['oldCents'] as num?)?.toInt(),
    newCents: (m['newCents'] as num?)?.toInt(),
    createdAt: createdAt,
  );
}
