import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/db_constants.dart';
import '../../../../core/services/sql_database_service.dart';
import '../../../dashboard/presentation/providers/connection_provider.dart';
import '../repository/auth_repository.dart';

/// Unified Authentication Engine
/// Consolidates domain use cases and technical service logic (Sync/Hydration) into a single pipeline.
class AuthUseCases {
  final AuthRepository _repository;
  final SqlDatabaseService _dbService;
  final Ref _ref;

  AuthUseCases(this._repository, this._dbService, this._ref);

  Stream<User?> get userChanges => _repository.userChanges;
  User? get currentUser => _repository.currentUser;

  Future<UserCredential?> signIn(String email, String password) async {
    final cred = await _repository.signIn(email, password);
    if (cred?.user != null) {
      await hydrateLocalDatabaseFromServer(cred!.user!.uid);
    }
    return cred;
  }

  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await _repository.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  Future<bool> checkTermsAcceptance(String uid) async {
    return await _repository.hasAcceptedTerms(uid);
  }

  Future<void> acceptTerms(String uid) async {
    await _repository.acceptTerms(uid);
  }

  /// Cloud-to-Local Synchronization Bridge
  /// Pulls historical records from Firestore and populates the local vault while respecting pending local drafts.
  Future<void> hydrateLocalDatabaseFromServer(String currentUid) async {
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

          // CRITICAL: Prevent overwriting newer local drafts that haven't synced yet.
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
              DbConstants.colId: id,
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
}
