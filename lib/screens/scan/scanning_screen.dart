/// Figma Frame 8 "Scanning": shows the receipt photo with a moving scan
/// line while [ReceiptScanner] reads it (OCR) and organizes it (AI).
///
/// Async states (course requirement e):
/// * loading: animated line + the current step ("Reading…", "Organizing…")
/// * error:   message + Retake / Enter manually (never a dead end)
/// * success: opens Assign Items with the found items
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:bahinko/screens/bill/assign_items_screen.dart';
import 'package:bahinko/screens/bill/manual_receipt_entry_screen.dart';
import 'package:bahinko/screens/scan/camera_capture_screen.dart';
import 'package:bahinko/services/receipt_scanner.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/btn.dart';
import 'package:bahinko/widgets/info_banner.dart';

class ScanningScreen extends StatefulWidget {
  const ScanningScreen({super.key, required this.imagePath, this.imageBytes});

  final String imagePath;

  /// The photo, for the preview (optional).
  final Uint8List? imageBytes;

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen>
    with SingleTickerProviderStateMixin {
  /// Moves the green scan line up and down (1.6 s each way).
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  ScanStage _stage = ScanStage.reading;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _sweep.dispose(); // stop the animation when the screen closes
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => _error = null);
    try {
      final result = await ReceiptScanner.instance.scanImage(
        widget.imagePath,
        onStage: (stage) {
          if (mounted) setState(() => _stage = stage);
        },
      );
      if (!mounted) return;
      // pushReplacement: Back from Assign Items skips this finished screen.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AssignItems(scan: result)),
      );
    } on ScanFailure catch (e) {
      if (mounted) setState(() => _error = e.message); // error state
    }
  }

  void _retake() => Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const CameraCapture()),
  );

  void _enterManually() => Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const ManualReceiptEntry()),
  );

  @override
  Widget build(BuildContext context) => AppPage(
    'Scanning',
    Column(
      children: [
        _ReceiptPreview(
          bytes: widget.imageBytes,
          sweep: _error == null ? _sweep : null,
        ),
        const SizedBox(height: 20),
        if (_error == null) ...[
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(color: green, strokeWidth: 3),
          ),
          const SizedBox(height: 12),
          Text(
            _stage == ScanStage.reading
                ? 'Reading your receipt…'
                : 'Organizing items with AI…',
            style: AppText.section,
          ),
          const SizedBox(height: 4),
          const Text('Usually takes a few seconds.', style: AppText.caption),
          const SizedBox(height: 20),
          const InfoBanner(
            "We'll mark any item we're unsure about as \"Needs review\" so "
            'you can fix it fast.',
            icon: Icons.info_outline,
          ),
        ] else ...[
          const Icon(Icons.receipt_long_outlined, color: errorFg, size: 40),
          const SizedBox(height: 8),
          Text("Couldn't scan this receipt", style: AppText.section),
          const SizedBox(height: 4),
          Text(_error!, textAlign: TextAlign.center, style: AppText.caption),
          const SizedBox(height: 20),
          Btn('Retake photo', _retake, icon: Icons.camera_alt_outlined),
          const SizedBox(height: 10),
          Btn('Enter manually', _enterManually, outlined: true),
        ],
      ],
    ),
  );
}

/// The photo in a rounded card, with an animated scan line on top.
class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({required this.bytes, required this.sweep});

  final Uint8List? bytes;

  /// null = no animation (e.g. on the error state).
  final Animation<double>? sweep;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: SizedBox(
      height: 300,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          bytes == null
              ? Container(
                  color: mint,
                  child: const Icon(Icons.receipt_long, color: green, size: 64),
                )
              : Image.memory(bytes!, fit: BoxFit.cover),
          if (sweep != null)
            AnimatedBuilder(
              animation: sweep!,
              builder: (context, _) => Align(
                // -1 = top, 1 = bottom
                alignment: Alignment(0, sweep!.value * 2 - 1),
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: green,
                    boxShadow: [
                      BoxShadow(
                        color: green.withValues(alpha: 0.6),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
