import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/core/constants/db_constants.dart';
import 'package:hscode_auditor/core/constants/app_constants.dart';

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
        version: 16,
        onCreate: _onCreate,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 10) await _migrateTo10(db);
          if (oldVersion < 11) await _migrateTo11(db);
          if (oldVersion < 12) await _migrateTo12(db);
          if (oldVersion < 13) await _migrateTo13(db);
          if (oldVersion < 14) await _migrateTo14(db);
          if (oldVersion < 15) await _migrateTo15(db);
          if (oldVersion < 16) await _migrateTo16(db);

          // Force re-seed if upgrading from a version without normalized codes
          if (oldVersion < 13 || oldVersion == 15) {
            await _seedTariffMaster(db);
          }
        },
      );
    } catch (e) {
      debugPrint('[DATABASE] ERROR during init: $e');
      rethrow;
    }
  }

  Future<void> _migrateTo10(Database db) async {
    debugPrint('[DATABASE] Upgrading schema to v10: Adding sync attempts...');
    try {
      await db.execute('ALTER TABLE invoices ADD COLUMN ${DbConstants.colSyncAttempts} INTEGER DEFAULT 0');
    } catch (e) {
      debugPrint('[DATABASE] Column colSyncAttempts might already exist: $e');
    }
  }

  Future<void> _migrateTo11(Database db) async {
    debugPrint('[DATABASE] Upgrading schema to v11: Adding national extensions and port surcharges...');
    try {
      await db.execute('ALTER TABLE invoices ADD COLUMN ${DbConstants.colNationalExtensionCode} TEXT');
      await db.execute('ALTER TABLE invoices ADD COLUMN ${DbConstants.colNationalExtensionDescription} TEXT');
      await db.execute('ALTER TABLE invoices ADD COLUMN ${DbConstants.colOriginPort} TEXT');
      await db.execute('ALTER TABLE invoices ADD COLUMN ${DbConstants.colDestinationPort} TEXT');
      await db.execute('ALTER TABLE invoices ADD COLUMN ${DbConstants.colPortCharges} TEXT');
    } catch (e) {
      debugPrint('[DATABASE] Error during v11 migration: $e');
    }
  }

  Future<void> _migrateTo12(Database db) async {
    debugPrint('[DATABASE] Upgrading schema to v12: Adding prompt versioning...');
    try {
      await db.execute('ALTER TABLE invoices ADD COLUMN ${DbConstants.colPromptVersion} INTEGER DEFAULT 0');
    } catch (e) {
      debugPrint('[DATABASE] Error during v12 migration: $e');
    }
  }

  Future<void> _migrateTo13(Database db) async {
    debugPrint('[DATABASE] Upgrading schema to v13: Adding normalized HS codes and metadata table...');
    try {
      await db.execute('ALTER TABLE static_hs_codes ADD COLUMN ${DbConstants.colNormalizedHsCode} TEXT');
      await db.execute('CREATE INDEX idx_normalized_hs ON static_hs_codes(${DbConstants.colNormalizedHsCode})');
      await db.execute('''
        CREATE TABLE metadata (
          ${DbConstants.colKey} TEXT PRIMARY KEY,
          ${DbConstants.colValue} TEXT
        )
      ''');
    } catch (e) {
      debugPrint('[DATABASE] Error during v13 migration: $e');
    }
  }

  Future<void> _migrateTo14(Database db) async {
    debugPrint('[DATABASE] Upgrading schema to v14: Adding verification status...');
    try {
      await db.execute('ALTER TABLE invoices ADD COLUMN ${DbConstants.colVerificationStatus} TEXT');
      await db.execute('ALTER TABLE invoices ADD COLUMN ${DbConstants.colHsDescriptionOfficial} TEXT');
    } catch (e) {
      debugPrint('[DATABASE] Error during v14 migration: $e');
    }
  }

  Future<void> _migrateTo15(Database db) async {
    debugPrint('[DATABASE] Upgrading schema to v15: Adding updated_at for conflict resolution...');
    try {
      await db.execute('ALTER TABLE invoices ADD COLUMN ${DbConstants.colUpdatedAt} TEXT');
    } catch (e) {
      debugPrint('[DATABASE] Error during v15 migration: $e');
    }
  }

  Future<void> _migrateTo16(Database db) async {
    debugPrint('[DATABASE] Upgrading schema to v16: Triggering forced re-seed for verification consistency.');
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[DATABASE] Creating schemas...');
    
    await _createInvoicesTable(db);

    await db.execute('''
      CREATE TABLE static_hs_codes (
        ${DbConstants.colStaticHsCode} TEXT PRIMARY KEY,
        ${DbConstants.colDescription} TEXT,
        ${DbConstants.colNormalizedHsCode} TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_normalized_hs ON static_hs_codes(${DbConstants.colNormalizedHsCode})');

    await db.execute('''
        CREATE TABLE metadata (
          ${DbConstants.colKey} TEXT PRIMARY KEY,
          ${DbConstants.colValue} TEXT
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
        ${DbConstants.colIsDeleted} INTEGER DEFAULT 0,
        ${DbConstants.colSyncAttempts} INTEGER DEFAULT 0,
        ${DbConstants.colNationalExtensionCode} TEXT,
        ${DbConstants.colNationalExtensionDescription} TEXT,
        ${DbConstants.colOriginPort} TEXT,
        ${DbConstants.colDestinationPort} TEXT,
        ${DbConstants.colPortCharges} TEXT,
        ${DbConstants.colPromptVersion} INTEGER DEFAULT 0,
        ${DbConstants.colVerificationStatus} TEXT,
        ${DbConstants.colHsDescriptionOfficial} TEXT,
        ${DbConstants.colUpdatedAt} TEXT
      )
    ''');
  }

  Future<void> _seedTariffMaster(Database db) async {
    try {
      // Robust check for metadata table
      final List<Map<String, dynamic>> tables = await db.query(
        'sqlite_master',
        where: 'type = ? AND name = ?',
        whereArgs: ['table', 'metadata'],
      );

      int currentVersion = 0;
      if (tables.isNotEmpty) {
        final List<Map<String, dynamic>> versionRows = await db.query(
          'metadata',
          where: '${DbConstants.colKey} = ?',
          whereArgs: [DbConstants.colDatasetVersion],
        );
        if (versionRows.isNotEmpty) {
          currentVersion = int.tryParse(versionRows.first[DbConstants.colValue].toString()) ?? 0;
        }
      }

      if (currentVersion >= AppConstants.kTariffDatasetVersion && tables.isNotEmpty) {
        debugPrint('[SEEDER] Data is current (v$currentVersion). Skipping seeding.');
        return;
      }

      debugPrint('[SEEDER] Ingesting Universal HS Codes JSON asset (v${AppConstants.kTariffDatasetVersion})...');
      final String jsonString = await rootBundle.loadString('assets/data/universal_hs_codes_6digit.json');
      final List<dynamic> data = await compute(_parseJsonIsolate, jsonString);
      
      await db.transaction((txn) async {
        await txn.delete('static_hs_codes');
        final batch = txn.batch();
        for (var item in data) {
          final String hsCode = item['hs_code'] ?? '';
          batch.insert(
            'static_hs_codes',
            {
              DbConstants.colStaticHsCode: hsCode,
              DbConstants.colDescription: item['description'] ?? '',
              DbConstants.colNormalizedHsCode: AppConstants.normalizeHsCode(hsCode),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        
        await txn.insert(
          'metadata',
          {
            DbConstants.colKey: DbConstants.colDatasetVersion,
            DbConstants.colValue: AppConstants.kTariffDatasetVersion.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
      
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
