import 'package:hscode_auditor/features/audit/domain/entities/hs_audit_result_entity.dart';
import 'package:hscode_auditor/features/audit/domain/repository/audit_repository.dart';
import 'package:hscode_auditor/features/invoice/data/data_sources/invoice_local_data_source.dart';

class AuditRepositoryImpl implements AuditRepository {
  final InvoiceLocalDataSource localDataSource;

  AuditRepositoryImpl(this.localDataSource);

  @override
  Future<HsAuditResultEntity?> getAuditById(String invoiceId, String userId) async {
    return await localDataSource.getAuditResult(invoiceId, userId);
  }
}
