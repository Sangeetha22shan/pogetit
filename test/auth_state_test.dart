import 'package:flutter_test/flutter_test.dart';
import 'package:pogetit/features/authentication/model/auth_state.dart';

void main() {
  test('authentication starts in the loading state', () {
    const state = AuthState();

    expect(state.status, AuthStatus.loading);
    expect(state.user, isNull);
    expect(state.errorMessage, isNull);
  });
}
