import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../invoice/data/repositories/sql_invoice_repository.dart';

/// Provider to handle real-time searching of the local Tariff Master database
final tariffSearchProvider = StateNotifierProvider.autoDispose<TariffSearchNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final repository = ref.watch(sqlInvoiceRepositoryProvider);
  return TariffSearchNotifier(repository);
});

class TariffSearchNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final SqlInvoiceRepository _repository;
  Timer? _debounceTimer;

  TariffSearchNotifier(this._repository) : super(const AsyncValue.loading()) {
    // Initial fetch to show "All" data
    updateQuery('');
  }

  /// Updates the search query and fetches matching results from the local database.
  /// Includes a 300ms debounce to prevent rapid typing from locking the UI thread.
  void updateQuery(String query) {
    _debounceTimer?.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (mounted) state = const AsyncValue.loading();
      
      try {
        final results = await _repository.searchTariffMaster(query);
        if (mounted) {
          state = AsyncValue.data(results);
        }
      } catch (e, stackTrace) {
        if (mounted) {
          state = AsyncValue.error(e, stackTrace);
        }
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
