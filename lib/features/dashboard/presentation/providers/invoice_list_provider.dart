import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../invoice/domain/models/invoice_model.dart';
import '../../../invoice/data/repositories/sql_invoice_repository.dart';

/// Provider that fetches and holds the list of all invoices stored in the local database.
final invoiceListProvider = StateNotifierProvider.autoDispose<InvoiceListNotifier, AsyncValue<List<InvoiceModel>>>((ref) {
  final repository = ref.watch(sqlInvoiceRepositoryProvider);
  return InvoiceListNotifier(repository);
});

class InvoiceListNotifier extends StateNotifier<AsyncValue<List<InvoiceModel>>> {
  final SqlInvoiceRepository _repository;

  InvoiceListNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetchInvoices();
  }

  /// Fetches all invoices from the database and updates the state.
  Future<void> fetchInvoices() async {
    state = const AsyncValue.loading();
    try {
      final invoices = await _repository.getAllInvoices();
      state = AsyncValue.data(invoices);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
