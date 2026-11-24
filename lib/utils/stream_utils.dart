/// Small helpers for working with several streams at once.
library;

import 'dart:async';

/// Emits [combine](a, b, c) whenever ANY of the three streams emits, once
/// all three have emitted at least once (like RxDart's combineLatest).
/// An error from any stream is passed on. Cancelling cancels all three.
Stream<R> combineLatest3<A, B, C, R>(
  Stream<A> sa,
  Stream<B> sb,
  Stream<C> sc,
  R Function(A a, B b, C c) combine,
) {
  late final StreamController<R> out;
  final subs = <StreamSubscription<Object?>>[];
  A? a;
  B? b;
  C? c;
  var hasA = false, hasB = false, hasC = false;

  void emit() {
    if (hasA && hasB && hasC) out.add(combine(a as A, b as B, c as C));
  }

  out = StreamController<R>(
    onListen: () {
      subs
        ..add(
          sa.listen((v) {
            a = v;
            hasA = true;
            emit();
          }, onError: out.addError),
        )
        ..add(
          sb.listen((v) {
            b = v;
            hasB = true;
            emit();
          }, onError: out.addError),
        )
        ..add(
          sc.listen((v) {
            c = v;
            hasC = true;
            emit();
          }, onError: out.addError),
        );
    },
    onCancel: () => Future.wait(subs.map((s) => s.cancel())),
  );
  return out.stream;
}

/// Two-stream version of [combineLatest3].
Stream<R> combineLatest2<A, B, R>(
  Stream<A> sa,
  Stream<B> sb,
  R Function(A a, B b) combine,
) => combineLatest3<A, B, bool, R>(
  sa,
  sb,
  Stream.value(true),
  (a, b, _) => combine(a, b),
);
