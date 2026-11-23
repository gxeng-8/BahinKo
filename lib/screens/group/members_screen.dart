/// Figma Frame 21 "Members": searchable member list with payment status,
/// plus an "Invite friends" card.
///
/// COURSE CORE FEATURE: searching/filtering records (live search box).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bahinko/data/in_memory_group_service.dart' show demoGroupId;
import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/screens/group/invite_members_screen.dart';
import 'package:bahinko/screens/group/widgets/add_member_dialog.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/app_toast.dart';
import 'package:bahinko/widgets/async_state_view.dart';
import 'package:bahinko/widgets/avatar.dart';
import 'package:bahinko/widgets/btn.dart';
import 'package:bahinko/widgets/pill.dart';

class Members extends StatefulWidget {
  /// Shows the members of [groupId] (defaults to the sample group).
  const Members({super.key, this.groupId = demoGroupId});

  final String groupId;

  @override
  State<Members> createState() => _MembersState();
}

class _MembersState extends State<Members> {
  /// Current text in the search box (lower-cased for matching).
  String _query = '';

  /// Live group data (created once, see initState).
  late Stream<Group> _group;

  /// Latest loaded group, used by the Copy/Invite buttons.
  Group? _latest;

  @override
  void initState() {
    super.initState();
    _group = GroupService.instance.watchGroup(widget.groupId);
  }

  void _reload() =>
      setState(() => _group = GroupService.instance.watchGroup(widget.groupId));

  /// Members whose name contains the search text (case-insensitive).
  List<Person> _filter(List<Person> all) => _query.isEmpty
      ? all
      : all.where((p) => p.name.toLowerCase().contains(_query)).toList();

  Future<void> _copyInviteLink() async {
    final link = _latest?.inviteLink;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) showAppToast(context, 'Invite link copied');
  }

  /// Saves a new guest; shows the error if saving fails.
  Future<void> _addMember(String name) async {
    try {
      await GroupService.instance.addGuest(widget.groupId, name);
    } on GroupFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    'Members',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('member-search'),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, color: muted),
            hintText: 'Search members',
          ),
          // setState re-runs build(), which re-filters the list.
          onChanged: (text) =>
              setState(() => _query = text.trim().toLowerCase()),
        ),
        const SizedBox(height: 12),
        StreamBuilder<Group>(
          stream: _group,
          builder: (context, snapshot) => AsyncStateView<Group>(
            snapshot: snapshot,
            onRetry: _reload,
            builder: (group) {
              _latest = group;
              final shown = _filter(group.members);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${group.name} members (${group.members.length})',
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 8),
                  // Empty state when the search matches no one.
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No members match "$_query"',
                          style: AppText.caption,
                        ),
                      ),
                    )
                  else
                    _MemberCard(members: shown),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _InviteCard(onCopy: _copyInviteLink),
      ],
    ),
    actions: [
      IconButton(
        tooltip: 'Invite',
        icon: const Icon(Icons.qr_code_2),
        onPressed: () => go(context, InviteMembers(groupId: widget.groupId)),
      ),
      IconButton(
        tooltip: 'Add member',
        icon: const Icon(Icons.add),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => AddMemberDialog(onAdd: _addMember),
        ),
      ),
    ],
  );
}

/// One white card listing members, separated by thin dividers.
class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.members});

  final List<Person> members;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border),
    ),
    child: Column(
      children: [
        for (var i = 0; i < members.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 64, color: border),
          ListTile(
            leading: Avatar(members[i], size: 38),
            title: Text(
              members[i].name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              members[i].pay == 'Guest'
                  ? 'Guest · no app needed'
                  : members[i].pay,
              style: AppText.caption,
            ),
            trailing: _statusPill(members[i]),
          ),
        ],
      ],
    ),
  );

  /// Chooses the pill style from the member's status text.
  Widget _statusPill(Person p) {
    if (p.pay == 'Guest') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: muted),
        ),
        child: const Text(
          'Guest',
          style: TextStyle(fontSize: 11, color: muted),
        ),
      );
    }
    if (p.status == 'Settled') return Pill.paid(text: 'Settled');
    if (p.status == 'Paid') {
      return Pill.paid(
        text: p.pay == 'Paid the bill' ? 'Paid the bill' : 'Paid',
      );
    }
    return Pill.unpaid(text: p.status);
  }
}

/// Green card at the bottom: "Invite friends" + Copy invite link.
class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.onCopy});

  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: bannerBg,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.group_add_outlined, color: deep, size: 20),
            SizedBox(width: 8),
            Text(
              'Invite friends',
              style: TextStyle(fontWeight: FontWeight.w700, color: deep),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Friends can join by link or QR code. Guests without the app can be added.',
          style: TextStyle(fontSize: 12, color: deep),
        ),
        const SizedBox(height: 12),
        Btn('Copy invite link', onCopy),
      ],
    ),
  );
}
