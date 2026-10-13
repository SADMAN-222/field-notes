import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'auth_repository.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository authRepository;

  AuthCubit({required this.authRepository}) : super(AuthInitial());

  String? get currentUserId {
    final s = state;
    if (s is AuthAuthenticated) return s.userId;
    return null;
  }

  String? get currentEmail {
    final s = state;
    if (s is AuthAuthenticated) return s.email;
    return null;
  }

  Future<void> checkAuth() async {
    emit(AuthLoading());
    try {
      final isLoggedIn = await authRepository.isLoggedIn();
      if (isLoggedIn) {
        final userId = await authRepository.getUserId() ?? '';
        final email = await authRepository.getUserEmail() ?? '';
        emit(AuthAuthenticated(userId: userId, email: email));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (error) {
      emit(AuthError(error.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.login(email, password);
      emit(
        AuthAuthenticated(
          userId: user['userId'] ?? '',
          email: user['email'] ?? email,
        ),
      );
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> register(String email, String password) async {
    emit(AuthLoading());
    try {
      await authRepository.register(email, password);
      final user = await authRepository.login(email, password);
      emit(
        AuthAuthenticated(
          userId: user['userId'] ?? '',
          email: user['email'] ?? email,
        ),
      );
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> logout() async {
    emit(AuthLoading());
    try {
      await authRepository.logout();
      emit(AuthUnauthenticated());
    } catch (error) {
      emit(AuthError(error.toString()));
      emit(AuthUnauthenticated());
    }
  }
}
