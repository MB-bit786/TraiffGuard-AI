import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/hs_audit_result_model.dart';
import '../../../invoice/data/repositories/sql_invoice_repository.dart';

/// Provider to fetch a detailed Audit Result from the database by its invoice ID
final auditDetailProvider = FutureProvider.family.autoDispose<HsAuditResultModel?, String>((ref, invoiceId) async {
  final repository = ref.watch(sqlInvoiceRepositoryProvider);
  return await repository.getAuditResultByInvoiceId(invoiceId);
});
