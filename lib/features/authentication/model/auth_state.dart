import 'auth_user.dart';

enum AuthStatus { loading, authenticated, unauthenticated, error }

class AuthState {
  const AuthState({
    this.status = AuthStatus.loading,
    this.user,
    this.errorMessage,
  });

  final AuthStatus status;
  final AuthUser? user;
  final String? errorMessage;
}
