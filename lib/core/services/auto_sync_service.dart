import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/features/invoice/domain/repository/invoice_repository.dart';
import 'package:hscode_auditor/core/services/gemini_audit_service.dart';
import 'package:hscode_auditor/features/audit/domain/entities/hs_audit_result_entity.dart';
import 'package:hscode_auditor/features/audit/data/models/hs_audit_result_model.dart';
import 'package:hscode_auditor/features/invoice/domain/entities/invoice_entity.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/invoice_list_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/connection_provider.dart';
import 'package:hscode_auditor/features/auth/presentation/providers/auth_providers.dart';

/// Principal Background Service for cargo manifest synchronization.
/// Handles network state changes, heartbeats, and database reconciliation.
class AutoSyncService {
  final InvoiceRepository _repository;
  final GeminiAuditService _geminiService;
  final Ref _ref;
  Timer? _heartbeatTimer;
  bool _isSyncing = false;
  String? _activeUserId;

  AutoSyncService(this._repository, this._geminiService, this._ref);

  /// Initializes background listeners for connectivity and authentication states.
  void startListening() {
    debugPrint('[SYNC] Starting background synchronization listener...');
    _ref.listen(authStateProvider, (previous, next) {
      final user = next.value;
      if (user != null && user.uid != _activeUserId) {
        _activeUserId = user.uid;
        syncPendingAudits();
      } else if (user == null) {
        _activeUserId = null;
      }
    }, fireImmediately: true);

    // Initial sync check if already online
    if (_ref.read(connectionProvider).effectivelyOnline) {
      syncPendingAudits();
    }

    // High-reliability heartbeat for state recovery
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      final isOnline = _ref.read(connectionProvider).effectivelyOnline;
      if (isOnline) {
        syncPendingAudits();
      }
    });
  }

  /// Iterates through local 'offlineDraft' records and pushes them to AI for auditing.
  Future<void> syncPendingAudits() async {
    if (_isSyncing) return;
    
    final isOnline = _ref.read(connectionProvider).effectivelyOnline;
    if (!isOnline) return;
    
    final user = _ref.read(authUseCasesProvider).currentUser;
    if (user == null) return;
    
    final String userId = user.uid;
    _isSyncing = true;

    try {
      final List<HsAuditResultEntity> pendingDrafts = (await _repository.getPendingDraftResults(userId))
          .where((draft) => !draft.isDeleted).toList();

      if (pendingDrafts.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('[SYNC] Processing ${pendingDrafts.length} pending manifest(s)...');
      int successCount = 0;

      for (final draft in pendingDrafts) {
        // Pre-flight check: Is the data "proper" enough for AI?
        final String desc = draft.cargoDescription.trim().toLowerCase();
        final bool isConversational = desc.contains('?') || desc.contains('how are') || desc.startsWith('hi') || desc.startsWith('hello');
        
        if (draft.cargoDescription.length < 10 || isConversational) {
          debugPrint('[SYNC] Skipping record ${draft.invoiceNumber} due to improper data.');
          // Mark it as synced with a block risk level so it doesn't loop
          await _markAsInvalid(draft, userId);
          continue;
        }

        try {
          final String jsonResponse = await _geminiService.fetchAiCustomsAudit(
            cargoDescription: draft.cargoDescription,
            hsCode: draft.hsCode.replaceAll(' (Offline Draft)', ''),
            originCountry: draft.originCountry,
            destinationCountry: draft.destinationCountry,
            declaredValue: double.tryParse(draft.declaredValue) ?? 0.0,
            currency: draft.currency,
            totalWeightKg: draft.totalWeightKg,
            plannedMonth: draft.plannedMonth,
            shippingMethod: draft.shippingMethod,
            originPort: draft.originPort,
            destinationPort: draft.destinationPort,
          );

          final Map<String, dynamic> aiData = json.decode(jsonResponse);

          final upgradedResult = HsAuditResultEntity(
            hsCode: aiData['hsCode']?.toString() ?? draft.hsCode,
            userId: userId,
            hsDescription: aiData['hsDescription']?.toString() ?? draft.hsDescription,
            chapter: aiData['chapter']?.toString() ?? draft.chapter,
            consignee: draft.consignee,
            invoiceNumber: draft.invoiceNumber,
            cargoDescription: draft.cargoDescription,
            standardDutyRate: aiData['dutyRate']?.toString() ?? draft.standardDutyRate,
            vatRate: aiData['vatRate']?.toString() ?? draft.vatRate,
            totalTaxBurden: aiData['totalTaxBurden']?.toString() ?? draft.totalTaxBurden,
            declaredValue: draft.declaredValue,
            currency: draft.currency,
            estimatedDutyAmount: aiData['estimatedDutyAmount']?.toString()
                .replaceAll(draft.currency, '')
                .replaceAll(RegExp(r'[^0-9.]'), '')
                .trim() ?? draft.estimatedDutyAmount,
            confidenceScore: (aiData['confidenceScore'] is num)
                ? ((aiData['confidenceScore'] as num) < 1.0
                ? ((aiData['confidenceScore'] as num) * 100).toInt()
                : (aiData['confidenceScore'] as num).toInt())
                : 0,
            riskLevel: aiData['riskLevel'] != null
                ? _parseRiskLevel(aiData['riskLevel'].toString())
                : RiskLevel.medium,
            status: 'synced',
            auditTimestamp: DateTime.now().toString().split('.').first,
            originCountry: draft.originCountry,
            destinationCountry: draft.destinationCountry,
            totalWeightKg: draft.totalWeightKg,
            plannedMonth: draft.plannedMonth,
            shippingMethod: draft.shippingMethod,
            isDeleted: draft.isDeleted,
            complianceWarnings: List<String>.from(aiData['complianceWarnings'] ?? []),
            requiredDocuments: List<String>.from(aiData['requiredDocuments'] ?? []),
            nationalExtensionCode: aiData['nationalExtensionCode']?.toString() ?? '',
            nationalExtensionDescription: aiData['nationalExtensionDescription']?.toString() ?? '',
            originPort: aiData['originPort']?.toString() ?? draft.originPort,
            destinationPort: aiData['destinationPort']?.toString() ?? draft.destinationPort,
            portCharges: _parsePortCharges(aiData['portCharges']),
          );

          final updatedManifest = InvoiceEntity(
            id: draft.invoiceNumber,
            userId: userId,
            consignee: draft.consignee,
            cargoDescription: draft.cargoDescription,
            hsCode: upgradedResult.hsCode,
            dutyRate: '${upgradedResult.standardDutyRate} Duty',
            status: 'synced',
            timestamp: upgradedResult.auditTimestamp,
          );

          await _repository.updateAuditSyncStatus(updatedManifest, upgradedResult);
          successCount++;
          
          // Small delay to prevent API rate-limit saturation
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint('[SYNC] Record-level sync failure for ${draft.invoiceNumber}: $e');
          // Increment sync attempts to prevent infinite loops on specific bad records
          try {
            final incrementedAttempts = draft.syncAttempts + 1;
            // We update the record locally so getPendingDraftResults will eventually ignore it (> 5 attempts)
            final updatedDraft = (draft as HsAuditResultModel).copyWith(syncAttempts: incrementedAttempts);
            await _repository.cacheInvoiceManifest(
              InvoiceEntity(
                id: draft.invoiceNumber,
                userId: userId,
                consignee: draft.consignee,
                cargoDescription: draft.cargoDescription,
                hsCode: draft.hsCode,
                dutyRate: draft.standardDutyRate,
                status: draft.status,
                timestamp: draft.auditTimestamp,
                syncAttempts: incrementedAttempts,
              ),
              auditResult: updatedDraft,
            );
          } catch (updateError) {
            debugPrint('[SYNC] Failed to increment sync attempts: $updateError');
          }
        }
      }

      if (successCount > 0) {
        debugPrint('[SYNC] Successfully reconciled $successCount records.');
        _ref.read(invoiceListProvider.notifier).fetchInvoices();
      }
    } catch (e) {
      debugPrint('[SYNC] Critical pipeline error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  RiskLevel _parseRiskLevel(String value) {
    final lowerValue = value.toLowerCase().replaceAll('_', '');
    if (lowerValue == 'invalidinput') return RiskLevel.invalidInput;
    return RiskLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == lowerValue,
      orElse: () => RiskLevel.medium,
    );
  }

  Future<void> _markAsInvalid(HsAuditResultEntity draft, String userId) async {
    final upgradedResult = HsAuditResultEntity(
      hsCode: 'INVALID-INPUT',
      userId: userId,
      hsDescription: 'Security Block: Description was not a commercial item.',
      chapter: '00',
      consignee: draft.consignee,
      invoiceNumber: draft.invoiceNumber,
      cargoDescription: draft.cargoDescription,
      standardDutyRate: '0%',
      vatRate: '0%',
      totalTaxBurden: '0%',
      declaredValue: draft.declaredValue,
      currency: draft.currency,
      estimatedDutyAmount: '0',
      confidenceScore: 1, // Set to 1 so it's not 0 (Pending)
      riskLevel: RiskLevel.invalidInput,
      status: 'synced',
      auditTimestamp: DateTime.now().toString().split('.').first,
      originCountry: draft.originCountry,
      destinationCountry: draft.destinationCountry,
      totalWeightKg: draft.totalWeightKg,
      plannedMonth: draft.plannedMonth,
      shippingMethod: draft.shippingMethod,
      isDeleted: draft.isDeleted,
      complianceWarnings: ['ERROR: This record was blocked by the security layer due to improper input data.'],
      requiredDocuments: [],
    );

    final updatedManifest = InvoiceEntity(
      id: draft.invoiceNumber,
      userId: userId,
      consignee: draft.consignee,
      cargoDescription: draft.cargoDescription,
      hsCode: 'INVALID',
      dutyRate: 'Blocked',
      status: 'synced',
      timestamp: upgradedResult.auditTimestamp,
    );

    await _repository.updateAuditSyncStatus(updatedManifest, upgradedResult);
  }

  List<Map<String, String>> _parsePortCharges(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) {
      if (e is Map) {
        return e.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      return <String, String>{};
    }).where((m) => m.isNotEmpty).toList();
  }

  /// Terminates all background activity.
  void dispose() {
    _heartbeatTimer?.cancel();
  }
}
