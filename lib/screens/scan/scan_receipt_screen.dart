/// Figma Frame 7 "Scan Receipt": start a scan or type the items in.
///
/// Explains in plain words what happens to the receipt (responsible AI:
/// users know AI is involved and what data it gets).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:bahinko/screens/bill/manual_receipt_entry_screen.dart';
import 'package:bahinko/screens/scan/camera_capture_screen.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/btn.dart';
import 'package:bahinko/widgets/info_banner.dart';

/// On-device text recognition (ML Kit) only runs in the phone apps.
bool get canScanReceipts =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class ScanReceipt extends StatelessWidget {
  const ScanReceipt({super.key});

  @override
  Widget build(BuildContext context) => AppPage(
    'Scan Receipt',
    Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 12),
            ],
          ),
          child: Column(
            children: [
              const _FramedReceipt(),
              const SizedBox(height: 14),
              Text(
                canScanReceipts
                    ? 'Point your camera at the receipt'
                    : 'Receipt scanning works in the Android app',
                style: AppText.caption,
              ),
              const SizedBox(height: 12),
              Btn(
                'Scan Receipt',
                canScanReceipts
                    ? () => go(context, const CameraCapture())
                    : null, // disabled where scanning isn't available
                icon: Icons.document_scanner_outlined,
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
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
        Btn(
          'Enter Manually',
          () => go(context, const ManualReceiptEntry()),
          outlined: true,
        ),
        const SizedBox(height: 16),
        const InfoBanner(
          'Receipts are processed securely and can be deleted anytime.',
        ),
        const SizedBox(height: 8),
        const InfoBanner(
          'AI helps list the items. Only the receipt text is sent (never the '
          'photo), and you can edit everything before splitting.',
          icon: Icons.auto_awesome,
          color: mint,
        ),
      ],
    ),
  );
}

/// A receipt icon inside green corner brackets (the camera frame in Figma).
class _FramedReceipt extends StatelessWidget {
  const _FramedReceipt();

  @override
  Widget build(BuildContext context) {
    Widget corner(Alignment a) {
      const side = BorderSide(color: green, width: 4);
      final top = a.y < 0, left = a.x < 0;
      return Align(
        alignment: a,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            border: Border(
              top: top ? side : BorderSide.none,
              bottom: top ? BorderSide.none : side,
              left: left ? side : BorderSide.none,
              right: left ? BorderSide.none : side,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: mint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long, color: green, size: 72),
            ),
          ),
          corner(Alignment.topLeft),
          corner(Alignment.topRight),
          corner(Alignment.bottomLeft),
          corner(Alignment.bottomRight),
        ],
      ),
    );
  }
}
