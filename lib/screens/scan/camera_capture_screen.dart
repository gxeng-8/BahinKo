/// Camera preview, capture, and on-device OCR of the receipt.
library;

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bahinko/models/receipt_line_item.dart';
import 'package:bahinko/utils/navigation.dart';
import 'package:bahinko/screens/bill/manual_receipt_entry_screen.dart';
import 'package:bahinko/screens/bill/assign_items_screen.dart';
import 'package:bahinko/utils/receipt_ocr.dart';
import 'package:bahinko/utils/receipt_parser.dart';

class CameraCapture extends StatefulWidget {
  const CameraCapture({super.key});

  @override
  State<CameraCapture> createState() => _CameraCaptureState();
}

class _CameraCaptureState extends State<CameraCapture>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Uint8List? _capturedImage;
  String? _capturedImagePath;
  String? _cameraError;
  String? _cameraHelp;
  String? _scanError;
  bool _initializing = false;
  bool _capturing = false;
  bool _processing = false;
  bool _isActive = true;
  bool _resumeRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  Future<void> _initializeCamera() async {
    if (_initializing) {
      _resumeRequested = true;
      return;
    }
    if (!mounted || !_isActive) return;
    _initializing = true;
    setState(() {
      _cameraError = null;
      _cameraHelp = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _cameraError = 'No camera was found on this device.';
            _cameraHelp =
                'Connect a webcam, close other apps using it, and try again.';
          });
        }
        return;
      }

      final controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted || !_isActive) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _cameraError = _cameraErrorMessage(error);
          _cameraHelp = _cameraHelpMessage(error);
        });
      }
    } finally {
      final resumeRequested = _resumeRequested;
      _resumeRequested = false;
      _initializing = false;
      if (resumeRequested &&
          mounted &&
          _isActive &&
          _controller == null &&
          _cameraError == null &&
          _capturedImage == null) {
        unawaited(_initializeCamera());
      }
    }
  }

  Future<void> _captureImage() async {
    final controller = _controller;
    if (controller == null || _capturing) return;

    setState(() => _capturing = true);
    try {
      final image = await controller.takePicture();
      final bytes = await image.readAsBytes();
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _controller = null;
        _capturedImage = bytes;
        _capturedImagePath = image.path;
        _processing = true;
      });
      await _recognizeReceipt(image.path);
    } on CameraException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_cameraErrorMessage(error)} ${_cameraHelpMessage(error)}',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _scanError = 'Could not process the photo: $error';
          _processing = false;
        });
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _recognizeReceipt(String path) async {
    try {
      final text = await recognizeReceiptText(path);
      final parsedItems = parseReceiptItems(text ?? '');
      if (!mounted) return;

      if (parsedItems.isEmpty) {
        setState(() {
          _scanError = 'No receipt items were recognized. Try another photo or enter them manually.';
          _processing = false;
        });
        return;
      }

      setState(() => _processing = false);
      go(
        context,
        AssignItems(
          receiptItems: [
            for (final (name, amountInCents) in parsedItems)
              ReceiptLineItem(name, amountInCents),
          ],
          storeName: 'Scanned Receipt',
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _scanError = 'Receipt recognition failed: $error';
          _processing = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _isActive = false;
      final controller = _controller;
      if (controller != null) {
        setState(() => _controller = null);
        unawaited(controller.dispose());
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _isActive = true;
      if (_capturedImage == null && _controller == null) {
        unawaited(_initializeCamera());
      }
    }
  }

  @override
  void dispose() {
    _isActive = false;
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan Receipt'), centerTitle: true),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black,
              alignment: Alignment.center,
              child: _buildPreview(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildControls(context),
          ),
        ],
      ),
    ),
  );

  Widget _buildPreview() {
    final image = _capturedImage;
    if (image != null) {
      return Image.memory(image, fit: BoxFit.contain);
    }

    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      return CameraPreview(controller);
    }

    final error = _cameraError;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(
              error,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            if (_cameraHelp != null) ...[
              const SizedBox(height: 8),
              Text(
                _cameraHelp!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return const CircularProgressIndicator(color: Colors.white);
  }

  Widget _buildControls(BuildContext context) {
    if (_capturedImage != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_processing)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Reading receipt...'),
              ],
            )
          else if (_scanError != null)
            Text(_scanError!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _initializing || _processing
                      ? null
                      : () {
                          setState(() {
                            _capturedImage = null;
                            _capturedImagePath = null;
                            _cameraError = null;
                            _cameraHelp = null;
                            _scanError = null;
                          });
                          unawaited(_initializeCamera());
                        },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake'),
                ),
              ),
              if (_scanError != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _processing
                        ? null
                        : () {
                            final path = _capturedImagePath;
                            if (path == null) return;
                            setState(() {
                              _scanError = null;
                              _processing = true;
                            });
                            unawaited(_recognizeReceipt(path));
                          },
                    child: const Text('Retry scan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _processing
                        ? null
                        : () => go(context, const ManualReceiptEntry()),
                    child: const Text('Enter manually'),
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    }

    if (_cameraError != null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _initializing ? null : _initializeCamera,
          icon: const Icon(Icons.refresh),
          label: Text(_initializing ? 'Connecting...' : 'Try again'),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _controller == null || _capturing ? null : _captureImage,
        icon: const Icon(Icons.camera_alt),
        label: Text(_capturing ? 'Capturing...' : 'Take photo'),
      ),
    );
  }

  String _cameraErrorMessage(CameraException error) {
    if (error.code == 'CameraAccessDenied' ||
        error.code == 'CameraAccessDeniedWithoutPrompt') {
      return 'Camera access was denied.';
    }
    return error.description ?? 'Unable to access the camera (${error.code}).';
  }

  String _cameraHelpMessage(CameraException error) {
    if (error.code == 'CameraAccessDenied' ||
        error.code == 'CameraAccessDeniedWithoutPrompt') {
      if (kIsWeb) {
        return "Allow camera access in your browser's site settings, then retry.";
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.windows:
          return 'In Windows Settings > Privacy & security > Camera, enable camera access and access for desktop apps.';
        case TargetPlatform.macOS:
          return 'Allow camera access for BahinKo in System Settings > Privacy & Security > Camera.';
        case TargetPlatform.android:
          return 'Allow camera access for BahinKo in the app permissions in Settings.';
        case TargetPlatform.iOS:
          return 'Allow camera access for BahinKo in Settings > Privacy & Security > Camera.';
        case TargetPlatform.linux:
        case TargetPlatform.fuchsia:
          return 'Check your system camera permissions, then retry.';
      }
    }
    return 'Check that your camera is connected and not in use by another app, then retry.';
  }
}
