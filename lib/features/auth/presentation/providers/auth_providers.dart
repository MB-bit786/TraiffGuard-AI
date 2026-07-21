import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/core/services/sql_database_service.dart';
import 'package:hscode_auditor/features/auth/domain/repository/auth_repository.dart';
import 'package:hscode_auditor/features/auth/data/repository/firebase_auth_repository.dart';
import 'package:hscode_auditor/features/auth/domain/usecases/auth_use_cases.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final authUseCasesProvider = Provider<AuthUseCases>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final dbService = ref.watch(sqlDatabaseServiceProvider);
  return AuthUseCases(repository, dbService, ref);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).userChanges;
});

final userAcceptedTermsProvider = FutureProvider.family<bool, String>((ref, uid) async {
  return await ref.watch(authRepositoryProvider).hasAcceptedTerms(uid);
});

final registrationInProgressProvider = StateProvider<bool>((ref) => false);
