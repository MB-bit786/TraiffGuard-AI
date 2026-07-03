import 'dart:convert';
import '../../domain/entities/hs_audit_result_entity.dart';

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
    super.originCountry = 'IN',
    super.destinationCountry = 'US',
    super.totalWeightKg = '0',
    super.plannedMonth = 'January',
    super.shippingMethod = 'Sea Freight',
    super.isDeleted = false,
  });

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
      'originCountry': originCountry,
      'destinationCountry': destinationCountry,
      'totalWeightKg': totalWeightKg,
      'plannedMonth': plannedMonth,
      'shippingMethod': shippingMethod,
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  factory HsAuditResultModel.fromMap(Map<String, dynamic> map) {
    return HsAuditResultModel(
      hsCode: map['hsCode'] as String,
      userId: map['userId'] as String? ?? 'anonymous',
      hsDescription: map['hsDescription'] as String,
      chapter: map['chapter'] as String,
      consignee: map['consignee'] as String,
      invoiceNumber: map['invoiceNumber'] as String,
      cargoDescription: map['cargoDescription'] as String,
      standardDutyRate: map['standardDutyRate'] as String,
      vatRate: map['vatRate'] as String,
      totalTaxBurden: map['totalTaxBurden'] as String,
      declaredValue: map['declaredValue'] as String,
      currency: map['currency'] as String,
      estimatedDutyAmount: map['estimatedDutyAmount'] as String,
      confidenceScore: map['confidenceScore'] as int,
      complianceWarnings: List<String>.from(json.decode(map['complianceWarnings'] as String)),
      requiredDocuments: List<String>.from(json.decode(map['requiredDocuments'] as String)),
      auditTimestamp: map['auditTimestamp'] as String,
      riskLevel: parseRiskLevel(map['riskLevel'] as String),
      originCountry: map['originCountry'] as String? ?? 'IN',
      destinationCountry: map['destinationCountry'] as String? ?? 'US',
      totalWeightKg: map['totalWeightKg'] as String? ?? '0',
      plannedMonth: map['plannedMonth'] as String? ?? 'January',
      shippingMethod: map['shippingMethod'] as String? ?? 'Sea Freight',
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
    );
  }

  static RiskLevel parseRiskLevel(String value) {
    final lowerValue = value.toLowerCase().replaceAll('_', '');
    if (lowerValue == 'invalidinput') return RiskLevel.invalidInput;
    return RiskLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == lowerValue,
      orElse: () => RiskLevel.medium,
    );
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
    String? originCountry,
    String? destinationCountry,
    String? totalWeightKg,
    String? plannedMonth,
    String? shippingMethod,
    bool? isDeleted,
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
      originCountry: originCountry ?? this.originCountry,
      destinationCountry: destinationCountry ?? this.destinationCountry,
      totalWeightKg: totalWeightKg ?? this.totalWeightKg,
      plannedMonth: plannedMonth ?? this.plannedMonth,
      shippingMethod: shippingMethod ?? this.shippingMethod,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
