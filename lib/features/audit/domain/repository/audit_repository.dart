import 'package:hscode_auditor/features/audit/domain/entities/hs_audit_result_entity.dart';

abstract class AuditRepository {
  Future<HsAuditResultEntity?> getAuditById(String invoiceId, String userId);
}
