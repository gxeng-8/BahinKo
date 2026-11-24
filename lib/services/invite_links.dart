/// Opens the Join screen when someone taps an invite link:
///   https://bahinko-303f2.web.app/j/DJ7Q2   (Android App Link)
///   bahinko://join/DJ7Q2                    (the web page's button)
///
/// The link can arrive before the user is ready (onboarding, PIN screen),
/// so the code waits in [pendingInvite] until the Shell (the main app,
/// only reached after sign-in and unlock) picks it up.
library;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'package:bahinko/services/group_service.dart';

/// The invite code waiting to be opened, or null.
final pendingInvite = ValueNotifier<String?>(null);

/// Takes the waiting code (so it's handled only once).
String? takePendingInvite() {
  final code = pendingInvite.value;
  pendingInvite.value = null;
  return code;
}

/// The invite code in [uri], or null if it isn't an invite link.
String? inviteCodeFromUri(Uri uri) {
  final isWebLink =
      uri.scheme == 'https' &&
      uri.pathSegments.length >= 2 &&
      uri.pathSegments.first == 'j';
  final isAppLink = uri.scheme == 'bahinko' && uri.host == 'join';
  if (!isWebLink && !isAppLink) return null;
  return parseInviteCode(uri.path);
}

StreamSubscription<Uri>? _sub;

/// Starts listening (phones only). Also catches the link that opened the app.
void listenForInviteLinks() {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return;
  }
  _sub ??= AppLinks().uriLinkStream.listen(
    (uri) {
      final code = inviteCodeFromUri(uri);
      if (code != null) pendingInvite.value = code;
    },
    onError: (_) {}, // a broken link is simply ignored
  );
}
