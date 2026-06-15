import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/core/services/sql_database_service.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/models/invoice_model.dart';
import '../../../audit/domain/models/hs_audit_result_model.dart';

/// Concrete SQFLite implementation of the Invoice Repository
class SqlInvoiceRepository {
  final SqlDatabaseService _dbService;

  SqlInvoiceRepository(this._dbService);

  /// Caches an invoice manifest and optional audit result to local SQLite tables
  Future<void> cacheInvoiceManifest(InvoiceModel invoice, {HsAuditResultModel? auditResult}) async {
    final db = await _dbService.database;

    await db.transaction((txn) async {
      // 1. Insert/Replace the Invoice Summary
      await txn.insert(
        'invoices',
        invoice.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. If an AI Audit result is provided, store it in the detailed table
      if (auditResult != null) {
        await txn.insert(
          'audit_results',
          auditResult.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Retrieves all cached invoices from the local database
  Future<List<InvoiceModel>> getAllInvoices() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      where: 'isDeleted = 0',
      orderBy: 'timestamp DESC',
    );
    
    return List.generate(maps.length, (i) => InvoiceModel.fromMap(maps[i]));
  }

  /// Retrieves audit results that are flagged as offline drafts
  Future<List<HsAuditResultModel>> getPendingDraftResults() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'audit_results',
      where: 'confidenceScore = 0 OR hsCode LIKE "%(Offline Draft)%"',
    );
    return List.generate(maps.length, (i) => HsAuditResultModel.fromMap(maps[i]));
  }

  /// Updates an existing audit result and its corresponding invoice manifest after a successful sync
  Future<void> updateAuditSyncStatus(InvoiceModel manifest, HsAuditResultModel result) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await txn.update(
        'invoices',
        manifest.toMap(),
        where: 'id = ?',
        whereArgs: [manifest.id],
      );
      await txn.update(
        'audit_results',
        result.toMap(),
        where: 'invoiceNumber = ?',
        whereArgs: [result.invoiceNumber],
      );
    });
  }

  /// Retrieves all soft-deleted cached invoices (Trash Bin)
  Future<List<InvoiceModel>> getTrashedInvoices() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      where: 'isDeleted = 1',
      orderBy: 'timestamp DESC',
    );
    
    return List.generate(maps.length, (i) => InvoiceModel.fromMap(maps[i]));
  }

  /// Sets the deletion flag for a specific invoice and its results
  Future<void> softDeleteInvoice(String id, bool delete) async {
    final db = await _dbService.database;
    final int value = delete ? 1 : 0;
    
    await db.transaction((txn) async {
      await txn.update(
        'invoices',
        {'isDeleted': value},
        where: 'id = ?',
        whereArgs: [id],
      );
      
      await txn.update(
        'audit_results',
        {'isDeleted': value},
        where: 'invoiceNumber = ?',
        whereArgs: [id],
      );
    });
  }

  /// Hard deletes an invoice and its associated audit results permanently
  Future<void> hardDeleteInvoice(String id) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await txn.delete(
        'invoices',
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'audit_results',
        where: 'invoiceNumber = ?',
        whereArgs: [id],
      );
    });
  }

  /// Fetches a detailed audit result matching a specific invoice identifier
  Future<HsAuditResultModel?> getAuditResultByInvoiceId(String id) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'audit_results',
      where: 'invoiceNumber = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return HsAuditResultModel.fromMap(maps.first);
  }

  /// Searches the static universal tariff library using a multi-keyword 'AND' refinement strategy.
  /// If query is empty, returns the first 50 results (All filter support).
  Future<List<Map<String, dynamic>>> searchTariffMaster(String query) async {
    final db = await _dbService.database;

    // 1. If empty, return a base set of results for the "All" view
    if (query.trim().isEmpty) {
      return await db.query(
        'static_hs_codes',
        limit: 50,
      );
    }

    // 2. Clean and tokenize the query into individual lowercase keywords
    final words = query.trim().toLowerCase().split(' ').where((w) => w.isNotEmpty).toList();
    
    // 2. Construct dynamic SQL linking each keyword with AND logic on the description column
    // We also include a check for the hs_code on the first word for quick code lookups
    String whereClause = words.map((_) => 'description LIKE ?').join(' AND ');
    List<String> args = words.map((word) => '%$word%').toList();

    // 3. Optimization: If the query is a single word, also check the HS Code column
    if (words.length == 1) {
      whereClause = '(hs_code LIKE ? OR $whereClause)';
      args.insert(0, '${words[0]}%');
    }

    // 4. Execute the refined query with a result limit for UI responsiveness
    return await db.query(
      'static_hs_codes',
      where: whereClause,
      whereArgs: args,
      limit: 50,
    );
  }
}

/// Provider for the SQFLite implementation of the repository
final sqlInvoiceRepositoryProvider = Provider<SqlInvoiceRepository>((ref) {
  final dbService = ref.watch(sqlDatabaseServiceProvider);
  return SqlInvoiceRepository(dbService);
});
