/// "What should friends call you?": asks for the user's first name right
/// after sign-in, so groups show real names instead of "You".
///
/// Only a name is collected (no email/phone): the minimum personal data
/// the app needs (Data Privacy Act, RA 10173).
library;

import 'package:flutter/material.dart';

import 'package:bahinko/screens/auth/app_lock_screen.dart';
import 'package:bahinko/services/auth_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/validators.dart';
import 'package:bahinko/widgets/app_toast.dart';
import 'package:bahinko/widgets/btn.dart';

class YourNameScreen extends StatefulWidget {
  const YourNameScreen({super.key});

  @override
  State<YourNameScreen> createState() => _YourNameScreenState();
}

class _YourNameScreenState extends State<YourNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill if the user already set a name before (e.g. reinstall).
    _nameController.text = AuthService.instance.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Validates, saves the name to the account, then continues to the PIN.
  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AuthService.instance.setDisplayName(_nameController.text);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppLockScreen()),
      );
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: mint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.badge_outlined, color: green, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'What should friends call you?',
                style: AppText.display(26, color: ink),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your name appears in the groups you join. '
                'We only ask for a name: no email or phone number.',
                style: AppText.caption,
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const ValueKey('your-name'),
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  hintText: 'e.g. Renz',
                ),
                validator: validatePersonName,
                onFieldSubmitted: (_) => _continue(),
              ),
              const SizedBox(height: 24),
              Btn(_saving ? 'Saving…' : 'Continue', _saving ? null : _continue),
            ],
          ),
        ),
      ),
    ),
  );
}
