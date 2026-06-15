import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hscode_auditor/features/invoice/data/repositories/sql_invoice_repository.dart';
import 'package:hscode_auditor/core/services/gemini_audit_service.dart';
import 'package:hscode_auditor/features/audit/domain/models/hs_audit_result_model.dart';
import 'package:hscode_auditor/features/invoice/domain/models/invoice_model.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/invoice_list_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/connection_provider.dart';

/// Principal Systems Architect: Background synchronization service.
/// Automatically detects connectivity recovery and processes offline drafts via Gemini.
class AutoSyncService {
  final SqlInvoiceRepository _repository;
  final GeminiAuditService _geminiService;
  final Ref _ref;
  StreamSubscription? _connectivitySubscription;
  Timer? _heartbeatTimer;
  bool _isSyncing = false;

  AutoSyncService(this._repository, this._geminiService, this._ref) {
    _init();
  }

  Future<void> _init() async {
    debugPrint('[SYNC] Initializing background sync engine...');
    
    // 1. Initial Check: Sync immediately if we are already online on startup
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.isNotEmpty && !connectivity.contains(ConnectivityResult.none)) {
      debugPrint('[SYNC] Startup: Network detected. Triggering initial sync...');
      syncPendingAudits();
    }

    // 2. Hardware Connectivity Listener
    // Monitors physical network changes (e.g., leaving airplane mode)
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final bool isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (isOnline) {
        debugPrint('[SYNC] Hardware: Online shift detected. Checking drafts...');
        syncPendingAudits();
      }
    });

    // 3. Heartbeat Sync (Safety Net)
    // Runs every 60 seconds to process any missed transitions while the app is alive
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      final isOnline = _ref.read(connectionProvider).isOnline;
      if (isOnline) {
        debugPrint('[SYNC] Heartbeat: Checking for pending drafts...');
        syncPendingAudits();
      }
    });
  }

  /// Iterates through OFFLINE DRAFT records and upgrades them using Live AI.
  /// Parallelized using Future.wait for maximum throughput.
  Future<void> syncPendingAudits() async {
    if (_isSyncing) return;
    
    // Final pre-flight check: ensure we are effectively online
    final isOnline = _ref.read(connectionProvider).isOnline;
    if (!isOnline) return;

    _isSyncing = true;

    try {
      // 1. Query for pending drafts (Filtered by isDeleted = 0 to prevent ghost syncs)
      final List<HsAuditResultModel> pendingDrafts = (await _repository.getPendingDraftResults())
          .where((draft) => !draft.isDeleted).toList();
      
      if (pendingDrafts.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('[SYNC] Found ${pendingDrafts.length} drafts requiring AI verification.');
      int successCount = 0;

      // 2. Map drafts into processing Futures and execute concurrently
      final syncTasks = pendingDrafts.map((draft) async {
        try {
          debugPrint('[SYNC] Processing Audit: ${draft.invoiceNumber}...');

          final String jsonResponse = await _geminiService.fetchAiCustomsAudit(
            cargoDescription: draft.cargoDescription,
            hsCode: draft.hsCode.replaceAll(' (Offline Draft)', ''),
            originCountry: draft.originCountry,
            destinationCountry: draft.destinationCountry,
            declaredValue: double.tryParse(draft.declaredValue) ?? 0.0,
            currency: draft.currency,
          );
          
          final Map<String, dynamic> aiData = json.decode(jsonResponse);

          // 3. Construct the upgraded model with fixed confidence score logic
          final upgradedResult = HsAuditResultModel(
            hsCode: aiData['hsCode']?.toString() ?? draft.hsCode,
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
            estimatedDutyAmount: aiData['estimatedDutyAmount']?.toString() ?? draft.estimatedDutyAmount,
            // Confidence score: Model returns 1-100 integer as per prompt instructions.
            // Defensive check: If it returns a float < 1.0 (legacy or model error), normalize to 1-100.
            confidenceScore: (aiData['confidenceScore'] is num) 
                ? ((aiData['confidenceScore'] as num) < 1.0 
                    ? ((aiData['confidenceScore'] as num) * 100).toInt() 
                    : (aiData['confidenceScore'] as num).toInt())
                : 0,
            riskLevel: (aiData['confidenceScore'] is num && (aiData['confidenceScore'] as num) > 80)
                ? RiskLevel.low 
                : RiskLevel.medium,
            auditTimestamp: DateTime.now().toString().split('.').first,
            originCountry: draft.originCountry,
            destinationCountry: draft.destinationCountry,
            isDeleted: draft.isDeleted,
            complianceWarnings: List<String>.from(aiData['complianceWarnings'] ?? []),
            requiredDocuments: List<String>.from(aiData['requiredDocuments'] ?? []),
          );

          // 4. Update SQLite manifest and result tables
          final updatedManifest = InvoiceModel(
            id: draft.invoiceNumber,
            consignee: draft.consignee,
            cargoDescription: draft.cargoDescription,
            hsCode: upgradedResult.hsCode,
            dutyRate: '${upgradedResult.standardDutyRate} Duty',
            status: InvoiceSyncStatus.synced,
            timestamp: upgradedResult.auditTimestamp,
          );

          await _repository.updateAuditSyncStatus(updatedManifest, upgradedResult);
          successCount++;
          
          debugPrint('[SYNC] Successfully verified: ${draft.invoiceNumber}');
        } catch (e) {
          debugPrint('[SYNC] Error syncing single invoice ${draft.invoiceNumber}: $e');
        }
      }).toList();

      // Execute all tasks in parallel
      await Future.wait(syncTasks);

      if (successCount > 0) {
        // Refresh local state so Dashboard updates immediately
        _ref.read(invoiceListProvider.notifier).fetchInvoices();
        debugPrint('[SYNC] Concurrent update complete. $successCount records synchronized.');
      }

    } catch (e) {
      debugPrint('[SYNC] Critical error in parallel sync engine: $e');
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _heartbeatTimer?.cancel();
  }
}

/// Global provider for the Automated Sync Service
final autoSyncServiceProvider = Provider<AutoSyncService>((ref) {
  final repository = ref.watch(sqlInvoiceRepositoryProvider);
  final gemini = ref.watch(geminiAuditServiceProvider);
  final service = AutoSyncService(repository, gemini, ref);

  // Reactive Bridge: Connects our manual Connection Provider shifts to the Sync Service
  ref.listen(connectionProvider, (previous, next) {
    if (next.isOnline && (previous == null || !previous.isOnline)) {
      debugPrint('[SYNC] UI Override: Online detected. Triggering sync...');
      service.syncPendingAudits();
    }
  });

  return service;
});
