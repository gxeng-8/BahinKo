/// Welcome screen (first run / after logging out), drawn to match the
/// team's design: deep-green background with two circles, the logo tile,
/// "BahinKo", the tagline, the BahinKo mascot peeking up, and a white
/// "Get Started" button.
///
/// "Get Started" opens Create account (name, @username, PIN); "I already
/// have an account" opens Sign in, so a reinstall gets the same account.
///
/// Sizes are fractions of the screen width so it looks the same on small
/// and large phones. The mascot and logo tile are images cut from the
/// design (assets/onboarding/).
library;

import 'package:flutter/material.dart';

import 'package:bahinko/screens/auth/account_screens.dart';

/// Colours sampled from the design.
const _background = Color(0xFF026D46);
const _lightCircle = Color(0xFF239065);
const _darkCircle = Color(0xFF01442B);
const _buttonText = Color(0xFF12794B);

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    body: LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        // The mascot keeps its real proportions, but gives way on very
        // short screens so the buttons always fit.
        final mascotHeight = (w * 551 / 841).clamp(0.0, box.maxHeight * 0.32);
        return Stack(
          children: [
            // Light circle in the top-left, dark one on the top-right.
            Positioned(
              left: w * 0.15 - w * 0.38,
              top: -w * 0.13 - w * 0.38,
              child: _Circle(w * 0.76, _lightCircle),
            ),
            Positioned(
              left: w - w * 0.26,
              top: w * 0.13 - w * 0.26,
              child: _Circle(w * 0.52, _darkCircle),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Same split of empty space as the design: more above
                  // the logo than between the text and the mascot.
                  const Spacer(flex: 22),
                  Center(
                    child: Image.asset(
                      'assets/onboarding/logo_tile.png',
                      width: w * 0.245,
                      semanticLabel: 'BahinKo logo',
                    ),
                  ),
                  SizedBox(height: w * 0.02),
                  Text(
                    'BahinKo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: w * 0.118,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: w * 0.07),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'BahinKo nang tama, bayad nang kaunti.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: w * 0.042,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: w * 0.02),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Split bills with friends without the awkward math',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: w * 0.037,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 10),
                  // The mascot, edge to edge.
                  SizedBox(
                    height: mascotHeight,
                    child: Image.asset(
                      'assets/onboarding/mascot.png',
                      width: w,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      semanticLabel: 'BahinKo mascot',
                    ),
                  ),
                  SizedBox(height: w * 0.045),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: w * 0.055),
                    child: SizedBox(
                      height: 54,
                      child: FilledButton(
                        key: const ValueKey('get-started'),
                        onPressed: () => _open(const CreateAccountScreen()),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _buttonText,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('have-account'),
                    onPressed: () => _open(const SignInScreen()),
                    child: const Text(
                      'I already have an account',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// A plain filled circle (background decoration).
class _Circle extends StatelessWidget {
  const _Circle(this.size, this.color);

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
