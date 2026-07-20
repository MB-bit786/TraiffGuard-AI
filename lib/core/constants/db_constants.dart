/// Database Constants for high-fidelity schema management.
class DbConstants {
  // Columns for consolidated Invoices table
  static const String colId = 'id';
  static const String colUserId = 'userId';
  static const String colConsignee = 'consignee';
  static const String colCargoDescription = 'cargoDescription';
  static const String colHsCode = 'hsCode';
  static const String colHsDescription = 'hsDescription';
  static const String colChapter = 'chapter';
  static const String colStandardDutyRate = 'standardDutyRate';
  static const String colVatRate = 'vatRate';
  static const String colTotalTaxBurden = 'totalTaxBurden';
  static const String colDeclaredValue = 'declaredValue';
  static const String colCurrency = 'currency';
  static const String colEstimatedDutyAmount = 'estimatedDutyAmount';
  static const String colConfidenceScore = 'confidenceScore';
  static const String colComplianceWarnings = 'complianceWarnings';
  static const String colRequiredDocuments = 'requiredDocuments';
  static const String colStatus = 'status';
  static const String colTimestamp = 'timestamp';
  static const String colRiskLevel = 'riskLevel';
  static const String colOriginCountry = 'originCountry';
  static const String colDestinationCountry = 'destinationCountry';
  static const String colTotalWeightKg = 'totalWeightKg';
  static const String colPlannedMonth = 'plannedMonth';
  static const String colShippingMethod = 'shippingMethod';
  static const String colIsDeleted = 'isDeleted';
  static const String colSyncAttempts = 'syncAttempts';

  // Static HS Codes table columns
  static const String colStaticHsCode = 'hs_code';
  static const String colDescription = 'description';
}
