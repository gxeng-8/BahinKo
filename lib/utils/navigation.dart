/// Small navigation helper used by every screen.
library;

import 'package:flutter/material.dart';

void go(BuildContext c, Widget w) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => w));
