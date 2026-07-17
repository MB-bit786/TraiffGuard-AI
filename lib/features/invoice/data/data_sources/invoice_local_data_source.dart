import 'package:sqflite/sqflite.dart';
import '../../../../core/services/sql_database_service.dart';
import 'package:hscode_auditor/core/constants/db_constants.dart';
import '../models/invoice_model.dart';
import 'package:hscode_auditor/features/audit/data/models/hs_audit_result_model.dart';
import 'dart:convert';

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
    
    // SMART CACHE: We use a transaction to check if the record exists.
    // If it exists, we only update manifest fields to avoid wiping high-fidelity AI data.
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> existing = await txn.query(
        'invoices',
        columns: [DbConstants.colId],
        where: '${DbConstants.colId} = ?',
        whereArgs: [invoice.id],
      );

      final manifestData = {
        DbConstants.colId: invoice.id,
        DbConstants.colUserId: invoice.userId,
        DbConstants.colConsignee: invoice.consignee,
        DbConstants.colCargoDescription: invoice.cargoDescription,
        DbConstants.colHsCode: invoice.hsCode,
        DbConstants.colStandardDutyRate: invoice.dutyRate,
        DbConstants.colStatus: invoice.status,
        DbConstants.colTimestamp: invoice.timestamp,
        DbConstants.colIsDeleted: invoice.isDeleted ? 1 : 0,
      };

      if (existing.isNotEmpty) {
        await txn.update(
          'invoices',
          manifestData,
          where: '${DbConstants.colId} = ?',
          whereArgs: [invoice.id],
        );
      } else {
        await txn.insert(
          'invoices',
          manifestData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> cacheAuditResult(HsAuditResultModel result) async {
    final db = await _dbService.database;
    // Audit results are high-fidelity, so we can use REPLACE safely here as they contain all columns.
    await db.insert(
      'invoices',
      {
        DbConstants.colId: result.invoiceNumber,
        DbConstants.colUserId: result.userId,
        DbConstants.colConsignee: result.consignee,
        DbConstants.colCargoDescription: result.cargoDescription,
        DbConstants.colHsCode: result.hsCode,
        DbConstants.colHsDescription: result.hsDescription,
        DbConstants.colChapter: result.chapter,
        DbConstants.colStandardDutyRate: result.standardDutyRate,
        DbConstants.colVatRate: result.vatRate,
        DbConstants.colTotalTaxBurden: result.totalTaxBurden,
        DbConstants.colDeclaredValue: result.declaredValue,
        DbConstants.colCurrency: result.currency,
        DbConstants.colEstimatedDutyAmount: result.estimatedDutyAmount,
        DbConstants.colConfidenceScore: result.confidenceScore,
        DbConstants.colComplianceWarnings: json.encode(result.complianceWarnings),
        DbConstants.colRequiredDocuments: json.encode(result.requiredDocuments),
        DbConstants.colTimestamp: result.auditTimestamp,
        DbConstants.colStatus: result.status,
        DbConstants.colRiskLevel: result.riskLevel.name,
        DbConstants.colOriginCountry: result.originCountry,
        DbConstants.colDestinationCountry: result.destinationCountry,
        DbConstants.colTotalWeightKg: result.totalWeightKg,
        DbConstants.colPlannedMonth: result.plannedMonth,
        DbConstants.colShippingMethod: result.shippingMethod,
        DbConstants.colIsDeleted: result.isDeleted ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<InvoiceModel>> getAllInvoices(String userId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'invoices',
      where: '${DbConstants.colIsDeleted} = 0 AND ${DbConstants.colUserId} = ?',
      whereArgs: [userId],
      orderBy: '${DbConstants.colTimestamp} DESC',
    );
    return maps.map((m) => _mapToInvoiceModel(m)).toList();
  }

  @override
  Future<List<HsAuditResultModel>> getPendingDraftResults(String userId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'invoices',
      where: '(${DbConstants.colConfidenceScore} = 0 OR ${DbConstants.colHsCode} LIKE "%(Offline Draft)%") AND ${DbConstants.colIsDeleted} = 0 AND ${DbConstants.colUserId} = ?',
      whereArgs: [userId],
    );
    return maps.map((m) => _mapToHsAuditResultModel(m)).toList();
  }

  @override
  Future<List<InvoiceModel>> getTrashedInvoices(String userId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'invoices',
      where: '${DbConstants.colIsDeleted} = 1 AND ${DbConstants.colUserId} = ?',
      whereArgs: [userId],
      orderBy: '${DbConstants.colTimestamp} DESC',
    );
    return maps.map((m) => _mapToInvoiceModel(m)).toList();
  }

  @override
  Future<void> updateInvoiceDeletedStatus(String id, String userId, bool isDeleted) async {
    final db = await _dbService.database;
    await db.update(
      'invoices',
      {DbConstants.colIsDeleted: isDeleted ? 1 : 0},
      where: '${DbConstants.colId} = ? AND ${DbConstants.colUserId} = ?',
      whereArgs: [id, userId],
    );
  }

  @override
  Future<void> updateAuditDeletedStatus(String id, String userId, bool isDeleted) async {
    await updateInvoiceDeletedStatus(id, userId, isDeleted);
  }

  @override
  Future<void> hardDeleteInvoice(String id, String userId) async {
    final db = await _dbService.database;
    await db.delete(
      'invoices',
      where: '${DbConstants.colId} = ? AND ${DbConstants.colUserId} = ?',
      whereArgs: [id, userId],
    );
  }

  @override
  Future<void> hardDeleteAudit(String id, String userId) async {
    await hardDeleteInvoice(id, userId);
  }

  @override
  Future<HsAuditResultModel?> getAuditResult(String id, String userId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'invoices',
      where: '${DbConstants.colId} = ? AND ${DbConstants.colUserId} = ?',
      whereArgs: [id, userId],
    );
    if (maps.isEmpty) return null;
    return _mapToHsAuditResultModel(maps.first);
  }

  InvoiceModel _mapToInvoiceModel(Map<String, dynamic> map) {
    return InvoiceModel(
      id: map[DbConstants.colId] as String,
      userId: map[DbConstants.colUserId] as String? ?? 'anonymous',
      consignee: map[DbConstants.colConsignee] as String? ?? '',
      cargoDescription: map[DbConstants.colCargoDescription] as String? ?? '',
      hsCode: map[DbConstants.colHsCode] as String? ?? '',
      dutyRate: map[DbConstants.colStandardDutyRate] as String? ?? '',
      status: map[DbConstants.colStatus] as String? ?? '',
      timestamp: map[DbConstants.colTimestamp] as String? ?? '',
      isDeleted: (map[DbConstants.colIsDeleted] as int? ?? 0) == 1,
    );
  }

  HsAuditResultModel _mapToHsAuditResultModel(Map<String, dynamic> map) {
    return HsAuditResultModel(
      hsCode: map[DbConstants.colHsCode] as String? ?? '',
      userId: map[DbConstants.colUserId] as String? ?? 'anonymous',
      hsDescription: map[DbConstants.colHsDescription] as String? ?? '',
      chapter: map[DbConstants.colChapter] as String? ?? '',
      consignee: map[DbConstants.colConsignee] as String? ?? '',
      invoiceNumber: map[DbConstants.colId] as String,
      cargoDescription: map[DbConstants.colCargoDescription] as String? ?? '',
      standardDutyRate: map[DbConstants.colStandardDutyRate] as String? ?? '',
      vatRate: map[DbConstants.colVatRate] as String? ?? '',
      totalTaxBurden: map[DbConstants.colTotalTaxBurden] as String? ?? '',
      declaredValue: map[DbConstants.colDeclaredValue] as String? ?? '',
      currency: map[DbConstants.colCurrency] as String? ?? '',
      estimatedDutyAmount: map[DbConstants.colEstimatedDutyAmount] as String? ?? '',
      confidenceScore: map[DbConstants.colConfidenceScore] as int? ?? 0,
      complianceWarnings: List<String>.from(json.decode(map[DbConstants.colComplianceWarnings] as String? ?? '[]')),
      requiredDocuments: List<String>.from(json.decode(map[DbConstants.colRequiredDocuments] as String? ?? '[]')),
      auditTimestamp: map[DbConstants.colTimestamp] as String? ?? '',
      riskLevel: HsAuditResultModel.parseRiskLevel(map[DbConstants.colRiskLevel] as String? ?? 'medium'),
      status: map[DbConstants.colStatus] as String? ?? 'synced',
      originCountry: map[DbConstants.colOriginCountry] as String? ?? 'IN',
      destinationCountry: map[DbConstants.colDestinationCountry] as String? ?? 'US',
      totalWeightKg: map[DbConstants.colTotalWeightKg] as String? ?? '0',
      plannedMonth: map[DbConstants.colPlannedMonth] as String? ?? 'January',
      shippingMethod: map[DbConstants.colShippingMethod] as String? ?? 'Sea Freight',
      isDeleted: (map[DbConstants.colIsDeleted] as int? ?? 0) == 1,
    );
  }
}
