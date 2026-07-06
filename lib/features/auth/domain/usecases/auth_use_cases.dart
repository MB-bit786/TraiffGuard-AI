import 'package:firebase_auth/firebase_auth.dart';
import '../repository/auth_repository.dart';

class AuthUseCases {
  final AuthRepository repository;
  AuthUseCases(this.repository);

  Future<UserCredential?> signIn(String email, String password) async {
    return await repository.signIn(email, password);
  }

  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await repository.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );
  }

  Future<void> signOut() async {
    return await repository.signOut();
  }

  Future<bool> checkTermsAcceptance(String uid) async {
    return await repository.hasAcceptedTerms(uid);
  }

  Future<void> acceptTerms(String uid) async {
    return await repository.acceptTerms(uid);
  }
}
