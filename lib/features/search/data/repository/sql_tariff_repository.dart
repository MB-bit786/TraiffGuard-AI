import 'package:hscode_auditor/core/services/sql_database_service.dart';
import '../../domain/repository/tariff_repository.dart';

class SqlTariffRepository implements TariffRepository {
  final SqlDatabaseService _dbService;
  SqlTariffRepository(this._dbService);

  @override
  Future<List<Map<String, dynamic>>> searchTariff(String query) async {
    final db = await _dbService.database;

    final trimmedQuery = query.trim().toLowerCase();
    if (trimmedQuery.isEmpty) {
      return await db.query('static_hs_codes', limit: 50);
    }

    // 1. Check if the query is a direct HS Code prefix
    if (RegExp(r'^\d+$').hasMatch(trimmedQuery)) {
      return await db.query(
        'static_hs_codes',
        where: 'hs_code LIKE ?',
        whereArgs: ['$trimmedQuery%'],
        limit: 50,
      );
    }

    // 2. Tokenize the query for ranked search
    final words = trimmedQuery.split(' ').where((w) => w.length > 2).toList();
    if (words.isEmpty) {
      // Fallback for short words
      words.add(trimmedQuery);
    }

    // 3. Build a scoring query
    // We give points for:
    // - Exact phrase match (+10)
    // - Individual word matches (+1 per word)
    // - Starting with the phrase (+5)
    
    final List<String> scoreParts = [];
    final List<String> whereParts = [];
    final List<String> args = [];

    // Full phrase match components
    scoreParts.add("(CASE WHEN description LIKE ? THEN 10 ELSE 0 END)");
    args.add('%$trimmedQuery%');
    
    scoreParts.add("(CASE WHEN description LIKE ? THEN 5 ELSE 0 END)");
    args.add('$trimmedQuery%');
    
    whereParts.add("description LIKE ?");
    args.add('%$trimmedQuery%');

    // Individual word components
    for (var word in words) {
      scoreParts.add("(CASE WHEN description LIKE ? THEN 1 ELSE 0 END)");
      args.add('%$word%');
      
      whereParts.add("description LIKE ?");
      args.add('%$word%');
    }

    final String scoreExpression = scoreParts.join(' + ');
    final String whereClause = whereParts.join(' OR ');

    // We use a rawQuery to handle the calculated 'relevance' column
    return await db.rawQuery('''
      SELECT *, ($scoreExpression) as relevance
      FROM static_hs_codes
      WHERE $whereClause
      ORDER BY relevance DESC, hs_code ASC
      LIMIT 50
    ''', args);
  }
}
