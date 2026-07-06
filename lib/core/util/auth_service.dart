import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/core/util/sql_database_service.dart';
import '../../features/auth/domain/repository/auth_repository.dart';
import '../../features/auth/data/repository/firebase_auth_repository.dart';

import '../../features/auth/domain/usecases/auth_use_cases.dart';

class AuthService {
  final AuthRepository _repository;
  final SqlDatabaseService _dbService;

  AuthService(this._repository, this._dbService);

  Stream<User?> get userChanges => _repository.userChanges;
  User? get currentUser => _repository.currentUser;

  Future<void> hydrateLocalDatabaseFromServer(String currentUid) async {
    try {
      debugPrint('[AUTH] Initiating Cloud-to-Local hydration for UID: $currentUid');
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('invoices')
          .get()
          .timeout(const Duration(seconds: 10));

      final db = await _dbService.database;
      await db.transaction((txn) async {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          await txn.insert('audit_results', data, conflictAlgorithm: ConflictAlgorithm.replace);
          await txn.insert('invoices', {
            'id': data['invoiceNumber'],
            'userId': data['userId'],
            'consignee': data['consignee'],
            'cargoDescription': data['cargoDescription'],
            'hsCode': data['hsCode'],
            'dutyRate': '${data['standardDutyRate']} Duty',
            'status': 'synced',
            'timestamp': data['auditTimestamp'],
            'isDeleted': data['isDeleted'] ?? 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
      debugPrint('[AUTH] Hydration complete: ${snapshot.docs.length} records restored.');
    } catch (e) {
      debugPrint('[AUTH] Hydration bypassed or failed: $e');
    }
  }

  Future<UserCredential?> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await _repository.signUp(email: email, password: password, fullName: fullName);
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    final cred = await _repository.signIn(email, password);
    if (cred?.user != null) {
      hydrateLocalDatabaseFromServer(cred!.user!.uid);
    }
    return cred;
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final authUseCasesProvider = Provider<AuthUseCases>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthUseCases(repository);
});

final authServiceProvider = Provider<AuthService>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final dbService = ref.watch(sqlDatabaseServiceProvider);
  return AuthService(repository, dbService);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).userChanges;
});

final userAcceptedTermsProvider = FutureProvider.family<bool, String>((ref, uid) async {
  return await ref.watch(authRepositoryProvider).hasAcceptedTerms(uid);
});

final registrationInProgressProvider = StateProvider<bool>((ref) => false);
