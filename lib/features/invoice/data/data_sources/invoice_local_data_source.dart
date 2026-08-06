import 'package:sqflite/sqflite.dart';
import 'package:hscode_auditor/core/services/sql_database_service.dart';
import 'package:hscode_auditor/core/constants/db_constants.dart';
import 'package:hscode_auditor/features/invoice/data/models/invoice_model.dart';
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
  Future<List<HsAuditResultModel>> getAuditHistory(String invoiceNumber, String userId);
  Future<void> hideAuditRecord(String recordId, String userId);
  Future<void> cacheAuditRecord(HsAuditResultModel result);
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
        DbConstants.colStatus: invoice.status,
        DbConstants.colTimestamp: invoice.timestamp,
        DbConstants.colIsDeleted: invoice.isDeleted ? 1 : 0,
        DbConstants.colUpdatedAt: invoice.updatedAt,
        DbConstants.colRecordId: invoice.recordId,
        DbConstants.colIsHidden: invoice.isHidden ? 1 : 0,
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
    await db.insert(
      'audit_records',
      {
        DbConstants.colRecordId: result.recordId,
        DbConstants.colInvoiceNumber: result.invoiceNumber,
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
        DbConstants.colNationalExtensionCode: result.nationalExtensionCode,
        DbConstants.colNationalExtensionDescription: result.nationalExtensionDescription,
        DbConstants.colOriginPort: result.originPort,
        DbConstants.colDestinationPort: result.destinationPort,
        DbConstants.colPortCharges: json.encode(result.portCharges),
        DbConstants.colPromptVersion: result.promptVersion,
        DbConstants.colVerificationStatus: result.verificationStatus.name,
        DbConstants.colHsDescriptionOfficial: result.hsDescriptionOfficial,
        DbConstants.colUpdatedAt: result.updatedAt,
        DbConstants.colSupersedesId: result.supersedesId,
        DbConstants.colIsHidden: result.isHidden ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<InvoiceModel>> getAllInvoices(String userId) async {
    final db = await _dbService.database;
    final maps = await db.rawQuery('''
      SELECT i.*, 
             a.${DbConstants.colHsCode}, 
             a.${DbConstants.colStandardDutyRate} as dutyRate
      FROM invoices i
      LEFT JOIN audit_records a ON i.${DbConstants.colId} = a.${DbConstants.colInvoiceNumber} 
        AND a.${DbConstants.colIsHidden} = 0
        AND a.${DbConstants.colUpdatedAt} = (
          SELECT MAX(${DbConstants.colUpdatedAt}) 
          FROM audit_records 
          WHERE ${DbConstants.colInvoiceNumber} = i.${DbConstants.colId} 
          AND ${DbConstants.colIsHidden} = 0
        )
      WHERE i.${DbConstants.colIsDeleted} = 0 
        AND i.${DbConstants.colIsHidden} = 0 
        AND i.${DbConstants.colUserId} = ?
      ORDER BY i.${DbConstants.colTimestamp} DESC
    ''', [userId]);
    
    return maps.map((m) => _mapToInvoiceModel(m)).toList();
  }

  @override
  Future<List<HsAuditResultModel>> getPendingDraftResults(String userId) async {
    final db = await _dbService.database;
    // CRITICAL: We only pick up records that are explicitly NOT synced.
    // Sync state now lives on the audit record.
    final maps = await db.query(
      'audit_records',
      where: '${DbConstants.colStatus} != "synced" '
             'AND ${DbConstants.colIsDeleted} = 0 '
             'AND ${DbConstants.colIsHidden} = 0 '
             'AND ${DbConstants.colUserId} = ?',
      whereArgs: [userId],
    );
    return maps.map((m) => _mapToHsAuditResultModel(m)).toList();
  }

  @override
  Future<List<InvoiceModel>> getTrashedInvoices(String userId) async {
    final db = await _dbService.database;
    final maps = await db.rawQuery('''
      SELECT i.*, 
             a.${DbConstants.colHsCode}, 
             a.${DbConstants.colStandardDutyRate} as dutyRate
      FROM invoices i
      LEFT JOIN audit_records a ON i.${DbConstants.colId} = a.${DbConstants.colInvoiceNumber} 
        AND a.${DbConstants.colIsHidden} = 0
        AND a.${DbConstants.colUpdatedAt} = (
          SELECT MAX(${DbConstants.colUpdatedAt}) 
          FROM audit_records 
          WHERE ${DbConstants.colInvoiceNumber} = i.${DbConstants.colId} 
          AND ${DbConstants.colIsHidden} = 0
        )
      WHERE i.${DbConstants.colIsDeleted} = 1 AND i.${DbConstants.colUserId} = ?
      ORDER BY i.${DbConstants.colTimestamp} DESC
    ''', [userId]);
    
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
    final db = await _dbService.database;
    await db.update(
      'audit_records',
      {DbConstants.colIsDeleted: isDeleted ? 1 : 0},
      where: '${DbConstants.colInvoiceNumber} = ? AND ${DbConstants.colUserId} = ?',
      whereArgs: [id, userId],
    );
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
    final db = await _dbService.database;
    await db.update(
      'audit_records',
      {
        DbConstants.colIsHidden: 1,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.colRecordId} = ? AND ${DbConstants.colUserId} = ?',
      whereArgs: [id, userId],
    );
  }

  @override
  Future<List<HsAuditResultModel>> getAuditHistory(String invoiceNumber, String userId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'audit_records',
      where: '${DbConstants.colInvoiceNumber} = ? AND ${DbConstants.colUserId} = ?',
      whereArgs: [invoiceNumber, userId],
      orderBy: '${DbConstants.colUpdatedAt} ASC',
    );
    return maps.map((m) => _mapToHsAuditResultModel(m)).toList();
  }

  @override
  Future<void> hideAuditRecord(String recordId, String userId) async {
    final db = await _dbService.database;
    await db.update(
      'audit_records',
      {
        DbConstants.colIsHidden: 1,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.colRecordId} = ? AND ${DbConstants.colUserId} = ?',
      whereArgs: [recordId, userId],
    );
  }

  @override
  Future<void> cacheAuditRecord(HsAuditResultModel result) async {
    await cacheAuditResult(result);
  }

  @override // this method is called when user opens an invoice to see the ai audit result
  Future<HsAuditResultModel?> getAuditResult(String id, String userId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'audit_records',
      where: '${DbConstants.colInvoiceNumber} = ? AND ${DbConstants.colUserId} = ? AND ${DbConstants.colIsHidden} = 0',
      whereArgs: [id, userId],
      orderBy: '${DbConstants.colUpdatedAt} DESC',
      limit: 1,
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
      updatedAt: map[DbConstants.colUpdatedAt] as String? ?? '',
      recordId: map[DbConstants.colRecordId] as String? ?? '',
      isHidden: (map[DbConstants.colIsHidden] as int? ?? 0) == 1,
    );
  }

  HsAuditResultModel _mapToHsAuditResultModel(Map<String, dynamic> map) {
    return HsAuditResultModel(
      hsCode: map[DbConstants.colHsCode] as String? ?? '',
      userId: map[DbConstants.colUserId] as String? ?? 'anonymous',
      hsDescription: map[DbConstants.colHsDescription] as String? ?? '',
      chapter: map[DbConstants.colChapter] as String? ?? '',
      consignee: map[DbConstants.colConsignee] as String? ?? '',
      invoiceNumber: (map[DbConstants.colInvoiceNumber] ?? map[DbConstants.colId]) as String,
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
      nationalExtensionCode: map[DbConstants.colNationalExtensionCode] as String? ?? '',
      nationalExtensionDescription: map[DbConstants.colNationalExtensionDescription] as String? ?? '',
      originPort: map[DbConstants.colOriginPort] as String? ?? '',
      destinationPort: map[DbConstants.colDestinationPort] as String? ?? '',
      promptVersion: map[DbConstants.colPromptVersion] as int? ?? 0,
      recordId: map[DbConstants.colRecordId] as String? ?? '',
      supersedesId: map[DbConstants.colSupersedesId] as String? ?? '',
      isHidden: (map[DbConstants.colIsHidden] as int? ?? 0) == 1,
      verificationStatus: HsAuditResultModel.parseVerificationStatus(map[DbConstants.colVerificationStatus]),
      hsDescriptionOfficial: map[DbConstants.colHsDescriptionOfficial] as String? ?? '',
      updatedAt: map[DbConstants.colUpdatedAt] as String? ?? '',
      portCharges: (map[DbConstants.colPortCharges] is String) 
          ? List<Map<String, String>>.from((json.decode(map[DbConstants.colPortCharges] as String) as List)
              .map((e) => Map<String, String>.from(e as Map)))
          : [],
    );
  }
}
