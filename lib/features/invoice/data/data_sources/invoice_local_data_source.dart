import 'package:sqflite/sqflite.dart';
import '../../../../core/util/sql_database_service.dart';
import '../models/invoice_model.dart';
import '../../../audit/data/models/hs_audit_result_model.dart';

abstract class InvoiceLocalDataSource {
  Future<void> cacheInvoice(InvoiceModel invoice);
  Future<void> cacheAuditResult(HsAuditResultModel result);
  Future<List<InvoiceModel>> getAllInvoices(String userId);
  Future<List<HsAuditResultModel>> getPendingDraftResults(String userId);
  Future<List<InvoiceModel>> getTrashedInvoices(String userId);
  Future<void> updateInvoiceDeletedStatus(String id, String userId, bool isDeleted);
  Future<void> updateAuditDeletedStatus(String id, String userId, bool isDeleted);
  Future<void> hardDeleteInvoice(String id, String userId);
  Future<void> hardDeleteAudit(String id, String userId);
  Future<HsAuditResultModel?> getAuditResult(String id, String userId);
}

class InvoiceLocalDataSourceImpl implements InvoiceLocalDataSource {
  final SqlDatabaseService _dbService;

  InvoiceLocalDataSourceImpl(this._dbService);

  @override
  Future<void> cacheInvoice(InvoiceModel invoice) async {
    final db = await _dbService.database;
    await db.insert('invoices', invoice.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> cacheAuditResult(HsAuditResultModel result) async {
    final db = await _dbService.database;
    await db.insert('audit_results', result.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<InvoiceModel>> getAllInvoices(String userId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'invoices',
      where: 'isDeleted = 0 AND userId = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => InvoiceModel.fromMap(m)).toList();
  }

  @override
  Future<List<HsAuditResultModel>> getPendingDraftResults(String userId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'audit_results',
      where: '(confidenceScore = 0 OR hsCode LIKE "%(Offline Draft)%") AND isDeleted = 0 AND userId = ?',
      whereArgs: [userId],
    );
    return maps.map((m) => HsAuditResultModel.fromMap(m)).toList();
  }

  @override
  Future<List<InvoiceModel>> getTrashedInvoices(String userId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'invoices',
      where: 'isDeleted = 1 AND userId = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => InvoiceModel.fromMap(m)).toList();
  }

  @override
  Future<void> updateInvoiceDeletedStatus(String id, String userId, bool isDeleted) async {
    final db = await _dbService.database;
    await db.update(
      'invoices',
      {'isDeleted': isDeleted ? 1 : 0},
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  @override
  Future<void> updateAuditDeletedStatus(String id, String userId, bool isDeleted) async {
    final db = await _dbService.database;
    await db.update(
      'audit_results',
      {'isDeleted': isDeleted ? 1 : 0},
      where: 'invoiceNumber = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  @override
  Future<void> hardDeleteInvoice(String id, String userId) async {
    final db = await _dbService.database;
    await db.delete('invoices', where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }

  @override
  Future<void> hardDeleteAudit(String id, String userId) async {
    final db = await _dbService.database;
    await db.delete('audit_results', where: 'invoiceNumber = ? AND userId = ?', whereArgs: [id, userId]);
  }

  @override
  Future<HsAuditResultModel?> getAuditResult(String id, String userId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'audit_results',
      where: 'invoiceNumber = ? AND userId = ?',
      whereArgs: [id, userId],
    );
    if (maps.isEmpty) return null;
    return HsAuditResultModel.fromMap(maps.first);
  }
}
