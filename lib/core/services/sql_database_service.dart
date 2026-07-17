import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/core/constants/db_constants.dart';

/// Standard Mobile SQL Service using native sqflite.
class SqlDatabaseService {
  Database? _database;

  /// Singleton access to the database.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    debugPrint('[DATABASE] Starting initialization...');
    
    try {
      final String path = p.join(await getDatabasesPath(), 'tariff_guard.db');

      return await openDatabase(
        path,
        version: 9,
        onCreate: _onCreate,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 9) {
            debugPrint('[DATABASE] Upgrading schema to v9: Consolidating tables...');
            // In a production app, we would perform a data migration here.
            // For development, we drop and recreate to ensure schema integrity.
            await db.execute('DROP TABLE IF EXISTS audit_results');
            await db.execute('DROP TABLE IF EXISTS invoices');
            await _createInvoicesTable(db);
          }
        },
      );
    } catch (e) {
      debugPrint('[DATABASE] ERROR during init: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[DATABASE] Creating schemas...');
    
    await _createInvoicesTable(db);

    await db.execute('''
      CREATE TABLE static_hs_codes (
        ${DbConstants.colStaticHsCode} TEXT PRIMARY KEY,
        ${DbConstants.colDescription} TEXT
      )
    ''');
    
    debugPrint('[DATABASE] Schemas created. Seeding in background...');
    _seedTariffMaster(db);
  }

  Future<void> _createInvoicesTable(Database db) async {
    await db.execute('''
      CREATE TABLE invoices (
        ${DbConstants.colId} TEXT PRIMARY KEY,
        ${DbConstants.colUserId} TEXT NOT NULL,
        ${DbConstants.colConsignee} TEXT,
        ${DbConstants.colCargoDescription} TEXT,
        ${DbConstants.colHsCode} TEXT,
        ${DbConstants.colHsDescription} TEXT,
        ${DbConstants.colChapter} TEXT,
        ${DbConstants.colStandardDutyRate} TEXT,
        ${DbConstants.colVatRate} TEXT,
        ${DbConstants.colTotalTaxBurden} TEXT,
        ${DbConstants.colDeclaredValue} TEXT,
        ${DbConstants.colCurrency} TEXT,
        ${DbConstants.colEstimatedDutyAmount} TEXT,
        ${DbConstants.colConfidenceScore} INTEGER,
        ${DbConstants.colComplianceWarnings} TEXT,
        ${DbConstants.colRequiredDocuments} TEXT,
        ${DbConstants.colStatus} TEXT,
        ${DbConstants.colTimestamp} TEXT,
        ${DbConstants.colRiskLevel} TEXT,
        ${DbConstants.colOriginCountry} TEXT DEFAULT "IN",
        ${DbConstants.colDestinationCountry} TEXT DEFAULT "US",
        ${DbConstants.colTotalWeightKg} TEXT DEFAULT "0",
        ${DbConstants.colPlannedMonth} TEXT DEFAULT "January",
        ${DbConstants.colShippingMethod} TEXT DEFAULT "Sea Freight",
        ${DbConstants.colIsDeleted} INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _seedTariffMaster(Database db) async {
    try {
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM static_hs_codes')) ?? 0;
      if (count > 0) {
        debugPrint('[SEEDER] Data already present ($count records). Skipping seeding.');
        return;
      }

      debugPrint('[SEEDER] Ingesting Universal HS Codes JSON asset...');
      final String jsonString = await rootBundle.loadString('assets/data/universal_hs_codes_6digit.json');
      final List<dynamic> data = await compute(_parseJsonIsolate, jsonString);
      
      final batch = db.batch();
      for (var item in data) {
        batch.insert(
        'static_hs_codes',
        {
            DbConstants.colStaticHsCode: item['hs_code'] ?? '',
            DbConstants.colDescription: item['description'] ?? '',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit(noResult: true);
      debugPrint('[SEEDER] Universal Database seeding successful.');
    } catch (e) {
      debugPrint('[SEEDER] ERROR: $e');
    }
  }
}

List<dynamic> _parseJsonIsolate(String jsonString) {
  return jsonDecode(jsonString) as List<dynamic>;
}

final sqlDatabaseServiceProvider = Provider<SqlDatabaseService>((ref) {
  return SqlDatabaseService();
});
