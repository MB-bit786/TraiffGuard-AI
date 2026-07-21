import 'dart:convert';
import 'package:hscode_auditor/features/audit/domain/entities/hs_audit_result_entity.dart';

class HsAuditResultModel extends HsAuditResultEntity {
  const HsAuditResultModel({
    required super.hsCode,
    required super.userId,
    required super.hsDescription,
    required super.chapter,
    required super.consignee,
    required super.invoiceNumber,
    required super.cargoDescription,
    required super.standardDutyRate,
    required super.vatRate,
    required super.totalTaxBurden,
    required super.declaredValue,
    required super.currency,
    required super.estimatedDutyAmount,
    required super.confidenceScore,
    required super.complianceWarnings,
    required super.requiredDocuments,
    required super.auditTimestamp,
    required super.riskLevel,
    required super.status,
    super.originCountry = 'IN',
    super.destinationCountry = 'US',
    super.totalWeightKg = '0',
    super.plannedMonth = 'January',
    super.shippingMethod = 'Sea Freight',
    super.isDeleted = false,
    super.syncAttempts = 0,
    super.nationalExtensionCode = '',
    super.nationalExtensionDescription = '',
    super.originPort = '',
    super.destinationPort = '',
    super.portCharges = const [],
  });

  /// Maps the object to a format suitable for local database persistence.
  Map<String, dynamic> toMap() {
    return {
      'hsCode': hsCode,
      'userId': userId,
      'hsDescription': hsDescription,
      'chapter': chapter,
      'consignee': consignee,
      'invoiceNumber': invoiceNumber,
      'cargoDescription': cargoDescription,
      'standardDutyRate': standardDutyRate,
      'vatRate': vatRate,
      'totalTaxBurden': totalTaxBurden,
      'declaredValue': declaredValue,
      'currency': currency,
      'estimatedDutyAmount': estimatedDutyAmount,
      'confidenceScore': confidenceScore,
      'complianceWarnings': json.encode(complianceWarnings),
      'requiredDocuments': json.encode(requiredDocuments),
      'auditTimestamp': auditTimestamp,
      'riskLevel': riskLevel.name,
      'status': status,
      'originCountry': originCountry,
      'destinationCountry': destinationCountry,
      'totalWeightKg': totalWeightKg,
      'plannedMonth': plannedMonth,
      'shippingMethod': shippingMethod,
      'isDeleted': isDeleted ? 1 : 0,
      'syncAttempts': syncAttempts,
      'nationalExtensionCode': nationalExtensionCode,
      'nationalExtensionDescription': nationalExtensionDescription,
      'originPort': originPort,
      'destinationPort': destinationPort,
      'portCharges': json.encode(portCharges),
    };
  }

  /// factory with defensive parsing to protect against malformed AI payloads or schema drift.
  factory HsAuditResultModel.fromMap(Map<String, dynamic> map) {
    return HsAuditResultModel(
      hsCode: _asString(map['hsCode']),
      userId: _asString(map['userId'], 'anonymous'),
      hsDescription: _asString(map['hsDescription']),
      chapter: _asString(map['chapter']),
      consignee: _asString(map['consignee']),
      invoiceNumber: _asString(map['invoiceNumber']),
      cargoDescription: _asString(map['cargoDescription']),
      standardDutyRate: _asString(map['standardDutyRate']),
      vatRate: _asString(map['vatRate']),
      totalTaxBurden: _asString(map['totalTaxBurden']),
      declaredValue: _asString(map['declaredValue'], '0.0'),
      currency: _asString(map['currency']),
      estimatedDutyAmount: _asString(map['estimatedDutyAmount']),
      confidenceScore: _asInt(map['confidenceScore'], 100), // Default high confidence for manually verified/trusted data
      complianceWarnings: _asStringList(map['complianceWarnings']),
      requiredDocuments: _asStringList(map['requiredDocuments']),
      auditTimestamp: _asString(map['auditTimestamp']),
      riskLevel: parseRiskLevel(map['riskLevel']),
      status: _asString(map['status'], 'synced'),
      originCountry: _asString(map['originCountry'], 'IN'),
      destinationCountry: _asString(map['destinationCountry'], 'US'),
      totalWeightKg: _asString(map['totalWeightKg'], '0'),
      plannedMonth: _asString(map['plannedMonth'], 'January'),
      shippingMethod: _asString(map['shippingMethod'], 'Sea Freight'),
      isDeleted: _asBoolFromInt(map['isDeleted']),
      syncAttempts: _asInt(map['syncAttempts'], 0),
      nationalExtensionCode: _asString(map['nationalExtensionCode']),
      nationalExtensionDescription: _asString(map['nationalExtensionDescription']),
      originPort: _asString(map['originPort']),
      destinationPort: _asString(map['destinationPort']),
      portCharges: _asPortChargesList(map['portCharges']),
    );
  }

  // --- PRIVATE DEFENSIVE PARSING HELPERS ---

  static String _asString(dynamic value, [String defaultValue = '']) {
    if (value == null) return defaultValue;
    return value.toString().trim();
  }

  static int _asInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? defaultValue;
    }
    return defaultValue;
  }

  static List<String> _asStringList(dynamic value) {
    if (value == null) return [];
    
    // 1. Handle JSON encoded string (common in SQFlite)
    if (value is String && value.startsWith('[')) {
      try {
        final decoded = json.decode(value);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {
        // Fall through to comma split if JSON fails
      }
    }

    // 2. Handle comma-separated string (LLM inaccuracy fallback)
    if (value is String) {
      if (value.isEmpty) return [];
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    // 3. Handle actual List
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }

    return [value.toString()];
  }

  static List<Map<String, String>> _asPortChargesList(dynamic value) {
    if (value == null) return [];
    
    // 1. Handle JSON encoded string (common in SQFlite)
    if (value is String && value.startsWith('[')) {
      try {
        final decoded = json.decode(value);
        if (decoded is List) {
          return decoded.map((e) {
            if (e is Map) {
              return e.map((k, v) => MapEntry(k.toString(), v.toString()));
            }
            return <String, String>{};
          }).where((m) => m.isNotEmpty).toList();
        }
      } catch (_) {}
    }

    // 2. Handle actual List from Firestore
    if (value is List) {
      return value.map((e) {
        if (e is Map) {
          return e.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
        return <String, String>{};
      }).where((m) => m.isNotEmpty).toList();
    }

    return [];
  }

  static RiskLevel parseRiskLevel(dynamic value) {
    final String val = _asString(value, 'low').toLowerCase().replaceAll('_', '');
    if (val == 'invalidinput') return RiskLevel.invalidInput;
    
    return RiskLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == val,
      orElse: () => RiskLevel.low, // Default to LOW as per requirement
    );
  }

  static bool _asBoolFromInt(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  HsAuditResultModel copyWith({
    String? hsCode,
    String? userId,
    String? hsDescription,
    String? chapter,
    String? consignee,
    String? invoiceNumber,
    String? cargoDescription,
    String? standardDutyRate,
    String? vatRate,
    String? totalTaxBurden,
    String? declaredValue,
    String? currency,
    String? estimatedDutyAmount,
    int? confidenceScore,
    List<String>? complianceWarnings,
    List<String>? requiredDocuments,
    String? auditTimestamp,
    RiskLevel? riskLevel,
    String? status,
    String? originCountry,
    String? destinationCountry,
    String? totalWeightKg,
    String? plannedMonth,
    String? shippingMethod,
    bool? isDeleted,
    int? syncAttempts,
    String? nationalExtensionCode,
    String? nationalExtensionDescription,
    String? originPort,
    String? destinationPort,
    List<Map<String, String>>? portCharges,
  }) {
    return HsAuditResultModel(
      hsCode: hsCode ?? this.hsCode,
      userId: userId ?? this.userId,
      hsDescription: hsDescription ?? this.hsDescription,
      chapter: chapter ?? this.chapter,
      consignee: consignee ?? this.consignee,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      cargoDescription: cargoDescription ?? this.cargoDescription,
      standardDutyRate: standardDutyRate ?? this.standardDutyRate,
      vatRate: vatRate ?? this.vatRate,
      totalTaxBurden: totalTaxBurden ?? this.totalTaxBurden,
      declaredValue: declaredValue ?? this.declaredValue,
      currency: currency ?? this.currency,
      estimatedDutyAmount: estimatedDutyAmount ?? this.estimatedDutyAmount,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      complianceWarnings: complianceWarnings ?? this.complianceWarnings,
      requiredDocuments: requiredDocuments ?? this.requiredDocuments,
      auditTimestamp: auditTimestamp ?? this.auditTimestamp,
      riskLevel: riskLevel ?? this.riskLevel,
      status: status ?? this.status,
      originCountry: originCountry ?? this.originCountry,
      destinationCountry: destinationCountry ?? this.destinationCountry,
      totalWeightKg: totalWeightKg ?? this.totalWeightKg,
      plannedMonth: plannedMonth ?? this.plannedMonth,
      shippingMethod: shippingMethod ?? this.shippingMethod,
      isDeleted: isDeleted ?? this.isDeleted,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      nationalExtensionCode: nationalExtensionCode ?? this.nationalExtensionCode,
      nationalExtensionDescription: nationalExtensionDescription ?? this.nationalExtensionDescription,
      originPort: originPort ?? this.originPort,
      destinationPort: destinationPort ?? this.destinationPort,
      portCharges: portCharges ?? this.portCharges,
    );
  }
}
