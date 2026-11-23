// Tests for the app lock: PIN hashing, saved lockout, and fingerprint.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bahinko/screens/auth/app_lock_screen.dart';
import 'package:bahinko/screens/shell.dart';
import 'package:bahinko/services/app_lock_service.dart';
import 'package:bahinko/services/biometric_service.dart';
import 'package:bahinko/services/secure_store.dart';

/// Pretends the device has a fingerprint sensor.
class _FakeBiometrics extends BiometricService {
  _FakeBiometrics({this.available = true, this.recognized = false});
  final bool available;
  final bool recognized;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate() async {
    prompts++;
    return recognized;
  }
}

void main() {
  late MemoryStore store;

  setUp(() {
    store = MemoryStore();
    AppLockService.instance = AppLockService(store: store);
    // No fingerprint sensor by default (the real plugin can't run here).
    BiometricService.instance = _FakeBiometrics(available: false);
  });

  test('PIN is saved as a salted hash, never as the PIN itself', () async {
    await AppLockService.instance.setPin('1234');

    final hash = await store.read('pin_hash');
    expect(hash, isNotNull);
    expect(hash, isNot(contains('1234')));
    expect(hash!.length, 64); // SHA-256 in hex

    // A "restarted app" (new service, same storage) still knows the PIN.
    final restarted = AppLockService(store: store);
    expect(await restarted.hasPin(), isTrue);
    expect(await restarted.verify('1234'), isA<PinCorrect>());
    expect(await restarted.verify('9999'), isA<PinWrong>());
  });

  test('same PIN gets a different hash each time (random salt)', () async {
    await AppLockService.instance.setPin('1234');
    final first = await store.read('pin_hash');
    await AppLockService.instance.setPin('1234');
    expect(await store.read('pin_hash'), isNot(first));
  });

  test(
    '5 wrong PINs lock it out, and the lockout survives a restart',
    () async {
      final lock = AppLockService.instance;
      await lock.setPin('1234');
      for (var i = 1; i < AppLockService.maxAttempts; i++) {
        final r = await lock.verify('0000');
        expect((r as PinWrong).attemptsLeft, AppLockService.maxAttempts - i);
      }
      expect(await lock.verify('0000'), isA<PinLockedOut>());

      // Even the right PIN is refused during the lockout, after a restart too.
      final restarted = AppLockService(store: store);
      expect(await restarted.verify('1234'), isA<PinLockedOut>());
      expect(await restarted.lockoutRemaining(), isNotNull);
    },
  );

  testWidgets('unlock screen shows tries left, then the lockout countdown', (
    tester,
  ) async {
    await AppLockService.instance.setPin('1234');
    await tester.pumpWidget(const MaterialApp(home: AppLockScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    Future<void> type(String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.text(d));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    await type('0000');
    expect(find.text('Incorrect PIN. 4 tries left.'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await type('0000');
    }
    expect(find.textContaining('Too many tries'), findsOneWidget);
  });

  testWidgets('fingerprint is offered automatically and unlocks the app', (
    tester,
  ) async {
    final bio = _FakeBiometrics(recognized: true);
    BiometricService.instance = bio;
    await AppLockService.instance.setPin('1234');

    await tester.pumpWidget(const MaterialApp(home: AppLockScreen()));
    await tester.pumpAndSettle();
    expect(bio.prompts, 1);
    expect(find.byType(Shell), findsOneWidget);
  });

  testWidgets('a failed fingerprint leaves the PIN pad usable', (tester) async {
    BiometricService.instance = _FakeBiometrics(recognized: false);
    await AppLockService.instance.setPin('1234');

    await tester.pumpWidget(const MaterialApp(home: AppLockScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Use fingerprint instead'), findsOneWidget);
    expect(find.byType(Shell), findsNothing);

    for (final d in '1234'.split('')) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(Shell), findsOneWidget);
  });
}
