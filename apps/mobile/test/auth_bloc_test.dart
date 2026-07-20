import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare_mobile/features/auth/bloc/auth_bloc.dart';

import 'fakes.dart';

void main() {
  group('AuthBloc', () {
    test('restores to Unauthenticated when no session exists', () async {
      final bloc = AuthBloc(FakeAuthRepository())..add(const AuthStarted());
      await expectLater(bloc.stream, emits(const AuthUnauthenticated()));
    });

    test('restores straight to Authenticated with a persisted session', () async {
      final repo = FakeAuthRepository()..sessionUser = FakeAuthRepository.demoUser;
      final bloc = AuthBloc(repo)..add(const AuthStarted());
      await expectLater(bloc.stream, emits(const AuthAuthenticated(FakeAuthRepository.demoUser)));
    });

    test('happy path: phone → code sent (with dev code) → authenticated', () async {
      final repo = FakeAuthRepository();
      final bloc = AuthBloc(repo);

      bloc.add(const AuthOtpRequested('03001234567'));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          const AuthUnauthenticated(submitting: true),
          const AuthCodeSent(phone: '03001234567', devCode: '123456'),
        ]),
      );
      expect(repo.lastOtpPhone, '03001234567');

      bloc.add(const AuthOtpSubmitted('123456'));
      await expectLater(
        bloc.stream,
        emitsThrough(const AuthAuthenticated(FakeAuthRepository.demoUser)),
      );
    });

    test('wrong code surfaces the API error and stays on the code step', () async {
      final repo = FakeAuthRepository()..failVerify = true;
      final bloc = AuthBloc(repo);
      bloc.add(const AuthOtpRequested('03001234567'));
      await expectLater(bloc.stream, emitsThrough(isA<AuthCodeSent>()));

      bloc.add(const AuthOtpSubmitted('000000'));
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AuthCodeSent>()
              .having((s) => s.error, 'error', 'Invalid or expired code')
              .having((s) => s.submitting, 'submitting', false),
        ),
      );
    });

    test('logout clears the session', () async {
      final repo = FakeAuthRepository()..sessionUser = FakeAuthRepository.demoUser;
      final bloc = AuthBloc(repo)..add(const AuthStarted());
      await expectLater(bloc.stream, emitsThrough(isA<AuthAuthenticated>()));

      bloc.add(const AuthLogoutRequested());
      await expectLater(bloc.stream, emits(const AuthUnauthenticated()));
      expect(repo.sessionUser, isNull);
    });
  });
}
