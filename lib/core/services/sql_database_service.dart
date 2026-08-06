import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
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
        version: 18,
        onCreate: _onCreate,
        onUpgrade: (db, oldVersion, newVersion) async {
          // Schema versions 1-9 predate first distribution and are not supported.
          // Any database below v10 is rebuilt from scratch.
          if (oldVersion < 10) {
            await _rebuildFromScratch(db);
            return;
          }

          if (oldVersion < 11) await _migrateTo11(db);
          if (oldVersion < 12) await _migrateTo12(db);
          if (oldVersion < 13) await _migrateTo13(db);
          if (oldVersion < 14) await _migrateTo14(db);
          if (oldVersion < 15) await _migrateTo15(db);
          if (oldVersion < 16) await _migrateTo16(db);
          if (oldVersion < 17) await _migrateTo17(db);
          if (oldVersion < 18) await _migrateTo18(db);

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

  Future<void> _safeAddColumn(Database db, String table, String column, String type) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    } catch (e) {
      if (e.toString().toLowerCase().contains('duplicate column')) {
        return; // already applied — fine
      }
      rethrow; // anything else is a real structural failure
    }
  }

  Future<void> _rebuildFromScratch(Database db) async {
    debugPrint('[DATABASE] Versions 1-9 are deprecated. Rebuilding from scratch...');
    await db.execute('DROP TABLE IF EXISTS invoices');
    await db.execute('DROP TABLE IF EXISTS static_hs_codes');
    await db.execute('DROP TABLE IF EXISTS metadata');
    await _onCreate(db, 16);
  }

  Future<void> _migrateTo11(Database db) async {
    debugPrint('[DATABASE] Upgrading schema to v11: Adding national extensions and port surcharges...');
    await _safeAddColumn(db, 'invoices', DbConstants.colNationalExtensionCode, 'TEXT');
    await _safeAddColumn(db, 'invoices', DbConstants.colNationalExtensionDescription, 'TEXT');
    await _safeAddColumn(db, 'invoices', DbConstants.colOriginPort, 'TEXT');
    await _safeAddColumn(db, 'invoices', DbConstants.colDestinationPort, 'TEXT');
    await _safeAddColumn(db, 'invoices', DbConstants.colPortCharges, 'TEXT');
  }

  Future<void> _migrateTo12(Database db) async {
    debugPrint('[DATABASE] Upgrading schema to v12: Adding prompt versioning...');
    await _safeAddColumn(db, 'invoices', DbConstants.colPromptVersion, 'INTEGER DEFAULT 0');
  }

  Future<void> _migrateTo13(Database db) async {
    debugPrint('[DATABASE] Upgrading schema to v13: Adding normalized HS codes and metadata table...');
    try {
      await db.execute('ALTER TABLE static_hs_codes ADD COLUMN ${DbConstants.colNormalizedHsCode} TEXT');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_normalized_hs ON static_hs_codes(${DbConstants.colNormalizedHsCode})');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS metadata (
          ${DbConstants.colKey} TEXT PRIMARY KEY,
          ${DbConstants.colValue} TEXT
        )
      ''');
    } catch (e) {
      if (e.toString().toLowerCase().contains('duplicate column')) return;
      rethrow;
    }
  }

  Future<void> _migrateTo14(Database db) async {
    debugPrint('[DATABASE] Upgrading schema to v14: Adding verification status...');
    await _safeAddColumn(db, 'invoices', DbConstants.colVerificationStatus, 'TEXT');
    await _safeAddColumn(db, 'invoices', DbConstants.colHsDescriptionOfficial, 'TEXT');
  }

  Future<void> _migrateTo15(Database db) async {
    debugPrint('[DATABASE] Upgrading schema to v15: Adding updated_at for conflict resolution...');
    await _safeAddColumn(db, 'invoices', DbConstants.colUpdatedAt, 'TEXT');
  }

  Future<void> _migrateTo16(Database db) async {
    debugPrint('[DATABASE] Upgrading schema to v16: Triggering forced re-seed for verification consistency.');
  }

  Future<void> _migrateTo17(Database db) async {
    debugPrint('[DATABASE] Upgrading schema to v17: Adding UUIDs and immutable audit trail columns...');
    await _safeAddColumn(db, 'invoices', 'record_id', 'TEXT');
    await _safeAddColumn(db, 'invoices', DbConstants.colSupersedesId, 'TEXT');
    await _safeAddColumn(db, 'invoices', DbConstants.colIsHidden, 'INTEGER DEFAULT 0');

    // Backfill record_id for existing records
    final List<Map<String, dynamic>> records = await db.query('invoices', columns: [DbConstants.colId]);
    final batch = db.batch();
    for (final row in records) {
      final String id = row[DbConstants.colId] as String;
      batch.update(
        'invoices',
        {'record_id': DateTime.now().millisecondsSinceEpoch.toString() + id.hashCode.toString()}, // Quick deterministic ID for backfill
        where: '${DbConstants.colId} = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _migrateTo18(Database db) async {
    debugPrint('[DATABASE] Upgrading schema to v18: Separating audit records table...');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_records (
        ${DbConstants.colRecordId} TEXT PRIMARY KEY,
        ${DbConstants.colInvoiceNumber} TEXT NOT NULL,
        ${DbConstants.colUserId} TEXT NOT NULL,
        ${DbConstants.colSupersedesId} TEXT,
        ${DbConstants.colIsHidden} INTEGER DEFAULT 0,
        ${DbConstants.colUpdatedAt} TEXT,
        ${DbConstants.colHsCode} TEXT,
        ${DbConstants.colHsDescription} TEXT,
        ${DbConstants.colHsDescriptionOfficial} TEXT,
        ${DbConstants.colVerificationStatus} TEXT,
        ${DbConstants.colConfidenceScore} INTEGER,
        ${DbConstants.colPromptVersion} INTEGER,
        ${DbConstants.colRiskLevel} TEXT,
        ${DbConstants.colChapter} TEXT,
        ${DbConstants.colCargoDescription} TEXT,
        ${DbConstants.colConsignee} TEXT,
        ${DbConstants.colStandardDutyRate} TEXT,
        ${DbConstants.colStatus} TEXT,
        ${DbConstants.colTimestamp} TEXT,
        ${DbConstants.colOriginCountry} TEXT,
        ${DbConstants.colDestinationCountry} TEXT,
        ${DbConstants.colTotalWeightKg} TEXT,
        ${DbConstants.colPlannedMonth} TEXT,
        ${DbConstants.colShippingMethod} TEXT,
        ${DbConstants.colNationalExtensionCode} TEXT,
        ${DbConstants.colNationalExtensionDescription} TEXT,
        ${DbConstants.colOriginPort} TEXT,
        ${DbConstants.colDestinationPort} TEXT,
        ${DbConstants.colPortCharges} TEXT,
        ${DbConstants.colDeclaredValue} TEXT,
        ${DbConstants.colCurrency} TEXT,
        ${DbConstants.colEstimatedDutyAmount} TEXT,
        ${DbConstants.colVatRate} TEXT,
        ${DbConstants.colTotalTaxBurden} TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_invoice '
      'ON audit_records(${DbConstants.colInvoiceNumber})',
    );

    await _backfillAuditRecords(db);
  }

  Future<void> _backfillAuditRecords(Database db) async {
    debugPrint('[DATABASE] Backfilling existing audit data from invoices...');
    final List<Map<String, dynamic>> records = await db.query('invoices');
    
    await db.transaction((txn) async {
      for (final row in records) {
        // Skip rows that don't have an HS code or description (manifest only)
        final hsCode = row[DbConstants.colHsCode];
        if (hsCode == null || hsCode.toString().isEmpty) continue;

        String recordId = row['record_id']?.toString() ?? '';
        if (recordId.isEmpty) {
          recordId = const Uuid().v4();
        }

        await txn.insert(
          'audit_records',
          {
            DbConstants.colRecordId: recordId,
            DbConstants.colInvoiceNumber: row[DbConstants.colId], // legacy ID was invoice number
            DbConstants.colUserId: row[DbConstants.colUserId],
            DbConstants.colSupersedesId: row[DbConstants.colSupersedesId],
            DbConstants.colIsHidden: row[DbConstants.colIsHidden] ?? 0,
            DbConstants.colUpdatedAt: row[DbConstants.colUpdatedAt],
            DbConstants.colHsCode: hsCode,
            DbConstants.colHsDescription: row[DbConstants.colHsDescription],
            DbConstants.colHsDescriptionOfficial: row[DbConstants.colHsDescriptionOfficial],
            DbConstants.colVerificationStatus: row[DbConstants.colVerificationStatus],
            DbConstants.colConfidenceScore: row[DbConstants.colConfidenceScore],
            DbConstants.colPromptVersion: row[DbConstants.colPromptVersion],
            DbConstants.colRiskLevel: row[DbConstants.colRiskLevel],
            DbConstants.colChapter: row[DbConstants.colChapter],
            DbConstants.colCargoDescription: row[DbConstants.colCargoDescription],
            DbConstants.colConsignee: row[DbConstants.colConsignee],
            DbConstants.colStandardDutyRate: row[DbConstants.colStandardDutyRate],
            DbConstants.colStatus: row[DbConstants.colStatus],
            DbConstants.colTimestamp: row[DbConstants.colTimestamp],
            DbConstants.colOriginCountry: row[DbConstants.colOriginCountry],
            DbConstants.colDestinationCountry: row[DbConstants.colDestinationCountry],
            DbConstants.colTotalWeightKg: row[DbConstants.colTotalWeightKg],
            DbConstants.colPlannedMonth: row[DbConstants.colPlannedMonth],
            DbConstants.colShippingMethod: row[DbConstants.colShippingMethod],
            DbConstants.colNationalExtensionCode: row[DbConstants.colNationalExtensionCode],
            DbConstants.colNationalExtensionDescription: row[DbConstants.colNationalExtensionDescription],
            DbConstants.colOriginPort: row[DbConstants.colOriginPort],
            DbConstants.colDestinationPort: row[DbConstants.colDestinationPort],
            DbConstants.colPortCharges: row[DbConstants.colPortCharges],
            DbConstants.colDeclaredValue: row[DbConstants.colDeclaredValue],
            DbConstants.colCurrency: row[DbConstants.colCurrency],
            DbConstants.colEstimatedDutyAmount: row[DbConstants.colEstimatedDutyAmount],
            DbConstants.colVatRate: row[DbConstants.colVatRate],
            DbConstants.colTotalTaxBurden: row[DbConstants.colTotalTaxBurden],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    debugPrint('[DATABASE] Backfill complete.');
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

    await db.execute('''
      CREATE TABLE audit_records (
        ${DbConstants.colRecordId} TEXT PRIMARY KEY,
        ${DbConstants.colInvoiceNumber} TEXT NOT NULL,
        ${DbConstants.colUserId} TEXT NOT NULL,
        ${DbConstants.colSupersedesId} TEXT,
        ${DbConstants.colIsHidden} INTEGER DEFAULT 0,
        ${DbConstants.colUpdatedAt} TEXT,
        ${DbConstants.colHsCode} TEXT,
        ${DbConstants.colHsDescription} TEXT,
        ${DbConstants.colHsDescriptionOfficial} TEXT,
        ${DbConstants.colVerificationStatus} TEXT,
        ${DbConstants.colConfidenceScore} INTEGER,
        ${DbConstants.colPromptVersion} INTEGER,
        ${DbConstants.colRiskLevel} TEXT,
        ${DbConstants.colChapter} TEXT,
        ${DbConstants.colCargoDescription} TEXT,
        ${DbConstants.colConsignee} TEXT,
        ${DbConstants.colStandardDutyRate} TEXT,
        ${DbConstants.colStatus} TEXT,
        ${DbConstants.colTimestamp} TEXT,
        ${DbConstants.colOriginCountry} TEXT,
        ${DbConstants.colDestinationCountry} TEXT,
        ${DbConstants.colTotalWeightKg} TEXT,
        ${DbConstants.colPlannedMonth} TEXT,
        ${DbConstants.colShippingMethod} TEXT,
        ${DbConstants.colNationalExtensionCode} TEXT,
        ${DbConstants.colNationalExtensionDescription} TEXT,
        ${DbConstants.colOriginPort} TEXT,
        ${DbConstants.colDestinationPort} TEXT,
        ${DbConstants.colPortCharges} TEXT,
        ${DbConstants.colDeclaredValue} TEXT,
        ${DbConstants.colCurrency} TEXT,
        ${DbConstants.colEstimatedDutyAmount} TEXT,
        ${DbConstants.colVatRate} TEXT,
        ${DbConstants.colTotalTaxBurden} TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_audit_invoice '
      'ON audit_records(${DbConstants.colInvoiceNumber})',
    );
    
    debugPrint('[DATABASE] Schemas created. Seeding in background...');
    await _seedTariffMaster(db);
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
        ${DbConstants.colUpdatedAt} TEXT,
        record_id TEXT,
        ${DbConstants.colSupersedesId} TEXT,
        ${DbConstants.colIsHidden} INTEGER DEFAULT 0
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
