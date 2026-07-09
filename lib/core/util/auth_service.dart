import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/core/util/sql_database_service.dart';
import 'package:hscode_auditor/core/constants/db_constants.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/connection_provider.dart';
import '../../features/auth/domain/repository/auth_repository.dart';
import '../../features/auth/data/repository/firebase_auth_repository.dart';
import '../../features/auth/domain/usecases/auth_use_cases.dart';

class AuthService {
  final AuthRepository _repository;
  final SqlDatabaseService _dbService;
  final Ref _ref;

  AuthService(this._repository, this._dbService, this._ref);

  Stream<User?> get userChanges => _repository.userChanges;
  User? get currentUser => _repository.currentUser;

  Future<void> hydrateLocalDatabaseFromServer(String currentUid) async {
    // PRE-FLIGHT: Only attempt if we have a real internet handshake
    final isOnline = _ref.read(connectionProvider).effectivelyOnline;
    if (!isOnline) {
      debugPrint('[AUTH] Offline: Skipping Cloud-to-Local hydration.');
      return;
    }

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
          final String id = data['invoiceNumber'] ?? data['id'] ?? doc.id;

          // CRITICAL: Check if we have a newer local draft that hasn't synced yet.
          // If the local status is 'offlineDraft', we skip overwriting it with old server data.
          final List<Map<String, dynamic>> local = await txn.query(
            'invoices',
            where: '${DbConstants.colId} = ? AND ${DbConstants.colStatus} = ?',
            whereArgs: [id, 'offlineDraft'],
          );

          if (local.isNotEmpty) {
            debugPrint('[AUTH] Skipping hydration for local draft: $id');
            continue;
          }
          
          await txn.insert(
            'invoices',
            {
              DbConstants.colId: data['invoiceNumber'] ?? data['id'] ?? doc.id,
              DbConstants.colUserId: data['userId'] ?? currentUid,
              DbConstants.colConsignee: data['consignee'] ?? '',
              DbConstants.colCargoDescription: data['cargoDescription'] ?? '',
              DbConstants.colHsCode: data['hsCode'] ?? 'UNKNOWN',
              DbConstants.colHsDescription: data['hsDescription'] ?? '',
              DbConstants.colChapter: data['chapter'] ?? '',
              DbConstants.colStandardDutyRate: data['standardDutyRate'] ?? data['dutyRate'] ?? '0%',
              DbConstants.colVatRate: data['vatRate'] ?? '0%',
              DbConstants.colTotalTaxBurden: data['totalTaxBurden'] ?? '0%',
              DbConstants.colDeclaredValue: data['declaredValue']?.toString() ?? '0',
              DbConstants.colCurrency: data['currency'] ?? 'USD',
              DbConstants.colEstimatedDutyAmount: data['estimatedDutyAmount']?.toString() ?? '0',
              DbConstants.colConfidenceScore: data['confidenceScore'] ?? 0,
              DbConstants.colComplianceWarnings: data['complianceWarnings'] is List 
                  ? json.encode(data['complianceWarnings']) 
                  : (data['complianceWarnings'] ?? '[]'),
              DbConstants.colRequiredDocuments: data['requiredDocuments'] is List 
                  ? json.encode(data['requiredDocuments']) 
                  : (data['requiredDocuments'] ?? '[]'),
              DbConstants.colStatus: data['status'] ?? 'synced',
              DbConstants.colTimestamp: data['auditTimestamp'] ?? data['timestamp'] ?? DateTime.now().toString(),
              DbConstants.colRiskLevel: data['riskLevel'] ?? 'medium',
              DbConstants.colOriginCountry: data['originCountry'] ?? 'IN',
              DbConstants.colDestinationCountry: data['destinationCountry'] ?? 'US',
              DbConstants.colTotalWeightKg: data['totalWeightKg']?.toString() ?? '0',
              DbConstants.colPlannedMonth: data['plannedMonth'] ?? 'January',
              DbConstants.colShippingMethod: data['shippingMethod'] ?? 'Sea Freight',
              DbConstants.colIsDeleted: data['isDeleted'] ?? 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
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
    final cred = await _repository.signUp(email: email, password: password, fullName: fullName);
    if (cred?.user != null) {
      await _claimAnonymousData(cred!.user!.uid);
    }
    return cred;
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    final cred = await _repository.signIn(email, password);
    if (cred?.user != null) {
      final String uid = cred!.user!.uid;
      await _claimAnonymousData(uid);
      await hydrateLocalDatabaseFromServer(uid);
    }
    return cred;
  }

  Future<void> _claimAnonymousData(String targetUid) async {
    try {
      final db = await _dbService.database;
      final count = await db.update(
        'invoices',
        {DbConstants.colUserId: targetUid},
        where: '${DbConstants.colUserId} = ?',
        whereArgs: ['anonymous'],
      );
      if (count > 0) {
        debugPrint('[AUTH] Migrated $count anonymous records to UID: $targetUid');
      }
    } catch (e) {
      debugPrint('[AUTH] Failed to migrate anonymous data: $e');
    }
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
  return AuthService(repository, dbService, ref);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).userChanges;
});

final userAcceptedTermsProvider = FutureProvider.family<bool, String>((ref, uid) async {
  return await ref.watch(authRepositoryProvider).hasAcceptedTerms(uid);
});

final registrationInProgressProvider = StateProvider<bool>((ref) => false);
