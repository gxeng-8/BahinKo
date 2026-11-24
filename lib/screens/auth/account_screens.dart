/// Accounts: "Create account" (name, @username, 6-digit PIN) and
/// "Sign in" (@username + PIN). The same PIN also unlocks the app on this
/// phone, so people only remember one thing.
///
/// Both are validated forms with loading and error states. After either,
/// the PIN is saved on the phone (as a salted hash, AppLockService) and the
/// app opens.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bahinko/screens/shell.dart';
import 'package:bahinko/services/app_lock_service.dart';
import 'package:bahinko/services/auth_service.dart';
import 'package:bahinko/services/settings_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/utils/validators.dart';
import 'package:bahinko/widgets/app_logo.dart';
import 'package:bahinko/widgets/app_toast.dart';
import 'package:bahinko/widgets/btn.dart';

/// Saves [pin] as this phone's app-lock PIN and opens the app.
Future<void> finishSignIn(BuildContext context, String pin) async {
  await AppLockService.instance.setPin(pin);
  await SettingsService.instance.setAppLockEnabled(true);
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const Shell()),
    (_) => false,
  );
}

/// A hidden 6-digit PIN box.
class PinField extends StatelessWidget {
  const PinField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: true,
    keyboardType: TextInputType.number,
    maxLength: AppLockService.newPinLength,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      counterText: '',
      prefixIcon: const Icon(Icons.pin_outlined),
    ),
    validator: validator,
    onFieldSubmitted: onSubmitted,
    onChanged: onChanged,
  );
}

/// "@yumi" box.
class UsernameField extends StatelessWidget {
  const UsernameField({super.key, required this.controller, this.validate});

  final TextEditingController controller;

  /// Check the rules (new usernames) or only that it's filled (sign in).
  final bool? validate;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    autocorrect: false,
    textCapitalization: TextCapitalization.none,
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._@]')),
    ],
    decoration: const InputDecoration(
      labelText: 'Username',
      hintText: 'e.g. yumi',
      prefixText: '@',
    ),
    validator: validate == false
        ? (v) =>
              normalizeUsername(v ?? '').isEmpty ? 'Enter your username' : null
        : validateUsername,
  );
}

/// White page with the logo, a title and a form.
class _AccountPage extends StatelessWidget {
  const _AccountPage({
    required this.title,
    required this.subtitle,
    required this.form,
  });

  final String title;
  final String subtitle;
  final Widget form;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(backgroundColor: Colors.white),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppLogo(size: 56),
            const SizedBox(height: 16),
            Text(title, style: AppText.display(26, color: ink)),
            const SizedBox(height: 6),
            Text(subtitle, style: AppText.caption),
            const SizedBox(height: 20),
            form,
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    try {
      _name.text = AuthService.instance.displayName ?? '';
    } catch (_) {} // Firebase not started (tests)
  }

  @override
  void dispose() {
    for (final c in [_name, _username, _pin, _pin2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AuthService.instance.createAccount(
        name: _name.text.trim(),
        username: normalizeUsername(_username.text),
        pin: _pin.text,
      );
      if (!mounted) return;
      await finishSignIn(context, _pin.text);
      if (mounted) showAppToast(context, 'Account created. Welcome!');
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => _AccountPage(
    title: 'Create your account',
    subtitle:
        'Your username and PIN get you back in after logging out or '
        'on a new phone. No email or phone number needed.',
    form: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('account-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Your name',
              hintText: 'What friends call you, e.g. Renz',
            ),
            validator: validatePersonName,
          ),
          const SizedBox(height: 12),
          UsernameField(
            key: const ValueKey('account-username'),
            controller: _username,
          ),
          const SizedBox(height: 12),
          PinField(
            key: const ValueKey('account-pin'),
            controller: _pin,
            label: '6-digit PIN',
            validator: validateNewPin,
          ),
          const SizedBox(height: 12),
          PinField(
            key: const ValueKey('account-pin2'),
            controller: _pin2,
            label: 'Enter the PIN again',
            validator: (v) => v != _pin.text ? "PINs don't match" : null,
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: 8),
          const Text(
            'The same PIN unlocks BahinKo on this phone. '
            "Don't share it.",
            style: AppText.caption,
          ),
          const SizedBox(height: 20),
          Btn(
            _saving ? 'Creating…' : 'Create account',
            _saving ? null : _create,
            key: const ValueKey('account-create'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _saving
                ? null
                : () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                  ),
            child: const Text(
              'Already have an account? Sign in',
              style: TextStyle(color: green, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _pin = TextEditingController();
  bool _signingIn = false;

  @override
  void dispose() {
    _username.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _signingIn = true);
    try {
      await AuthService.instance.signInWithPin(
        username: normalizeUsername(_username.text),
        pin: _pin.text,
      );
      if (!mounted) return;
      await finishSignIn(context, _pin.text);
      if (mounted) {
        final name = AuthService.instance.displayName;
        showAppToast(context, 'Welcome back${name == null ? '' : ', $name'}!');
      }
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _signingIn = false);
      showAppToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => _AccountPage(
    title: 'Welcome back',
    subtitle: 'Sign in with your username and PIN to get your groups back.',
    form: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UsernameField(
            key: const ValueKey('signin-username'),
            controller: _username,
            validate: false,
          ),
          const SizedBox(height: 12),
          PinField(
            key: const ValueKey('signin-pin'),
            controller: _pin,
            label: 'PIN',
            validator: (v) => (v ?? '').length < 4 ? 'Enter your PIN' : null,
            onSubmitted: (_) => _signIn(),
          ),
          const SizedBox(height: 20),
          Btn(
            _signingIn ? 'Signing in…' : 'Sign in',
            _signingIn ? null : _signIn,
            key: const ValueKey('signin-submit'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _signingIn
                ? null
                : () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateAccountScreen(),
                    ),
                  ),
            child: const Text(
              'New here? Create an account',
              style: TextStyle(color: green, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}
