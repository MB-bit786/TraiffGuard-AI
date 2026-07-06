import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        version: 8,
        onCreate: _onCreate,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            debugPrint('[DATABASE] Upgrading schema to v2...');
            await db.execute('DROP TABLE IF EXISTS static_hs_codes');
            await db.execute('CREATE TABLE static_hs_codes (hs_code TEXT PRIMARY KEY, description TEXT)');
            _seedTariffMaster(db);
          }
          if (oldVersion < 3) {
            debugPrint('[DATABASE] Upgrading schema to v3: Adding consignee to audit_results...');
            try {
              await db.execute('ALTER TABLE audit_results ADD COLUMN consignee TEXT');
            } catch (e) {
              debugPrint('[DATABASE] Migration warning (consignee): $e');
            }
          }
          if (oldVersion < 4) {
            debugPrint('[DATABASE] Upgrading schema to v4: Adding cargoDescription to audit_results...');
            try {
              await db.execute('ALTER TABLE audit_results ADD COLUMN cargoDescription TEXT');
            } catch (e) {
              debugPrint('[DATABASE] Migration warning (cargoDescription): $e');
            }
          }
          if (oldVersion < 5) {
            debugPrint('[DATABASE] Upgrading schema to v5: Adding isDeleted flag...');
            try {
              await db.execute('ALTER TABLE audit_results ADD COLUMN isDeleted INTEGER DEFAULT 0');
              await db.execute('ALTER TABLE invoices ADD COLUMN isDeleted INTEGER DEFAULT 0');
            } catch (e) {
              debugPrint('[DATABASE] Migration warning (isDeleted): $e');
            }
          }
          if (oldVersion < 6) {
            debugPrint('[DATABASE] Upgrading schema to v6: Adding country metrics for sync tracking...');
            try {
              await db.execute('ALTER TABLE audit_results ADD COLUMN originCountry TEXT DEFAULT "IN"');
              await db.execute('ALTER TABLE audit_results ADD COLUMN destinationCountry TEXT DEFAULT "US"');
            } catch (e) {
              debugPrint('[DATABASE] Migration warning (country fields): $e');
            }
          }
          if (oldVersion < 7) {
            debugPrint('[DATABASE] Upgrading schema to v7: Adding logistics metrics...');
            try {
              await db.execute('ALTER TABLE audit_results ADD COLUMN totalWeightKg TEXT DEFAULT "0"');
              await db.execute('ALTER TABLE audit_results ADD COLUMN plannedMonth TEXT DEFAULT "January"');
              await db.execute('ALTER TABLE audit_results ADD COLUMN shippingMethod TEXT DEFAULT "Sea Freight"');
            } catch (e) {
              debugPrint('[DATABASE] Migration warning (logistics fields): $e');
            }
          }
          if (oldVersion < 8) {
            debugPrint('[DATABASE] Upgrading schema to v8: Adding userId for data isolation...');
            try {
              await db.execute('ALTER TABLE audit_results ADD COLUMN userId TEXT DEFAULT "anonymous"');
              await db.execute('ALTER TABLE invoices ADD COLUMN userId TEXT DEFAULT "anonymous"');
            } catch (e) {
              debugPrint('[DATABASE] Migration warning (userId): $e');
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[DATABASE] ERROR during init: $e');
      rethrow;
    }
  }

  /// Shared schema creation logic
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[DATABASE] Creating schemas...');
    
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        consignee TEXT,
        cargoDescription TEXT,
        hsCode TEXT,
        dutyRate TEXT,
        status TEXT,
        timestamp TEXT,
        isDeleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_results (
        invoiceNumber TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        hsCode TEXT,
        hsDescription TEXT,
        chapter TEXT,
        consignee TEXT,
        cargoDescription TEXT,
        standardDutyRate TEXT,
        vatRate TEXT,
        totalTaxBurden TEXT,
        declaredValue TEXT,
        currency TEXT,
        estimatedDutyAmount TEXT,
        confidenceScore INTEGER,
        complianceWarnings TEXT,
        requiredDocuments TEXT,
        auditTimestamp TEXT,
        riskLevel TEXT,
        originCountry TEXT DEFAULT "IN",
        destinationCountry TEXT DEFAULT "US",
        totalWeightKg TEXT DEFAULT "0",
        plannedMonth TEXT DEFAULT "January",
        shippingMethod TEXT DEFAULT "Sea Freight",
        isDeleted INTEGER DEFAULT 0,
        FOREIGN KEY (invoiceNumber) REFERENCES invoices (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE static_hs_codes (
        hs_code TEXT PRIMARY KEY,
        description TEXT
      )
    ''');
    
    debugPrint('[DATABASE] Schemas created. Seeding in background...');
    _seedTariffMaster(db);
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
            'hs_code': item['hs_code'] ?? '',
            'description': item['description'] ?? '',
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
