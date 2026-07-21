import 'package:hscode_auditor/core/services/sql_database_service.dart';
import 'package:hscode_auditor/features/search/domain/repository/tariff_repository.dart';

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

    // 1. Check if the query is a direct HS Code prefix (Allows numbers and dots)
    if (RegExp(r'^[0-9.]+$').hasMatch(trimmedQuery)) {
      return await db.query(
        'static_hs_codes',
        where: "hs_code LIKE ? OR REPLACE(hs_code, '.', '') LIKE ?",
        whereArgs: ['$trimmedQuery%', '${trimmedQuery.replaceAll('.', '')}%'],
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
    final List<String> scoreArgs = [];
    final List<String> whereArgs = [];

    // 1. Direct HS Code Scoring (Highest Priority)
    scoreParts.add("(CASE WHEN hs_code LIKE ? OR REPLACE(hs_code, '.', '') LIKE ? THEN 20 ELSE 0 END)");
    scoreArgs.add('$trimmedQuery%');
    scoreArgs.add('${trimmedQuery.replaceAll('.', '')}%');
    
    // 2. Full phrase match on description
    scoreParts.add("(CASE WHEN description LIKE ? THEN 10 ELSE 0 END)");
    scoreArgs.add('%$trimmedQuery%');
    
    scoreParts.add("(CASE WHEN description LIKE ? THEN 5 ELSE 0 END)");
    scoreArgs.add('$trimmedQuery%');

    // 3. Tokenized Search (Scoring AND Filtering)
    for (var word in words) {
      final cleanWord = word.replaceAll('.', '');
      
      // Score token matches on both columns
      scoreParts.add("(CASE WHEN description LIKE ? THEN 1 ELSE 0 END)");
      scoreArgs.add('%$word%');
      
      // High score for matching formatted or raw HS code
      scoreParts.add("(CASE WHEN hs_code LIKE ? OR REPLACE(hs_code, '.', '') LIKE ? THEN 8 ELSE 0 END)");
      scoreArgs.add('$word%');
      scoreArgs.add('$cleanWord%');
      
      // Filter requirement: word must exist in EITHER description OR hs_code (formatted or raw)
      whereParts.add("(description LIKE ? OR hs_code LIKE ? OR REPLACE(hs_code, '.', '') LIKE ?)");
      whereArgs.add('%$word%');
      whereArgs.add('$word%');
      whereArgs.add('$cleanWord%');
    }

    final String scoreExpression = scoreParts.join(' + ');
    final String whereClause = whereParts.join(' AND ');

    final List<String> allArgs = [...scoreArgs, ...whereArgs];

    return await db.rawQuery('''
      SELECT *, ($scoreExpression) as relevance
      FROM static_hs_codes
      WHERE $whereClause
      ORDER BY relevance DESC, hs_code ASC
      LIMIT 50
    ''', allArgs);
  }
}
