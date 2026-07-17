import '../entities/invoice_entity.dart';
import 'package:hscode_auditor/features/audit/domain/entities/hs_audit_result_entity.dart';

abstract class InvoiceRepository {
  Future<void> cacheInvoiceManifest(InvoiceEntity invoice, {HsAuditResultEntity? auditResult});
  
  Future<List<InvoiceEntity>> getAllInvoices(String userId);
  
  Future<List<HsAuditResultEntity>> getPendingDraftResults(String userId);
  
  Future<void> updateAuditSyncStatus(InvoiceEntity manifest, HsAuditResultEntity result);
  
  Future<List<InvoiceEntity>> getTrashedInvoices(String userId);
  
  Future<void> softDeleteInvoice(String id, String userId, bool delete);
  
  Future<void> hardDeleteInvoice(String id, String userId);
  
  Future<HsAuditResultEntity?> getAuditResultByInvoiceId(String id, String userId);
  
  Future<List<Map<String, dynamic>>> searchTariffMaster(String query);
}
