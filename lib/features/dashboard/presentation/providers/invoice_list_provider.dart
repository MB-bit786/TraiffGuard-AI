import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/features/invoice/domain/entities/invoice_entity.dart';
import 'package:hscode_auditor/core/util/auth_service.dart';
import 'package:hscode_auditor/features/invoice/domain/usecases/invoice_use_cases.dart';
import 'package:hscode_auditor/features/invoice/presentation/providers/invoice_providers.dart';

final invoiceListProvider = StateNotifierProvider.autoDispose<InvoiceListNotifier, AsyncValue<List<InvoiceEntity>>>((ref) {
  final invoiceUseCases = ref.watch(invoiceUseCasesProvider);
  final user = ref.watch(authStateProvider).value;
  final userId = user?.uid ?? 'anonymous';
  return InvoiceListNotifier(invoiceUseCases, userId);
});

class InvoiceListNotifier extends StateNotifier<AsyncValue<List<InvoiceEntity>>> {
  final InvoiceUseCases _invoiceUseCases;
  final String _userId;

  InvoiceListNotifier(this._invoiceUseCases, this._userId) : super(const AsyncValue.loading()) {
    fetchInvoices();
  }

  Future<void> fetchInvoices() async {
    state = const AsyncValue.loading();
    try {
      final invoices = await _invoiceUseCases.getInvoices(_userId);
      state = AsyncValue.data(invoices);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> syncWithCloud() async {
    state = const AsyncValue.loading();
    try {
      await _invoiceUseCases.syncInvoices(_userId);
      await fetchInvoices();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
