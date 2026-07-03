import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/hs_audit_result_entity.dart';
import '../../domain/repository/audit_repository.dart';
import '../../../invoice/data/data_sources/invoice_local_data_source.dart';

class AuditRepositoryImpl implements AuditRepository {
  final InvoiceLocalDataSource localDataSource;

  AuditRepositoryImpl(this.localDataSource);

  @override
  Future<HsAuditResultEntity?> getAuditById(String invoiceId) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    // Repositories coordinate Data Sources and return Entities
    return await localDataSource.getAuditResult(invoiceId, currentUid);
  }
}
