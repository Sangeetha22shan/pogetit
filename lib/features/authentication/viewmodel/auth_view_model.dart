import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../model/auth_state.dart';
import '../model/auth_user.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository) {
    _subscription = _repository.authStateChanges.listen(
      _handleAuthChange,
      onError: _handleError,
    );
  }

  final AuthRepository _repository;
  late final StreamSubscription _subscription;
  AuthState _state = const AuthState();
  bool _disposed = false;
  bool _initializationStarted = false;

  AuthState get state => _state;

  Future<void> initialize() async {
    if (_initializationStarted) return;
    _initializationStarted = true;
    try {
      final user = await _repository.ensureSignedInAnonymously();
      _handleAuthChange(user);
    } catch (error) {
      _setState(
        AuthState(status: AuthStatus.error, errorMessage: error.toString()),
      );
    }
  }

  void _handleAuthChange(AuthUser? user) {
    _setState(
      AuthState(
        status: user == null
            ? AuthStatus.unauthenticated
            : AuthStatus.authenticated,
        user: user,
      ),
    );
  }

  void _handleError(Object error) {
    _setState(
      AuthState(status: AuthStatus.error, errorMessage: error.toString()),
    );
  }

  void _setState(AuthState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    super.dispose();
  }
}
