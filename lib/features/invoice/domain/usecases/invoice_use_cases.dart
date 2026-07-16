import 'dart:convert';
import '../entities/invoice_entity.dart';
import '../../../audit/domain/entities/hs_audit_result_entity.dart';
import '../repository/invoice_repository.dart';
import 'package:hscode_auditor/core/services/gemini_audit_service.dart';
import 'package:hscode_auditor/features/auth/domain/usecases/auth_use_cases.dart';

class AuditParams {
  final String invoiceNumber;
  final String consignee;
  final String cargoDescription;
  final String originCountry;
  final String destCountry;
  final double declaredValue;
  final String currency;
  final String totalWeightKg;
  final String plannedMonth;
  final String shippingMethod;
  final String? hsCode;
  final String userId;
  final bool effectivelyOnline;

  AuditParams({
    required this.invoiceNumber,
    required this.consignee,
    required this.cargoDescription,
    required this.originCountry,
    required this.destCountry,
    required this.declaredValue,
    required this.currency,
    required this.totalWeightKg,
    required this.plannedMonth,
    required this.shippingMethod,
    required this.userId,
    required this.effectivelyOnline,
    this.hsCode,
  });
}

class AuditResponse {
  final HsAuditResultEntity result;
  final String? error;

  AuditResponse({required this.result, this.error});
}

class InvoiceUseCases {
  final InvoiceRepository repository;
  final GeminiAuditService aiService;
  final AuthUseCases authService;

  InvoiceUseCases({
    required this.repository, 
    required this.aiService,
    required this.authService,
  });

  Future<List<InvoiceEntity>> getInvoices(String userId) async {
    return await repository.getAllInvoices(userId);
  }

  Future<void> syncInvoices(String userId) async {
    if (userId != 'anonymous') {
      await authService.hydrateLocalDatabaseFromServer(userId);
    }
  }

  Future<AuditResponse> processAudit(AuditParams params) async {
    final String timestamp = DateTime.now().toString().split('.').first;

    final double offlineRate = _calculateOfflineTariff(params.originCountry, params.destCountry);
    final double estimatedLocalDuty = params.declaredValue * offlineRate;

    final String activeHsCode = params.hsCode ?? 'PENDING';
    final String activeChapter = (activeHsCode != 'PENDING' && activeHsCode.length >= 2)
        ? 'Chapter ${activeHsCode.substring(0, 2)}'
        : '00';

    final offlineAuditResult = HsAuditResultEntity(
      hsCode: params.hsCode != null ? '${params.hsCode} (Offline Draft)' : 'PENDING (Offline Draft)',
      userId: params.userId,
      hsDescription: 'Local corridor-based estimation (Track B Fallback)',
      chapter: activeChapter,
      consignee: params.consignee,
      invoiceNumber: params.invoiceNumber,
      cargoDescription: params.cargoDescription,
      standardDutyRate: '${(offlineRate * 100).toStringAsFixed(1)}%',
      vatRate: 'TBD',
      totalTaxBurden: '${(offlineRate * 100).toStringAsFixed(1)}% (Est)',
      declaredValue: params.declaredValue.toString(),
      currency: params.currency,
      estimatedDutyAmount: estimatedLocalDuty.toStringAsFixed(2),
      confidenceScore: 0,
      riskLevel: RiskLevel.medium,
      status: 'offlineDraft',
      auditTimestamp: timestamp,
      originCountry: params.originCountry,
      destinationCountry: params.destCountry,
      totalWeightKg: params.totalWeightKg,
      plannedMonth: params.plannedMonth,
      shippingMethod: params.shippingMethod,
      isDeleted: false,
      complianceWarnings: [
        '⚠️ OFFLINE DRAFT: Live AI tier is currently under high demand.',
        '⚠️ Local trade matrix applied: ${params.originCountry}_TO_${params.destCountry} corridor.',
      ],
      requiredDocuments: ['Commercial Invoice', 'Packing List', 'Certificate of Origin'],
    );

    final baselineManifest = InvoiceEntity(
      id: params.invoiceNumber,
      userId: params.userId,
      consignee: params.consignee,
      cargoDescription: params.cargoDescription,
      hsCode: offlineAuditResult.hsCode,
      dutyRate: '${offlineAuditResult.standardDutyRate} (Est)',
      status: 'offlineDraft',
      timestamp: timestamp,
    );

    if (!params.effectivelyOnline) {
      await repository.cacheInvoiceManifest(baselineManifest, auditResult: offlineAuditResult);
      return AuditResponse(result: offlineAuditResult);
    }

    try {
      final String jsonResponse = await aiService.fetchAiCustomsAudit(
        cargoDescription: params.cargoDescription,
        hsCode: params.hsCode ?? "AUTO-SELECT",
        originCountry: params.originCountry,
        destinationCountry: params.destCountry,
        declaredValue: params.declaredValue,
        currency: params.currency,
        totalWeightKg: params.totalWeightKg,
        plannedMonth: params.plannedMonth,
        shippingMethod: params.shippingMethod,
      );

      final Map<String, dynamic> aiData = json.decode(jsonResponse);

      final auditReport = HsAuditResultEntity(
        hsCode: aiData['hsCode']?.toString() ?? 'UNKNOWN',
        userId: params.userId,
        hsDescription: aiData['hsDescription']?.toString() ?? 'Description not available',
        chapter: aiData['chapter']?.toString() ?? 'WCO Classification Chapter',
        consignee: params.consignee,
        invoiceNumber: params.invoiceNumber,
        cargoDescription: params.cargoDescription,
        standardDutyRate: aiData['dutyRate']?.toString() ?? 'N/A',
        vatRate: aiData['vatRate']?.toString() ?? 'TBD',
        totalTaxBurden: aiData['totalTaxBurden']?.toString() ?? 'TBD',
        declaredValue: params.declaredValue.toString(),
        currency: params.currency,
        estimatedDutyAmount: aiData['estimatedDutyAmount']?.toString()
                .replaceAll(params.currency, '')
                .replaceAll(RegExp(r'[^0-9.]'), '')
                .trim() ?? 'TBD',
        confidenceScore: (aiData['confidenceScore'] is num)
            ? ((aiData['confidenceScore'] as num) < 1.0
                ? ((aiData['confidenceScore'] as num) * 100).toInt()
                : (aiData['confidenceScore'] as num).toInt())
            : 0,
        riskLevel: aiData['riskLevel'] != null
            ? _parseRiskLevel(aiData['riskLevel'].toString())
            : (aiData['confidenceScore'] is num && ((aiData['confidenceScore'] as num) > 80 || (aiData['confidenceScore'] as num) > 0.8))
                ? RiskLevel.low
                : RiskLevel.medium,
        status: 'synced',
        auditTimestamp: timestamp,
        originCountry: params.originCountry,
        destinationCountry: params.destCountry,
        totalWeightKg: params.totalWeightKg,
        plannedMonth: params.plannedMonth,
        shippingMethod: params.shippingMethod,
        complianceWarnings: List<String>.from(aiData['complianceWarnings'] ?? []),
        requiredDocuments: List<String>.from(aiData['requiredDocuments'] ?? []),
      );

      final syncedManifest = InvoiceEntity(
        id: baselineManifest.id,
        userId: baselineManifest.userId,
        consignee: baselineManifest.consignee,
        cargoDescription: baselineManifest.cargoDescription,
        hsCode: auditReport.hsCode,
        dutyRate: '${auditReport.standardDutyRate} Duty',
        status: 'synced',
        timestamp: auditReport.auditTimestamp,
      );

      await repository.cacheInvoiceManifest(syncedManifest, auditResult: auditReport);

      return AuditResponse(result: auditReport);
    } catch (e) {
      await repository.cacheInvoiceManifest(baselineManifest, auditResult: offlineAuditResult);
      return AuditResponse(
        result: offlineAuditResult,
        error: 'AI is currently overloaded. Document saved as high-fidelity local draft.',
      );
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

  double _calculateOfflineTariff(String origin, String destination) {
    final corridorKey = '${origin.trim().toUpperCase()}_TO_${destination.trim().toUpperCase()}';
    const matrix = {
      'IN_TO_US': 0.12,
      'CN_TO_US': 0.25,
      'MX_TO_US': 0.05,
      'VN_TO_US': 0.15,
      'DE_TO_US': 0.08,
      'DE_TO_IN': 0.18,
    };
    return matrix[corridorKey] ?? 0.10;
  }
}
