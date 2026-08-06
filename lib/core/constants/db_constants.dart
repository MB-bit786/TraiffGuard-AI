/// Database Constants for high-fidelity schema management.
class DbConstants {
  static const String colId = 'id'; // Local ID (may match recordId or legacy invoiceNumber)
  static const String colInvoiceNumber = 'invoice_number'; // Link between manifest and audits
  static const String colRecordId = 'record_id'; // UUID for multi-device sync
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
  static const String colNationalExtensionCode = 'nationalExtensionCode';
  static const String colNationalExtensionDescription = 'nationalExtensionDescription';
  static const String colOriginPort = 'originPort';
  static const String colDestinationPort = 'destinationPort';
  static const String colPortCharges = 'portCharges';
  static const String colPromptVersion = 'promptVersion';
  static const String colVerificationStatus = 'verificationStatus';
  static const String colHsDescriptionOfficial = 'hsDescriptionOfficial';
  static const String colUpdatedAt = 'updated_at';
  static const String colSupersedesId = 'supersedes_id';
  static const String colIsHidden = 'is_hidden';

  // Static HS Codes table columns
  static const String colStaticHsCode = 'hs_code';
  static const String colDescription = 'description';
  static const String colNormalizedHsCode = 'normalized_code';
  
  // App Metadata table columns
  static const String colKey = 'key';
  static const String colValue = 'value';
  static const String colDatasetVersion = 'tariff_dataset_version';
}
