import 'package:flutter/foundation.dart';

enum RiskLevel { low, medium, high, invalidInput }

@immutable
class HsAuditResultEntity {
  const HsAuditResultEntity({
    required this.hsCode,
    required this.userId,
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
    this.totalWeightKg = '0',
    this.plannedMonth = 'January',
    this.shippingMethod = 'Sea Freight',
    this.isDeleted = false,
  });

  final String hsCode;
  final String userId;
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
  final String totalWeightKg;
  final String plannedMonth;
  final String shippingMethod;
  final bool isDeleted;
}
