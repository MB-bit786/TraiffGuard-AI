import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../invoice/domain/entities/invoice_entity.dart';
import '../../../../core/util/auth_service.dart';
import '../../../invoice/domain/usecases/get_invoices_use_case.dart';
import '../../../invoice/domain/usecases/sync_invoices_use_case.dart';
import '../../../invoice/domain/repository/invoice_repository.dart';
import '../../../invoice/data/repository/invoice_repository_impl.dart';
import '../../../invoice/data/data_sources/invoice_local_data_source.dart';
import '../../../invoice/data/data_sources/invoice_remote_data_source.dart';
import '../../../../core/util/sql_database_service.dart';

// Strict Clean Architecture: Dependency Injection logic
final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepositoryImpl(
    localDataSource: InvoiceLocalDataSourceImpl(ref.watch(sqlDatabaseServiceProvider)),
    remoteDataSource: InvoiceRemoteDataSourceImpl(),
    dbService: ref.watch(sqlDatabaseServiceProvider),
  );
});

final getInvoicesUseCaseProvider = Provider<GetInvoicesUseCase>((ref) {
  return GetInvoicesUseCase(ref.watch(invoiceRepositoryProvider));
});

final syncInvoicesUseCaseProvider = Provider<SyncInvoicesUseCase>((ref) {
  return SyncInvoicesUseCase(ref.watch(invoiceRepositoryProvider), ref.watch(authServiceProvider));
});

final invoiceListProvider = StateNotifierProvider.autoDispose<InvoiceListNotifier, AsyncValue<List<InvoiceEntity>>>((ref) {
  final getInvoicesUseCase = ref.watch(getInvoicesUseCaseProvider);
  final syncInvoicesUseCase = ref.watch(syncInvoicesUseCaseProvider);
  final user = ref.watch(authStateProvider).value;
  final userId = user?.uid ?? 'anonymous';
  return InvoiceListNotifier(getInvoicesUseCase, syncInvoicesUseCase, userId);
});

class InvoiceListNotifier extends StateNotifier<AsyncValue<List<InvoiceEntity>>> {
  final GetInvoicesUseCase _getInvoicesUseCase;
  final SyncInvoicesUseCase _syncInvoicesUseCase;
  final String _userId;

  InvoiceListNotifier(this._getInvoicesUseCase, this._syncInvoicesUseCase, this._userId) : super(const AsyncValue.loading()) {
    fetchInvoices();
  }

  Future<void> fetchInvoices() async {
    state = const AsyncValue.loading();
    try {
      final invoices = await _getInvoicesUseCase.execute(_userId);
      state = AsyncValue.data(invoices);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> syncWithCloud() async {
    state = const AsyncValue.loading();
    try {
      await _syncInvoicesUseCase.execute(_userId);
      await fetchInvoices();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
