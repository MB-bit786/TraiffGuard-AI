import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/hs_audit_result_entity.dart';
import '../../domain/repository/audit_repository.dart';
import '../../data/repository/audit_repository_impl.dart';
import '../../domain/usecases/get_audit_detail_use_case.dart';
import 'package:hscode_auditor/features/invoice/data/repository/invoice_repository_impl.dart';
import '../../../dashboard/presentation/providers/invoice_list_provider.dart';

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  // We reuse the LocalDataSource from Invoice for now as they share the SQLite instance
  final invoiceRepo = ref.watch(invoiceRepositoryProvider) as InvoiceRepositoryImpl;
  return AuditRepositoryImpl(invoiceRepo.localDataSource);
});

final getAuditDetailUseCaseProvider = Provider<GetAuditDetailUseCase>((ref) {
  final repository = ref.watch(auditRepositoryProvider);
  return GetAuditDetailUseCase(repository);
});

final auditDetailProvider = FutureProvider.family.autoDispose<HsAuditResultEntity?, String>((ref, invoiceId) async {
  final useCase = ref.watch(getAuditDetailUseCaseProvider);
  return await useCase.execute(invoiceId);
});
