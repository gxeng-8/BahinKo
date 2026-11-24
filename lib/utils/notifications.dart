/// The bell on Home: which activity is news FOR ME, how to word it, and
/// the badge text ("3", "9+").
///
/// A notification is an activity entry that someone ELSE made and that
/// names me in [ActivityEvent.forIds]:
///   reminder → "Leo reminded you to pay ₱395.00"
///   payment  → "Jun says they paid you ₱845.00. Confirm it in Settle Up."
///   confirm  → "Mia confirmed your ₱450.00 payment"
///   expense / edit → "Ana added Samgyup", "Jun edited Soju"
/// Unread = newer than the last time the bell was opened (saved on the
/// phone in SettingsService.notificationsSeenAt).
library;

import 'package:bahinko/models/group.dart';
import 'package:bahinko/utils/currency.dart';

typedef GroupEvent = ({Group group, ActivityEvent event});

/// True if [e] is about me and was done by someone else.
bool isNotificationFor(ActivityEvent e, String myId) =>
    e.forIds.contains(myId) && e.actorId.isNotEmpty && e.actorId != myId;

/// Only my notifications, keeping the newest-first order.
List<GroupEvent> notificationsFor(List<GroupEvent> all, String myId) => [
  for (final item in all)
    if (isNotificationFor(item.event, myId)) item,
];

/// How many are newer than [seenAt] (all of them if never opened).
int unreadCount(List<GroupEvent> mine, DateTime? seenAt) => mine
    .where(
      (n) =>
          seenAt == null ||
          (n.event.createdAt ?? DateTime.now()).isAfter(seenAt),
    )
    .length;

/// Badge text: nothing for 0, "1"–"9", then "9+".
String? badgeLabel(int count) => count <= 0
    ? null
    : count > 9
    ? '9+'
    : '$count';

/// The sentence shown in the list, written to me.
String notificationText(ActivityEvent e) {
  final who = e.actorName.isEmpty ? 'Someone' : e.actorName;
  final amount = e.amountCents == null ? '' : formatMoney(e.amountCents!);
  return switch (e.type) {
    'reminder' =>
      amount.isEmpty
          ? '$who sent you a payment reminder'
          : '$who reminded you to pay $amount',
    'payment' => '$who says they paid you $amount. Confirm it once you get it.',
    'confirm' => '$who confirmed your $amount payment',
    _ => e.text,
  };
}
