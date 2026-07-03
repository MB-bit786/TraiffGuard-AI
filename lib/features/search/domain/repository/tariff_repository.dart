abstract class TariffRepository {
  Future<List<Map<String, dynamic>>> searchTariff(String query);
}
