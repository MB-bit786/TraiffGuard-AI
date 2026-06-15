import 'package:flutter/foundation.dart';
import 'dart:convert';

enum RiskLevel { low, medium, high }

@immutable
class HsAuditResultModel {
  const HsAuditResultModel({
    required this.hsCode,
    required this.hsDescription,
    required this.chapter,
    required this.consignee,
    required this.invoiceNumber,
    required this.cargoDescription,
    required this.standardDutyRate,
    required this.vatRate,
    required this.totalTaxBurden,
    required this.declaredValue,
    required this.currency,
    required this.estimatedDutyAmount,
    required this.confidenceScore,
    required this.complianceWarnings,
    required this.requiredDocuments,
    required this.auditTimestamp,
    required this.riskLevel,
    this.originCountry = 'IN',
    this.destinationCountry = 'US',
    this.isDeleted = false,
  });

  final String hsCode;
  final String hsDescription;
  final String chapter;
  final String consignee;
  final String invoiceNumber;
  final String cargoDescription;
  final String standardDutyRate;
  final String vatRate;
  final String totalTaxBurden;
  final String declaredValue;
  final String currency;
  final String estimatedDutyAmount;
  final int confidenceScore;
  final List<String> complianceWarnings;
  final List<String> requiredDocuments;
  final String auditTimestamp;
  final RiskLevel riskLevel;
  final String originCountry;
  final String destinationCountry;
  final bool isDeleted;

  Map<String, dynamic> toMap() {
    return {
      'hsCode': hsCode,
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
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  factory HsAuditResultModel.fromMap(Map<String, dynamic> map) {
    return HsAuditResultModel(
      hsCode: map['hsCode'] as String,
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
      riskLevel: RiskLevel.values.byName(map['riskLevel'] as String),
      originCountry: map['originCountry'] as String? ?? 'IN',
      destinationCountry: map['destinationCountry'] as String? ?? 'US',
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
    );
  }
}
