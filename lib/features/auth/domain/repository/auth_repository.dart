import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Stream<User?> get userChanges;
  User? get currentUser;
  
  Future<UserCredential?> signIn(String email, String password);
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String fullName,
  });
  
  Future<void> signOut();
  Future<bool> hasAcceptedTerms(String uid);
  Future<void> acceptTerms(String uid);
}
