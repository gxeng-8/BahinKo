/// Full-width primary button (filled) or secondary button (outlined).
library;

import 'package:flutter/material.dart';

import 'package:bahinko/theme/app_colors.dart';

class Btn extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool outlined;
  final Color? color;

  const Btn(
    this.text,
    this.onTap, {
    super.key,
    this.outlined = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 50,
    child: outlined
        ? OutlinedButton(onPressed: onTap, child: Text(text))
        : FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: color ?? green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onTap,
            child: Text(text),
          ),
  );
}
