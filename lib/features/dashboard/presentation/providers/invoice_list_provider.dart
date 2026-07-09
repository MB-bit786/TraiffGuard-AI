import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/features/invoice/domain/entities/invoice_entity.dart';
import 'package:hscode_auditor/core/util/auth_service.dart';
import 'package:hscode_auditor/features/invoice/domain/usecases/invoice_use_cases.dart';
import 'package:hscode_auditor/features/invoice/presentation/providers/invoice_providers.dart';
import 'package:hscode_auditor/core/util/auto_sync_service.dart';

final invoiceListProvider = StateNotifierProvider.autoDispose<InvoiceListNotifier, AsyncValue<List<InvoiceEntity>>>((ref) {
  final invoiceUseCases = ref.watch(invoiceUseCasesProvider);
  final syncService = ref.watch(autoSyncServiceProvider);
  final user = ref.watch(authStateProvider).value;
  final userId = user?.uid ?? 'anonymous';
  return InvoiceListNotifier(invoiceUseCases, syncService, userId);
});

class InvoiceListNotifier extends StateNotifier<AsyncValue<List<InvoiceEntity>>> {
  final InvoiceUseCases _invoiceUseCases;
  final AutoSyncService _syncService;
  final String _userId;

  InvoiceListNotifier(this._invoiceUseCases, this._syncService, this._userId) : super(const AsyncValue.loading()) {
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
    // CRITICAL UX FIX: Do NOT set state to loading. 
    // We want to keep showing local data while syncing in the background.
    try {
      // 1. PULL (Background): Get remote changes from Firestore. 
      await _invoiceUseCases.syncInvoices(_userId);
      
      // 2. REFRESH UI: Show the latest pulled data + local drafts instantly.
      final invoices = await _invoiceUseCases.getInvoices(_userId);
      state = AsyncValue.data(invoices);

      // 3. PUSH (Background): Start AI analysis for any local drafts.
      // Non-blocking trigger.
      _syncService.syncPendingAudits();
      
    } catch (e, st) {
      // If sync fails, we don't want to crash the UI, 
      // just ensure the current data is still visible.
      final currentData = state.value ?? [];
      if (currentData.isEmpty) {
        state = AsyncValue.error(e, st);
      }
    }
  }
}
