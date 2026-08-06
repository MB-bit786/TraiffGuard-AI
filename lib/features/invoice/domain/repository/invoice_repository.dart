import 'package:hscode_auditor/features/invoice/domain/entities/invoice_entity.dart';
import 'package:hscode_auditor/features/audit/domain/entities/hs_audit_result_entity.dart';

class TariffLookup {
  final Map<String, dynamic>? row;
  final VerificationStatus status;
  const TariffLookup(this.row, this.status);
}

abstract class InvoiceRepository {
  Future<void> cacheInvoiceManifest(InvoiceEntity invoice, {HsAuditResultEntity? auditResult});
  
  Future<List<InvoiceEntity>> getAllInvoices(String userId);

  Stream<List<InvoiceEntity>> watchInvoices(String userId);
  
  Future<List<HsAuditResultEntity>> getPendingDraftResults(String userId);
  
  Future<void> updateAuditSyncStatus(InvoiceEntity manifest, HsAuditResultEntity result);
  
  Future<List<InvoiceEntity>> getTrashedInvoices(String userId);
  
  Future<void> softDeleteInvoice(String id, String userId, bool delete);
  
  Future<void> hardDeleteInvoice(String id, String userId);
  
  Future<HsAuditResultEntity?> getAuditResultByInvoiceId(String id, String userId);

  Future<List<HsAuditResultEntity>> getAuditHistory(String invoiceNumber, String userId);

  Future<void> hideAuditRecord(String recordId, String userId);

  Future<void> cacheAuditRecord(HsAuditResultEntity result);
  
  Future<List<Map<String, dynamic>>> searchTariffMaster(String query);

  Future<TariffLookup> findTariffByCode(String rawCode);

  /// Manually triggers a broadcast of the invoice list for the given user.
  void notifyChanges(String userId);
}
