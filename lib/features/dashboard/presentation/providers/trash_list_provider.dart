import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../invoice/domain/entities/invoice_entity.dart';
import '../../../../core/util/auth_service.dart';
import '../../../invoice/domain/usecases/trash_use_cases.dart';
import 'invoice_list_provider.dart';

final trashUseCasesProvider = Provider<TrashUseCases>((ref) {
  final repository = ref.watch(invoiceRepositoryProvider);
  return TrashUseCases(repository);
});

final trashListProvider = StateNotifierProvider.autoDispose<TrashListNotifier, AsyncValue<List<InvoiceEntity>>>((ref) {
  final trashUseCases = ref.watch(trashUseCasesProvider);
  final user = ref.watch(authStateProvider).value;
  final userId = user?.uid ?? 'anonymous';
  
  return TrashListNotifier(trashUseCases, userId);
});

class TrashListNotifier extends StateNotifier<AsyncValue<List<InvoiceEntity>>> {
  final TrashUseCases _trashUseCases;
  final String _userId;

  TrashListNotifier(
    this._trashUseCases,
    this._userId,
  ) : super(const AsyncValue.loading()) {
    fetchTrashedInvoices();
  }

  Future<void> fetchTrashedInvoices() async {
    state = const AsyncValue.loading();
    try {
      final invoices = await _trashUseCases.getTrashedInvoices(_userId);
      state = AsyncValue.data(invoices);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => fetchTrashedInvoices();

  Future<void> restoreInvoice(String id) async {
    try {
      await _trashUseCases.restoreInvoice(_userId, id);
      await fetchTrashedInvoices();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> permanentlyDeleteInvoice(String id) async {
    try {
      await _trashUseCases.permanentlyDeleteInvoice(_userId, id);
      await fetchTrashedInvoices();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
