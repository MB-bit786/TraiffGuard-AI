import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/features/invoice/domain/repository/invoice_repository.dart';
import 'package:hscode_auditor/features/invoice/data/repository/invoice_repository_impl.dart';
import 'package:hscode_auditor/features/invoice/data/data_sources/invoice_local_data_source.dart';
import 'package:hscode_auditor/features/invoice/data/data_sources/invoice_remote_data_source.dart';
import 'package:hscode_auditor/core/services/sql_database_service.dart';
import 'package:hscode_auditor/features/invoice/domain/usecases/invoice_use_cases.dart';
import 'package:hscode_auditor/core/services/gemini_audit_service.dart';
import 'package:hscode_auditor/core/services/auth_service.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepositoryImpl(
    localDataSource: InvoiceLocalDataSourceImpl(ref.watch(sqlDatabaseServiceProvider)),
    remoteDataSource: InvoiceRemoteDataSourceImpl(),
    dbService: ref.watch(sqlDatabaseServiceProvider),
  );
});

final invoiceUseCasesProvider = Provider<InvoiceUseCases>((ref) {
  final repository = ref.watch(invoiceRepositoryProvider);
  final aiService = ref.watch(geminiAuditServiceProvider);
  final authService = ref.watch(authServiceProvider);
  return InvoiceUseCases(
    repository: repository,
    aiService: aiService,
    authService: authService,
  );
});
