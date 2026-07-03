import '../repository/tariff_repository.dart';

class SearchTariffUseCase {
  final TariffRepository repository;
  SearchTariffUseCase(this.repository);

  Future<List<Map<String, dynamic>>> execute(String query) async {
    return await repository.searchTariff(query);
  }
}
