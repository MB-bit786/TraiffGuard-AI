import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../invoice/domain/entities/invoice_entity.dart';
import '../../../../core/util/auth_service.dart';
import '../../../invoice/domain/usecases/trash_use_cases.dart';
import '../providers/invoice_list_provider.dart';

final getTrashedInvoicesUseCaseProvider = Provider<GetTrashedInvoicesUseCase>((ref) {
  final repository = ref.watch(invoiceRepositoryProvider);
  return GetTrashedInvoicesUseCase(repository);
});

final restoreInvoiceUseCaseProvider = Provider<RestoreInvoiceUseCase>((ref) {
  final repository = ref.watch(invoiceRepositoryProvider);
  return RestoreInvoiceUseCase(repository);
});

final permanentlyDeleteInvoiceUseCaseProvider = Provider<PermanentlyDeleteInvoiceUseCase>((ref) {
  final repository = ref.watch(invoiceRepositoryProvider);
  return PermanentlyDeleteInvoiceUseCase(repository);
});

final trashListProvider = StateNotifierProvider.autoDispose<TrashListNotifier, AsyncValue<List<InvoiceEntity>>>((ref) {
  final getTrashedUseCase = ref.watch(getTrashedInvoicesUseCaseProvider);
  final restoreUseCase = ref.watch(restoreInvoiceUseCaseProvider);
  final permanentDeleteUseCase = ref.watch(permanentlyDeleteInvoiceUseCaseProvider);
  final user = ref.watch(authStateProvider).value;
  final userId = user?.uid ?? 'anonymous';
  
  return TrashListNotifier(getTrashedUseCase, restoreUseCase, permanentDeleteUseCase, userId);
});

class TrashListNotifier extends StateNotifier<AsyncValue<List<InvoiceEntity>>> {
  final GetTrashedInvoicesUseCase _getTrashedUseCase;
  final RestoreInvoiceUseCase _restoreUseCase;
  final PermanentlyDeleteInvoiceUseCase _permanentDeleteUseCase;
  final String _userId;

  TrashListNotifier(
    this._getTrashedUseCase,
    this._restoreUseCase,
    this._permanentDeleteUseCase,
    this._userId,
  ) : super(const AsyncValue.loading()) {
    fetchTrashedInvoices();
  }

  Future<void> fetchTrashedInvoices() async {
    state = const AsyncValue.loading();
    try {
      final invoices = await _getTrashedUseCase.execute(_userId);
      state = AsyncValue.data(invoices);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => fetchTrashedInvoices();

  Future<void> restoreInvoice(String id) async {
    try {
      await _restoreUseCase.execute(_userId, id);
      await fetchTrashedInvoices();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> permanentlyDeleteInvoice(String id) async {
    try {
      await _permanentDeleteUseCase.execute(_userId, id);
      await fetchTrashedInvoices();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
