/// Figma Frame 22 "Invite": QR code + link to join a group, share buttons,
/// and a small validated form to add a guest who doesn't have the app.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/app_toast.dart';
import 'package:bahinko/widgets/btn.dart';

class InviteMembers extends StatefulWidget {
  /// Invite screen for [group]; defaults to the sample group.
  const InviteMembers({super.key, this.group});

  final Group? group;

  @override
  State<InviteMembers> createState() => _InviteMembersState();
}

class _InviteMembersState extends State<InviteMembers> {
  final _formKey = GlobalKey<FormState>();
  final _guestController = TextEditingController();

  Group get _group => widget.group ?? demoGroup;

  @override
  void dispose() {
    _guestController.dispose();
    super.dispose();
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _group.inviteLink));
    if (mounted) showAppToast(context, 'Invite link copied');
  }

  /// Opens the phone's share sheet (Messenger, Viber, SMS… appear there).
  Future<void> _share() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Join "${_group.name}" on BahinKo: ${_group.inviteLink}',
          subject: 'BahinKo group invite',
        ),
      );
    } catch (_) {
      // Error feedback: some desktops have no share sheet.
      if (mounted) {
        showAppToast(context, "Couldn't open sharing. Link copied instead.");
        await _copyLink();
      }
    }
  }

  /// Guest name: required, 2–30 characters, letters/spaces/.-' only.
  String? _validateGuest(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return "Enter the guest's name";
    if (name.length < 2) return 'Name is too short';
    if (name.length > 30) return 'Keep it under 30 characters';
    if (!RegExp(r"^[A-Za-zÀ-ÿñÑ .'-]+$").hasMatch(name)) {
      return 'Use letters only';
    }
    final taken = _group.members.value.any(
      (p) => p.name.toLowerCase() == name.toLowerCase(),
    );
    if (taken) return '$name is already in this group';
    return null;
  }

  void _addGuest() {
    if (!_formKey.currentState!.validate()) return;
    final name = _guestController.text.trim();
    addMember(name, to: _group.members);
    _guestController.clear();
    FocusScope.of(context).unfocus(); // hide the keyboard
    showAppToast(context, '$name added as a guest');
  }

  @override
  Widget build(BuildContext context) => AppPage(
    'Invite',
    Column(
      children: [
        _QrCard(group: _group),
        const SizedBox(height: 16),
        Btn('Copy invite link', _copyLink),
        const SizedBox(height: 10),
        Btn('Share via Messenger', _share, outlined: true),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(child: Divider(color: border)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('or', style: AppText.caption),
              ),
              Expanded(child: Divider(color: border)),
            ],
          ),
        ),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add a guest instead', style: AppText.section),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('guest-name'),
                controller: _guestController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Guest name',
                  hintText: 'e.g. Rico',
                ),
                validator: _validateGuest,
                onFieldSubmitted: (_) => _addGuest(),
              ),
              const SizedBox(height: 6),
              const Text(
                'Guests can view their share through a link. No install needed.',
                style: AppText.caption,
              ),
              const SizedBox(height: 12),
              Btn('Add guest', _addGuest, outlined: true),
            ],
          ),
        ),
      ],
    ),
  );
}

/// White card with the group name, member count, QR code, and short link.
class _QrCard extends StatelessWidget {
  const _QrCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border),
    ),
    child: Column(
      children: [
        Text(group.name, style: AppText.display(20, color: deep)),
        ValueListenableBuilder<List<Person>>(
          valueListenable: group.members,
          builder: (context, members, _) => Text(
            'Scan to join · ${members.length} members',
            style: AppText.caption,
          ),
        ),
        const SizedBox(height: 12),
        QrImageView(
          data: group.inviteLink,
          size: 180,
          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: deep),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: deep,
          ),
          semanticsLabel: 'QR code to join ${group.name}',
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            group.inviteLink.replaceFirst('https://', ''),
            style: AppText.caption,
          ),
        ),
      ],
    ),
  );
}
