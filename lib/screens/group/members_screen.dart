/// List of group members with an add button.
library;

import 'package:flutter/material.dart';
import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/screens/group/widgets/add_member_dialog.dart';
import 'package:bahinko/screens/group/invite_members_screen.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/avatar.dart';
import 'package:bahinko/widgets/box.dart';
import 'package:bahinko/widgets/btn.dart';
import 'package:bahinko/widgets/pill.dart';

class Members extends StatelessWidget {
  const Members({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    'Members',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search member',
            filled: true,
            fillColor: mint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<List<Person>>(
          valueListenable: groupMembers,
          builder: (context, currentMembers, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dinner at Jaro members (${currentMembers.length})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final p in currentMembers)
                Box(
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Avatar(p),
                    title: Text(p.name),
                    subtitle: Text(p.pay),
                    trailing: Pill(
                      p.status,
                      bg: p.status == 'Paid' ? mint : const Color(0xFFFFF3D6),
                      fg: p.status == 'Paid' ? green : const Color(0xFFB7791F),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Box(
          color: lime,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Invite friends',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const Text(
                'Share a link or QR code. Friends without the app can join as guests.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Btn('Copy invite link', () => go(context, const InviteMembers())),
            ],
          ),
        ),
      ],
    ),
    actions: [
      IconButton(
        tooltip: 'Add member',
        icon: const Icon(Icons.add),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => AddMemberDialog(onAdd: addMember),
        ),
      ),
    ],
  );
}
