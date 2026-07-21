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
    required this.status,
    this.originCountry = 'IN',
    this.destinationCountry = 'US',
    this.totalWeightKg = '0',
    this.plannedMonth = 'January',
    this.shippingMethod = 'Sea Freight',
    this.isDeleted = false,
    this.syncAttempts = 0,
    this.nationalExtensionCode = '',
    this.nationalExtensionDescription = '',
    this.originPort = '',
    this.destinationPort = '',
    this.portCharges = const [],
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
  final String status;
  final String originCountry;
  final String destinationCountry;
  final String totalWeightKg;
  final String plannedMonth;
  final String shippingMethod;
  final bool isDeleted;
  final int syncAttempts;
  final String nationalExtensionCode;
  final String nationalExtensionDescription;
  final String originPort;
  final String destinationPort;
  final List<Map<String, String>> portCharges;
}
