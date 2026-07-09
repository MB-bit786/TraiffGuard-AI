import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hscode_auditor/features/invoice/domain/repository/invoice_repository.dart';
import 'package:hscode_auditor/core/util/gemini_audit_service.dart';
import 'package:hscode_auditor/features/audit/domain/entities/hs_audit_result_entity.dart';
import 'package:hscode_auditor/features/invoice/domain/entities/invoice_entity.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/invoice_list_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/connection_provider.dart';
import 'package:hscode_auditor/core/util/auth_service.dart';
import 'package:hscode_auditor/features/invoice/presentation/providers/invoice_providers.dart' as inv;

class AutoSyncService {
  final InvoiceRepository _repository;
  final GeminiAuditService _geminiService;
  final Ref _ref;
  StreamSubscription? _connectivitySubscription;
  Timer? _heartbeatTimer;
  bool _isSyncing = false;
  String? _activeUserId;

  AutoSyncService(this._repository, this._geminiService, this._ref) {
    _init();
  }

  Future<void> _init() async {
    _ref.listen(authStateProvider, (previous, next) {
      final user = next.value;
      if (user != null && user.uid != _activeUserId) {
        _activeUserId = user.uid;
        syncPendingAudits();
      } else if (user == null) {
        _activeUserId = null;
      }
    }, fireImmediately: true);

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.isNotEmpty && !connectivity.contains(ConnectivityResult.none)) {
      syncPendingAudits();
    }

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final bool isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (isOnline) {
        syncPendingAudits();
      }
    });

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      final isOnline = _ref.read(connectionProvider).effectivelyOnline;
      if (isOnline) {
        syncPendingAudits();
      }
    });
  }

  Future<void> syncPendingAudits() async {
    if (_isSyncing) return;
    final isOnline = _ref.read(connectionProvider).effectivelyOnline;
    if (!isOnline) return;
    final user = _ref.read(authServiceProvider).currentUser;
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

      int successCount = 0;
      for (final draft in pendingDrafts) {
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
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint('[SYNC] Sync failed for record: $e');
        }
      }

      if (successCount > 0) {
        _ref.read(invoiceListProvider.notifier).fetchInvoices();
      }
    } catch (e) {
      debugPrint('[SYNC] Global sync error: $e');
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

  void dispose() {
    _connectivitySubscription?.cancel();
    _heartbeatTimer?.cancel();
  }
}

final autoSyncServiceProvider = Provider<AutoSyncService>((ref) {
  final repository = ref.watch(inv.invoiceRepositoryProvider);
  final gemini = ref.watch(geminiAuditServiceProvider);
  final service = AutoSyncService(repository, gemini, ref);

  ref.listen(connectionProvider, (previous, next) {
    if (next.effectivelyOnline && (previous == null || !previous.effectivelyOnline)) {
      service.syncPendingAudits();
    }
  });

  return service;
});
