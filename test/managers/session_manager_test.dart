import 'package:fake_async/fake_async.dart';
import 'package:flutter_security_suite/managers/secure_token_storage.dart';
import 'package:flutter_security_suite/managers/session_manager.dart';
import 'package:flutter_security_suite/managers/token_expiry_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_storage.dart';

const _timeout = Duration(minutes: 5);

void main() {
  final start = DateTime.utc(2026, 1, 1, 12);
  late FakeStorage storage;
  late SecureTokenStorage tokens;
  late TokenExpiryManager expiry;

  setUp(() {
    storage = FakeStorage();
    tokens = SecureTokenStorage(storage);
    expiry = TokenExpiryManager(storage: storage, tokenStorage: tokens);
    storage.data.addAll({
      'sbk.access_token': 'a',
      'sbk.refresh_token': 'r',
      'sbk.token_expiry': '123',
      'unrelated': 'keep me',
    });
  });

  /// Runs [body] under fake time with a manager whose clock follows it
  /// (plus an adjustable [skew] to simulate wall-clock jumps).
  void run(
    void Function(FakeAsync async, SessionManager sut, List<int> events,
            void Function(Duration) skew)
        body, {
    bool withTokens = true,
    bool clearTokensOnExpiry = true,
  }) {
    fakeAsync((async) {
      var offset = Duration.zero;
      final sut = SessionManager(
        timeout: _timeout,
        tokenStorage: withTokens ? tokens : null,
        tokenExpiry: withTokens ? expiry : null,
        clearTokensOnExpiry: clearTokensOnExpiry,
        now: () => start.add(async.elapsed).add(offset),
      );
      final events = <int>[];
      sut.onSessionExpired.listen((_) => events.add(async.elapsed.inSeconds));
      body(async, sut, events, (d) => offset += d);
      sut.dispose();
      async.flushMicrotasks();
    });
  }

  group('construction', () {
    test('rejects a zero or negative timeout', () {
      expect(() => SessionManager(timeout: Duration.zero), throwsArgumentError);
      expect(
        () => SessionManager(timeout: const Duration(seconds: -1)),
        throwsArgumentError,
      );
    });

    test('starts without a session', () {
      final sut = SessionManager(timeout: _timeout);
      expect(sut.isActive, isFalse);
      expect(sut.remainingTime, Duration.zero);
      expect(sut.recordActivity(), isFalse);
    });
  });

  group('inactivity timeout', () {
    test('a started session is active with the full time remaining', () {
      run((async, sut, events, _) {
        sut.startSession();
        expect(sut.isActive, isTrue);
        expect(sut.remainingTime, _timeout);
      });
    });

    test('remaining time counts down', () {
      run((async, sut, events, _) {
        sut.startSession();
        async.elapse(const Duration(minutes: 2));
        expect(sut.remainingTime, const Duration(minutes: 3));
      });
    });

    test('expires exactly at the timeout and fires once', () {
      run((async, sut, events, _) {
        sut.startSession();
        async.elapse(_timeout - const Duration(seconds: 1));
        expect(sut.isActive, isTrue);
        expect(events, isEmpty);
        async.elapse(const Duration(seconds: 1));
        expect(sut.isActive, isFalse);
        expect(sut.remainingTime, Duration.zero);
        expect(events, [300]);
        async.elapse(const Duration(hours: 1));
        expect(events, [300]);
      });
    });

    test('clears tokens and expiry but nothing else', () {
      run((async, sut, events, _) {
        sut.startSession();
        async.elapse(_timeout);
        expect(storage.data, {'unrelated': 'keep me'});
      });
    });

    test('fires the event only after the tokens were cleared', () {
      run((async, sut, events, _) {
        Map<String, String>? seen;
        sut.onSessionExpired.listen((_) => seen = Map.of(storage.data));
        sut.startSession();
        async.elapse(_timeout);
        expect(seen, {'unrelated': 'keep me'});
      });
    });

    test('keeps tokens when clearTokensOnExpiry is off', () {
      run((async, sut, events, _) {
        sut.startSession();
        async.elapse(_timeout);
        expect(events, hasLength(1));
        expect(storage.data, hasLength(4));
      }, clearTokensOnExpiry: false);
    });

    test('still fires when clearing the tokens fails', () {
      run((async, sut, events, _) {
        storage.failDeletes.addAll(['sbk.access_token', 'sbk.token_expiry']);
        sut.startSession();
        async.elapse(_timeout);
        expect(events, hasLength(1));
        expect(sut.isActive, isFalse);
      });
    });

    test('still fires when clearing the tokens throws', () {
      run((async, sut, events, _) {
        storage.throwDeletes.add('sbk.token_expiry');
        sut.startSession();
        async.elapse(_timeout);
        expect(events, hasLength(1));
      });
    });

    test('works without any token storage', () {
      run((async, sut, events, _) {
        sut.startSession();
        async.elapse(_timeout);
        expect(events, hasLength(1));
        expect(storage.data, hasLength(4));
      }, withTokens: false);
    });

    test('notifies every listener', () {
      run((async, sut, events, _) {
        var second = 0;
        sut.onSessionExpired.listen((_) => second++);
        sut.startSession();
        async.elapse(_timeout);
        expect(events, hasLength(1));
        expect(second, 1);
      });
    });
  });

  group('recordActivity', () {
    test('pushes the expiry back', () {
      run((async, sut, events, _) {
        sut.startSession();
        async.elapse(const Duration(minutes: 4));
        expect(sut.recordActivity(), isTrue);
        expect(sut.remainingTime, _timeout);
        async.elapse(const Duration(minutes: 4));
        expect(sut.isActive, isTrue);
        expect(events, isEmpty);
        async.elapse(const Duration(minutes: 1));
        expect(events, [540]);
      });
    });

    test('repeated activity keeps the session alive indefinitely', () {
      run((async, sut, events, _) {
        sut.startSession();
        for (var i = 0; i < 50; i++) {
          async.elapse(const Duration(minutes: 4));
          expect(sut.recordActivity(), isTrue);
        }
        expect(events, isEmpty);
        expect(storage.data, hasLength(4));
      });
    });

    test('returns false after expiry and does not revive the session', () {
      run((async, sut, events, _) {
        sut.startSession();
        async.elapse(_timeout);
        expect(sut.recordActivity(), isFalse);
        expect(sut.isActive, isFalse);
        async.elapse(_timeout);
        expect(events, hasLength(1));
      });
    });

    test('expires instead of extending when the wall clock jumped ahead', () {
      // e.g. the app was suspended, so the timer never ran.
      run((async, sut, events, skew) {
        sut.startSession();
        async.elapse(const Duration(minutes: 1));
        skew(const Duration(hours: 1));
        expect(sut.isActive, isFalse);
        expect(sut.remainingTime, Duration.zero);
        expect(sut.recordActivity(), isFalse);
        async.flushMicrotasks();
        expect(events, [60]);
        expect(storage.data, {'unrelated': 'keep me'});
        // The stale timer must not fire a second event.
        async.elapse(_timeout);
        expect(events, hasLength(1));
      });
    });

    test('a clock moved backwards restarts the countdown', () {
      run((async, sut, events, skew) {
        sut.startSession();
        async.elapse(const Duration(minutes: 1));
        skew(const Duration(hours: -3));
        expect(sut.isActive, isTrue);
        expect(sut.remainingTime, _timeout);
        // Must not stay alive for three extra hours.
        async.elapse(const Duration(minutes: 4));
        expect(sut.isActive, isTrue);
        async.elapse(const Duration(minutes: 1));
        expect(sut.isActive, isFalse);
        expect(events, hasLength(1));
      });
    });
  });

  group('startSession', () {
    test('restarting resets the countdown', () {
      run((async, sut, events, _) {
        sut.startSession();
        async.elapse(const Duration(minutes: 4));
        sut.startSession();
        async.elapse(const Duration(minutes: 4));
        expect(sut.isActive, isTrue);
        async.elapse(const Duration(minutes: 1));
        expect(events, [540]);
      });
    });

    test('a new session can start after expiry', () {
      run((async, sut, events, _) {
        sut.startSession();
        async.elapse(_timeout);
        sut.startSession();
        expect(sut.isActive, isTrue);
        async.elapse(_timeout);
        expect(events, [300, 600]);
      });
    });
  });

  group('endSession', () {
    test('stops the session without firing the expiry event', () {
      run((async, sut, events, _) {
        sut.startSession();
        final results = <bool>[];
        sut.endSession().then((r) => results.add(r.isSuccess));
        async.flushMicrotasks();
        expect(results, [true]);
        expect(sut.isActive, isFalse);
        expect(sut.recordActivity(), isFalse);
        expect(storage.data, {'unrelated': 'keep me'});
        async.elapse(const Duration(hours: 1));
        expect(events, isEmpty);
      });
    });

    test('can keep the tokens', () {
      run((async, sut, events, _) {
        sut.startSession();
        sut.endSession(clearTokens: false);
        async.flushMicrotasks();
        expect(storage.data, hasLength(4));
      });
    });

    test('is safe without a running session', () {
      run((async, sut, events, _) {
        final results = <bool>[];
        sut.endSession().then((r) => results.add(r.isSuccess));
        async.flushMicrotasks();
        expect(results, [true]);
      });
    });

    test('reports a cleanup failure but still ends the session', () {
      run((async, sut, events, _) {
        storage.failDeletes.add('sbk.refresh_token');
        sut.startSession();
        final results = <bool>[];
        sut.endSession().then((r) => results.add(r.isFailure));
        async.flushMicrotasks();
        expect(results, [true]);
        expect(sut.isActive, isFalse);
        // The remaining cleanup still ran.
        expect(storage.data.containsKey('sbk.token_expiry'), isFalse);
      });
    });

    test('reports a failure to clear the expiry', () {
      run((async, sut, events, _) {
        storage.failDeletes.add('sbk.token_expiry');
        sut.startSession();
        final results = <bool>[];
        sut.endSession().then((r) => results.add(r.isFailure));
        async.flushMicrotasks();
        expect(results, [true]);
      });
    });
  });

  group('dispose', () {
    test('closes the stream and cancels the timer', () {
      fakeAsync((async) {
        final sut = SessionManager(
          timeout: _timeout,
          tokenStorage: tokens,
          now: () => start.add(async.elapsed),
        );
        var events = 0;
        var done = false;
        sut.onSessionExpired.listen((_) => events++, onDone: () => done = true);
        sut.startSession();
        sut.dispose();
        async.flushMicrotasks();
        expect(done, isTrue);
        async.elapse(const Duration(hours: 1));
        expect(events, 0);
        expect(sut.isActive, isFalse);
        // Tokens are kept on dispose.
        expect(storage.data, hasLength(4));
      });
    });

    test('is idempotent', () async {
      final sut = SessionManager(timeout: _timeout);
      await sut.dispose();
      await sut.dispose();
    });

    test('startSession throws afterwards', () async {
      final sut = SessionManager(timeout: _timeout);
      await sut.dispose();
      expect(sut.startSession, throwsStateError);
      expect(sut.recordActivity(), isFalse);
    });

    test('endSession still works afterwards', () async {
      final sut = SessionManager(timeout: _timeout, tokenStorage: tokens);
      await sut.dispose();
      expect((await sut.endSession()).isSuccess, isTrue);
      expect(storage.data.containsKey('sbk.access_token'), isFalse);
    });

    test('disposing while the expiry cleanup runs does not throw', () {
      fakeAsync((async) {
        final sut = SessionManager(
          timeout: _timeout,
          tokenStorage: tokens,
          now: () => start.add(async.elapsed),
        );
        sut.startSession();
        async.elapse(_timeout - const Duration(seconds: 1));
        // Expire synchronously via the wall clock, then dispose right away.
        async.elapse(const Duration(seconds: 1));
        sut.dispose();
        async.flushMicrotasks();
        expect(sut.isActive, isFalse);
      });
    });
  });
}
