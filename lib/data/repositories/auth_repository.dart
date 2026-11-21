import 'package:firebase_auth/firebase_auth.dart';

import '../../features/authentication/model/auth_user.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  Stream<AuthUser?> get authStateChanges => _firebaseAuth
      .authStateChanges()
      .map((user) => user == null ? null : AuthUser.fromFirebaseUser(user));

  Future<void> signInAnonymously() async {
    await _firebaseAuth.signInAnonymously();
  }

  Future<void> signOut() => _firebaseAuth.signOut();
}
