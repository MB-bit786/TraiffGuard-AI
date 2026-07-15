import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repository/tariff_repository.dart';
import '../../data/repository/sql_tariff_repository.dart';
import '../../domain/usecases/search_tariff_use_case.dart';
import '../../../../core/services/sql_database_service.dart';

final tariffRepositoryProvider = Provider<TariffRepository>((ref) {
  final dbService = ref.watch(sqlDatabaseServiceProvider);
  return SqlTariffRepository(dbService);
});

final searchTariffUseCaseProvider = Provider<SearchTariffUseCase>((ref) {
  final repository = ref.watch(tariffRepositoryProvider);
  return SearchTariffUseCase(repository);
});

final tariffSearchProvider = StateNotifierProvider.autoDispose<TariffSearchNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final useCase = ref.watch(searchTariffUseCaseProvider);
  return TariffSearchNotifier(useCase);
});

class TariffSearchNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final SearchTariffUseCase _searchTariffUseCase;
  Timer? _debounceTimer;

  TariffSearchNotifier(this._searchTariffUseCase) : super(const AsyncValue.loading()) {
    updateQuery('');
  }

  void updateQuery(String query) {
    _debounceTimer?.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (mounted) state = const AsyncValue.loading();
      
      try {
        final results = await _searchTariffUseCase.execute(query);
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
