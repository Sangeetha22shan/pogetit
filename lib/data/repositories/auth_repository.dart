import 'package:firebase_auth/firebase_auth.dart';

import '../../features/authentication/model/auth_user.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  AuthUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    return user == null ? null : AuthUser.fromFirebaseUser(user);
  }

  Stream<AuthUser?> get authStateChanges => _firebaseAuth
      .authStateChanges()
      .map((user) => user == null ? null : AuthUser.fromFirebaseUser(user));

  Future<AuthUser> ensureSignedInAnonymously() async {
    final existingUser = currentUser;
    if (existingUser != null) return existingUser;

    final credential = await _firebaseAuth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw StateError('Anonymous sign-in completed without a Firebase user.');
    }
    return AuthUser.fromFirebaseUser(user);
  }
}
