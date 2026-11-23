/// Join a group with an invite code: type it, paste the invite link, or
/// scan the group's QR code. Opened from Home ("Join").
///
/// Validated form: the code must be 5 valid characters and the name must
/// pass [validatePersonName]. Shows loading on the button and errors
/// (unknown code, no internet) as a toast.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/screens/group/group_detail_screen.dart';
import 'package:bahinko/screens/group/scan_invite_screen.dart';
import 'package:bahinko/services/auth_service.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/validators.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/app_toast.dart';
import 'package:bahinko/widgets/btn.dart';
import 'package:bahinko/widgets/info_banner.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key, this.initialCode});

  /// Pre-filled code (e.g. from a scanned QR code).
  final String? initialCode;

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _codeController.text = widget.initialCode ?? '';
    _nameController.text = AuthService.instance.displayName ?? '';
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String? _validateCode(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Enter the invite code';
    return parseInviteCode(value!) == null
        ? 'Codes are 5 letters/numbers, like DJ7Q2'
        : null;
  }

  /// Opens the camera; if a QR invite is found, fills in the code.
  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanInviteScreen()),
    );
    if (code != null && mounted) {
      setState(() => _codeController.text = code);
      showAppToast(context, 'Code $code scanned');
    }
  }

  Future<void> _join() async {
    if (!_formKey.currentState!.validate()) return;
    final code = parseInviteCode(_codeController.text)!;
    final name = _nameController.text.trim();

    setState(() => _joining = true);
    try {
      // Remember the name for next time (and for groups you create).
      if (name != AuthService.instance.displayName) {
        await AuthService.instance.setDisplayName(name);
      }
      final groupId = await GroupService.instance.joinGroup(code, name);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GroupDetail(groupId: groupId)),
      );
      showAppToast(context, "You're in! Welcome to the group.");
    } on GroupFailure catch (e) {
      _failed(e.message);
    } on AuthFailure catch (e) {
      _failed(e.message);
    }
  }

  /// Error state: show the message and re-enable the button.
  void _failed(String message) {
    if (!mounted) return;
    setState(() => _joining = false);
    showAppToast(context, message);
  }

  @override
  Widget build(BuildContext context) => AppPage(
    'Join a Group',
    Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InfoBanner(
            "Ask a member for the group's invite code, link, or QR code. "
            'You can find it on their Invite screen.',
            icon: Icons.group_add_outlined,
          ),
          const SizedBox(height: 20),
          Text('Invite code', style: AppText.section),
          const SizedBox(height: 8),
          TextFormField(
            key: const ValueKey('invite-code'),
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'DJ7Q2 or bahinko.app/j/DJ7Q2',
              suffixIcon: canScanQr
                  ? IconButton(
                      tooltip: 'Scan QR code',
                      icon: const Icon(Icons.qr_code_scanner, color: green),
                      onPressed: _scan,
                    )
                  : null,
            ),
            validator: _validateCode,
          ),
          const SizedBox(height: 16),
          Text('Your name', style: AppText.section),
          const SizedBox(height: 8),
          TextFormField(
            key: const ValueKey('join-name'),
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'How the group sees you',
            ),
            validator: validatePersonName,
            onFieldSubmitted: (_) => _join(),
          ),
        ],
      ),
    ),
    bottom: Btn(_joining ? 'Joining…' : 'Join group', _joining ? null : _join),
  );
}
