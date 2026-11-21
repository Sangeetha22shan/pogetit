import 'package:firebase_auth/firebase_auth.dart';

class AuthUser {
  const AuthUser({required this.id, this.email});

  factory AuthUser.fromFirebaseUser(User user) {
    return AuthUser(id: user.uid, email: user.email);
  }

  final String id;
  final String? email;
}
