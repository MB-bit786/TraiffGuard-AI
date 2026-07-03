import '../entities/invoice_entity.dart';
import '../../../audit/domain/entities/hs_audit_result_entity.dart';

abstract class InvoiceRepository {
  Future<void> cacheInvoiceManifest(InvoiceEntity invoice, {HsAuditResultEntity? auditResult});
  
  Future<List<InvoiceEntity>> getAllInvoices(String userId);
  
  Future<List<HsAuditResultEntity>> getPendingDraftResults(String userId);
  
  Future<void> updateAuditSyncStatus(InvoiceEntity manifest, HsAuditResultEntity result);
  
  Future<List<InvoiceEntity>> getTrashedInvoices(String userId);
  
  Future<void> softDeleteInvoice(String id, bool delete);
  
  Future<void> hardDeleteInvoice(String id);
  
  Future<HsAuditResultEntity?> getAuditResultByInvoiceId(String id);
  
  Future<List<Map<String, dynamic>>> searchTariffMaster(String query);
}
