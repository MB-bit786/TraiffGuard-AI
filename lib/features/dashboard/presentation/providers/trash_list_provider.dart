import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../invoice/domain/models/invoice_model.dart';
import '../../../invoice/data/repositories/sql_invoice_repository.dart';

final trashListProvider = StateNotifierProvider.autoDispose<TrashListNotifier, AsyncValue<List<InvoiceModel>>>((ref) {
  final repository = ref.watch(sqlInvoiceRepositoryProvider);
  return TrashListNotifier(repository);
});

class TrashListNotifier extends StateNotifier<AsyncValue<List<InvoiceModel>>> {
  final SqlInvoiceRepository _repository;

  TrashListNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetchTrashedInvoices();
  }

  Future<void> fetchTrashedInvoices() async {
    state = const AsyncValue.loading();
    try {
      final invoices = await _repository.getTrashedInvoices();
      state = AsyncValue.data(invoices);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> restoreInvoice(String id) async {
    try {
      await _repository.softDeleteInvoice(id, false);
      await fetchTrashedInvoices();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> permanentlyDeleteInvoice(String id) async {
    try {
      await _repository.hardDeleteInvoice(id);
      await fetchTrashedInvoices();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
