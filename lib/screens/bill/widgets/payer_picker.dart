/// "Paid by" row (Figma Frames 6 and 9): the group's members as avatars;
/// the one who paid gets a green ring and a check badge.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/models/person.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/widgets/avatar.dart';

class PayerPicker extends StatelessWidget {
  const PayerPicker({
    super.key,
    required this.members,
    required this.payerId,
    required this.onChanged,
  });

  final List<Person> members;
  final String payerId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final m in members)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Semantics(
              button: true,
              selected: m.id == payerId,
              label: 'Paid by ${m.name}',
              child: GestureDetector(
                key: ValueKey('payer-${m.id}'),
                onTap: () => onChanged(m.id),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: m.id == payerId
                                  ? green
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Avatar(m, size: 38),
                        ),
                        if (m.id == payerId)
                          const Positioned(
                            right: -2,
                            bottom: -2,
                            child: CircleAvatar(
                              radius: 9,
                              backgroundColor: green,
                              child: Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.id == GroupService.instance.myId ? 'You' : m.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: m.id == payerId
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
