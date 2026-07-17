import 'package:hscode_auditor/features/audit/domain/entities/hs_audit_result_entity.dart';
import '../repository/audit_repository.dart';

class GetAuditDetailUseCase {
  final AuditRepository repository;
  GetAuditDetailUseCase(this.repository);

  Future<HsAuditResultEntity?> execute(String invoiceId, String userId) async {
    return await repository.getAuditById(invoiceId, userId);
  }
}
