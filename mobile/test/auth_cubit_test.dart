import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:field_notes_test/features/authentication/auth_cubit.dart';
import 'package:field_notes_test/features/authentication/auth_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late AuthCubit authCubit;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    authCubit = AuthCubit(authRepository: mockAuthRepository);
  });

  tearDown(() {
    authCubit.close();
  });

  group('AuthCubit', () {
    test('initial state is AuthInitial', () {
      expect(authCubit.state, equals(AuthInitial()));
      expect(authCubit.currentUserId, isNull);
      expect(authCubit.currentEmail, isNull);
    });

    group('checkAuth', () {
      test('emits [AuthLoading, AuthAuthenticated] when logged in', () async {
        when(() => mockAuthRepository.isLoggedIn()).thenAnswer((_) async => true);
        when(() => mockAuthRepository.getUserId()).thenAnswer((_) async => 'user-123');
        when(() => mockAuthRepository.getUserEmail()).thenAnswer((_) async => 'test@example.com');

        final expectedStates = [
          AuthLoading(),
          const AuthAuthenticated(userId: 'user-123', email: 'test@example.com'),
        ];

        expectLater(authCubit.stream, emitsInOrder(expectedStates));

        await authCubit.checkAuth();
        expect(authCubit.currentUserId, equals('user-123'));
        expect(authCubit.currentEmail, equals('test@example.com'));
      });

      test('emits [AuthLoading, AuthUnauthenticated] when not logged in', () async {
        when(() => mockAuthRepository.isLoggedIn()).thenAnswer((_) async => false);

        final expectedStates = [
          AuthLoading(),
          AuthUnauthenticated(),
        ];

        expectLater(authCubit.stream, emitsInOrder(expectedStates));

        await authCubit.checkAuth();
        expect(authCubit.currentUserId, isNull);
      });

      test('emits [AuthLoading, AuthUnauthenticated] on repository exception', () async {
        when(() => mockAuthRepository.isLoggedIn()).thenThrow(Exception('Storage error'));

        final expectedStates = [
          AuthLoading(),
          AuthUnauthenticated(),
        ];

        expectLater(authCubit.stream, emitsInOrder(expectedStates));

        await authCubit.checkAuth();
      });
    });

    group('login', () {
      test('emits [AuthLoading, AuthAuthenticated] on success', () async {
        when(() => mockAuthRepository.login('admin@example.com', 'password123'))
            .thenAnswer((_) async => {'userId': 'admin-1', 'email': 'admin@example.com'});

        final expectedStates = [
          AuthLoading(),
          const AuthAuthenticated(userId: 'admin-1', email: 'admin@example.com'),
        ];

        expectLater(authCubit.stream, emitsInOrder(expectedStates));

        await authCubit.login('admin@example.com', 'password123');
      });

      test('emits [AuthLoading, AuthError, AuthUnauthenticated] on failure', () async {
        when(() => mockAuthRepository.login(any(), any()))
            .thenThrow(Exception('Invalid credentials'));

        final expectedStates = [
          AuthLoading(),
          const AuthError('Exception: Invalid credentials'),
          AuthUnauthenticated(),
        ];

        expectLater(authCubit.stream, emitsInOrder(expectedStates));

        await authCubit.login('wrong@example.com', 'wrongpass');
      });
    });

    group('register', () {
      test('emits [AuthLoading, AuthAuthenticated] on registration and auto-login success', () async {
        when(() => mockAuthRepository.register('new@example.com', 'secret123'))
            .thenAnswer((_) async {});
        when(() => mockAuthRepository.login('new@example.com', 'secret123'))
            .thenAnswer((_) async => {'userId': 'user-new', 'email': 'new@example.com'});

        final expectedStates = [
          AuthLoading(),
          const AuthAuthenticated(userId: 'user-new', email: 'new@example.com'),
        ];

        expectLater(authCubit.stream, emitsInOrder(expectedStates));

        await authCubit.register('new@example.com', 'secret123');
      });

      test('emits [AuthLoading, AuthError, AuthUnauthenticated] on registration failure', () async {
        when(() => mockAuthRepository.register(any(), any()))
            .thenThrow(Exception('Email already in use'));

        final expectedStates = [
          AuthLoading(),
          const AuthError('Exception: Email already in use'),
          AuthUnauthenticated(),
        ];

        expectLater(authCubit.stream, emitsInOrder(expectedStates));

        await authCubit.register('existing@example.com', 'pass123');
      });
    });

    group('logout', () {
      test('emits [AuthLoading, AuthUnauthenticated]', () async {
        when(() => mockAuthRepository.logout()).thenAnswer((_) async {});

        final expectedStates = [
          AuthLoading(),
          AuthUnauthenticated(),
        ];

        expectLater(authCubit.stream, emitsInOrder(expectedStates));

        await authCubit.logout();
      });
    });
  });
}

