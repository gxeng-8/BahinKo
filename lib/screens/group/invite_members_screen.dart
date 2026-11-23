/// Invite people to a group via link or QR.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/btn.dart';

class InviteMembers extends StatelessWidget {
  const InviteMembers({super.key});

  @override
  Widget build(BuildContext context) => AppPage(
    'Invite',
    Column(
      children: [
        const Text(
          'Dinner at Jaro',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Add friends or share an invite link',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 18),
        Container(
          width: 190,
          height: 190,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0E7E3)),
          ),
          child: const Icon(Icons.qr_code_2, size: 150, color: deep),
        ),
        const SizedBox(height: 12),
        const Text(
          'bahinko.app/join/dinner-jaro',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        Btn('Copy invite link', () async {
          await Clipboard.setData(
            const ClipboardData(text: 'https://bahinko.app/join/dinner-jaro'),
          );
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Invite link copied')));
          }
        }),
        const SizedBox(height: 8),
        Btn('Share via Messenger', () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invite ready to share')),
          );
        }, outlined: true),
      ],
    ),
  );
}
