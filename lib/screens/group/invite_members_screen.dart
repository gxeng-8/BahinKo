/// Figma Frame 22 "Invite": QR code + link to join a group, share buttons,
/// and a small validated form to add a guest who doesn't have the app.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:bahinko/data/in_memory_group_service.dart' show demoGroupId;
import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/validators.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/app_toast.dart';
import 'package:bahinko/widgets/async_state_view.dart';
import 'package:bahinko/widgets/btn.dart';

class InviteMembers extends StatefulWidget {
  /// Invite screen for [groupId] (defaults to the sample group).
  const InviteMembers({super.key, this.groupId = demoGroupId});

  final String groupId;

  @override
  State<InviteMembers> createState() => _InviteMembersState();
}

class _InviteMembersState extends State<InviteMembers> {
  final _formKey = GlobalKey<FormState>();
  final _guestController = TextEditingController();

  /// Live group data (created once, see initState).
  late Stream<Group> _group;

  /// Latest loaded group: used by the buttons and the duplicate-name check.
  Group? _latest;

  /// True while a guest is being saved (disables the button).
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _group = GroupService.instance.watchGroup(widget.groupId);
    // Make sure this group's code can be looked up by people joining
    // (groups made before invite codes existed don't have it yet).
    GroupService.instance
        .watchGroup(widget.groupId)
        .first
        .then(GroupService.instance.ensureInvite)
        .catchError((_) {}); // not critical; retried next time
  }

  @override
  void dispose() {
    _guestController.dispose();
    super.dispose();
  }

  void _reload() =>
      setState(() => _group = GroupService.instance.watchGroup(widget.groupId));

  Future<void> _copyLink(Group group) async {
    await Clipboard.setData(ClipboardData(text: group.inviteLink));
    if (mounted) showAppToast(context, 'Invite link copied');
  }

  /// Opens the phone's share sheet (Messenger, Viber, SMS… appear there).
  Future<void> _share(Group group) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Join "${group.name}" on BahinKo: ${group.inviteLink}',
          subject: 'BahinKo group invite',
        ),
      );
    } catch (_) {
      // Error feedback: some desktops have no share sheet.
      if (mounted) {
        showAppToast(context, "Couldn't open sharing. Link copied instead.");
        await _copyLink(group);
      }
    }
  }

  /// Guest name: a valid name (see validatePersonName) that isn't
  /// already in the group.
  String? _validateGuest(String? value) {
    if ((value ?? '').trim().isEmpty) return "Enter the guest's name";
    final error = validatePersonName(value);
    if (error != null) return error;
    final name = value!.trim();
    final taken = (_latest?.members ?? const <Person>[]).any(
      (p) => p.name.toLowerCase() == name.toLowerCase(),
    );
    if (taken) return '$name is already in this group';
    return null;
  }

  /// Validates the form, saves the guest, and shows the result.
  Future<void> _addGuest() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _guestController.text.trim();
    setState(() => _saving = true);
    try {
      await GroupService.instance.addGuest(widget.groupId, name);
      if (!mounted) return;
      _guestController.clear();
      FocusScope.of(context).unfocus(); // hide the keyboard
      showAppToast(context, '$name added as a guest');
    } on GroupFailure catch (e) {
      if (mounted) showAppToast(context, e.message); // error state
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    'Invite',
    StreamBuilder<Group>(
      stream: _group,
      builder: (context, snapshot) => AsyncStateView<Group>(
        snapshot: snapshot,
        onRetry: _reload,
        builder: (group) {
          _latest = group;
          return Column(
            children: [
              _QrCard(group: group),
              const SizedBox(height: 16),
              Btn('Copy invite link', () => _copyLink(group)),
              const SizedBox(height: 10),
              Btn('Share via Messenger', () => _share(group), outlined: true),
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
              _guestForm(),
            ],
          );
        },
      ),
    ),
  );

  /// "Add a guest instead" form.
  Widget _guestForm() => Form(
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
        Btn(
          _saving ? 'Adding…' : 'Add guest',
          _saving ? null : _addGuest,
          outlined: true,
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
        Text(
          'Scan to join · ${group.members.length} members',
          style: AppText.caption,
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
