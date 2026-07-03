import 'package:firebase_auth/firebase_auth.dart';
import '../repository/auth_repository.dart';

class SignInUseCase {
  final AuthRepository repository;
  SignInUseCase(this.repository);

  Future<UserCredential?> execute(String email, String password) async {
    return await repository.signIn(email, password);
  }
}

class SignUpUseCase {
  final AuthRepository repository;
  SignUpUseCase(this.repository);

  Future<UserCredential?> execute({
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
}

class SignOutUseCase {
  final AuthRepository repository;
  SignOutUseCase(this.repository);

  Future<void> execute() async {
    return await repository.signOut();
  }
}

class CheckTermsAcceptanceUseCase {
  final AuthRepository repository;
  CheckTermsAcceptanceUseCase(this.repository);

  Future<bool> execute(String uid) async {
    return await repository.hasAcceptedTerms(uid);
  }
}

class AcceptTermsUseCase {
  final AuthRepository repository;
  AcceptTermsUseCase(this.repository);

  Future<void> execute(String uid) async {
    return await repository.acceptTerms(uid);
  }
}
