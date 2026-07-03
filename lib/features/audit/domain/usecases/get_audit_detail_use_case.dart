import '../entities/hs_audit_result_entity.dart';
import '../repository/audit_repository.dart';

class GetAuditDetailUseCase {
  final AuditRepository repository;
  GetAuditDetailUseCase(this.repository);

  Future<HsAuditResultEntity?> execute(String invoiceId) async {
    return await repository.getAuditById(invoiceId);
  }
}
