import 'package:hscode_auditor/core/util/sql_database_service.dart';
import '../../domain/repository/tariff_repository.dart';

class SqlTariffRepository implements TariffRepository {
  final SqlDatabaseService _dbService;
  SqlTariffRepository(this._dbService);

  @override
  Future<List<Map<String, dynamic>>> searchTariff(String query) async {
    final db = await _dbService.database;

    if (query.trim().isEmpty) {
      return await db.query('static_hs_codes', limit: 50);
    }

    final words = query.trim().toLowerCase().split(' ').where((w) => w.isNotEmpty).toList();
    String whereClause = words.map((_) => 'description LIKE ?').join(' AND ');
    List<String> args = words.map((word) => '%$word%').toList();

    if (words.length == 1) {
      whereClause = '(hs_code LIKE ? OR $whereClause)';
      args.insert(0, '${words[0]}%');
    }

    return await db.query(
      'static_hs_codes',
      where: whereClause,
      whereArgs: args,
      limit: 50,
    );
  }
}
