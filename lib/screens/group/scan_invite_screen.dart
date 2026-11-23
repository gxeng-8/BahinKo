/// Full-screen camera that reads a group's invite QR code.
///
/// Returns the invite code (e.g. "DJ7Q2") to the screen that opened it
/// via `Navigator.pop(context, code)`. QR codes that aren't BahinKo
/// invites are ignored.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/widgets/app_page.dart';

/// QR scanning works on phones and in the browser, but not on Windows.
bool get canScanQr =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

class ScanInviteScreen extends StatefulWidget {
  const ScanInviteScreen({super.key});

  @override
  State<ScanInviteScreen> createState() => _ScanInviteScreenState();
}

class _ScanInviteScreenState extends State<ScanInviteScreen> {
  /// Only look for QR codes (faster than scanning every barcode type).
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  /// Set once a code is found, so we don't pop the screen twice.
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose(); // releases the camera
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final code = parseInviteCode(barcode.rawValue ?? '');
      if (code != null) {
        _done = true;
        Navigator.pop(context, code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text(
        'Scan invite QR',
        style: TextStyle(color: Colors.white),
      ),
      leading: const RoundBackButton(onDark: true),
    ),
    body: Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          // Error state: no camera, or permission denied.
          errorBuilder: (context, error) => const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              "Can't open the camera. Allow camera access, or go back and "
              'type the code instead.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        // Square frame showing where to point the QR code.
        IgnorePointer(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: lime, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const Positioned(
          bottom: 48,
          child: Text(
            "Point at the group's QR code",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
