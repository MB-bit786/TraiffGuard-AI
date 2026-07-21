import 'dart:async';
import 'package:hscode_auditor/features/invoice/domain/entities/invoice_entity.dart';
import 'package:hscode_auditor/features/audit/domain/entities/hs_audit_result_entity.dart';
import 'package:hscode_auditor/features/invoice/domain/repository/invoice_repository.dart';
import 'package:hscode_auditor/features/invoice/data/data_sources/invoice_local_data_source.dart';
import 'package:hscode_auditor/features/invoice/data/data_sources/invoice_remote_data_source.dart';
import 'package:hscode_auditor/features/invoice/data/models/invoice_model.dart';
import 'package:hscode_auditor/features/audit/data/models/hs_audit_result_model.dart';
import 'package:hscode_auditor/core/services/sql_database_service.dart';

class InvoiceRepositoryImpl implements InvoiceRepository {
  final InvoiceLocalDataSource localDataSource;
  final InvoiceRemoteDataSource remoteDataSource;
  final SqlDatabaseService dbService;

  // Reactive stream to broadcast invoice list updates
  final _invoiceStreamController = StreamController<List<InvoiceEntity>>.broadcast();

  InvoiceRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.dbService,
  });

  @override
  Stream<List<InvoiceEntity>> watchInvoices(String userId) {
    // Trigger initial fetch when a new listener joins
    _refreshInvoices(userId);
    return _invoiceStreamController.stream;
  }

  Future<void> _refreshInvoices(String userId) async {
    final invoices = await localDataSource.getAllInvoices(userId);
    _invoiceStreamController.add(invoices);
  }

  @override
  Future<void> cacheInvoiceManifest(InvoiceEntity invoice, {HsAuditResultEntity? auditResult}) async {
    final model = _toInvoiceModel(invoice);
    await localDataSource.cacheInvoice(model);

    if (auditResult != null) {
      final resultModel = _toModel(auditResult);
      await localDataSource.cacheAuditResult(resultModel);
      
      if (invoice.status == 'synced') {
        await remoteDataSource.syncAuditResult(resultModel);
      }
    }
    // Broadcast change
    _refreshInvoices(invoice.userId);
  }

  @override
  Future<List<InvoiceEntity>> getAllInvoices(String userId) async {
    return await localDataSource.getAllInvoices(userId);
  }

  @override
  Future<List<HsAuditResultEntity>> getPendingDraftResults(String userId) async {
    return await localDataSource.getPendingDraftResults(userId);
  }

  @override
  Future<void> updateAuditSyncStatus(InvoiceEntity manifest, HsAuditResultEntity result) async {
    final manifestModel = _toInvoiceModel(manifest);
    final resultModel = _toModel(result);
    
    await localDataSource.cacheInvoice(manifestModel);
    await localDataSource.cacheAuditResult(resultModel);
    await remoteDataSource.syncAuditResult(resultModel);

    // Broadcast change
    _refreshInvoices(manifest.userId);
  }

  @override
  Future<List<InvoiceEntity>> getTrashedInvoices(String userId) async {
    return await localDataSource.getTrashedInvoices(userId);
  }

  @override
  Future<void> softDeleteInvoice(String id, String userId, bool delete) async {
    await localDataSource.updateInvoiceDeletedStatus(id, userId, delete);
    await localDataSource.updateAuditDeletedStatus(id, userId, delete);
    await remoteDataSource.updateDeletedStatus(id, userId, delete);

    // Broadcast change
    _refreshInvoices(userId);
  }

  @override
  Future<void> hardDeleteInvoice(String id, String userId) async {
    await localDataSource.hardDeleteInvoice(id, userId);
    await localDataSource.hardDeleteAudit(id, userId);
    await remoteDataSource.permanentlyDelete(id, userId);

    // Broadcast change
    _refreshInvoices(userId);
  }

  @override
  Future<HsAuditResultEntity?> getAuditResultByInvoiceId(String id, String userId) async {
    return await localDataSource.getAuditResult(id, userId);
  }

  @override
  Future<List<Map<String, dynamic>>> searchTariffMaster(String query) async {
    final db = await dbService.database;
    if (query.trim().isEmpty) return await db.query('static_hs_codes', limit: 50);
    final words = query.trim().toLowerCase().split(' ').where((w) => w.isNotEmpty).toList();
    String whereClause = words.map((_) => 'description LIKE ?').join(' AND ');
    List<String> args = words.map((word) => '%$word%').toList();
    return await db.query('static_hs_codes', where: whereClause, whereArgs: args, limit: 50);
  }

  @override
  void notifyChanges(String userId) {
    _refreshInvoices(userId);
  }

  HsAuditResultModel _toModel(HsAuditResultEntity e) {
    return HsAuditResultModel(
      hsCode: e.hsCode,
      userId: e.userId,
      hsDescription: e.hsDescription,
      chapter: e.chapter,
      consignee: e.consignee,
      invoiceNumber: e.invoiceNumber,
      cargoDescription: e.cargoDescription,
      standardDutyRate: e.standardDutyRate,
      vatRate: e.vatRate,
      totalTaxBurden: e.totalTaxBurden,
      declaredValue: e.declaredValue,
      currency: e.currency,
      estimatedDutyAmount: e.estimatedDutyAmount,
      confidenceScore: e.confidenceScore,
      complianceWarnings: e.complianceWarnings,
      requiredDocuments: e.requiredDocuments,
      auditTimestamp: e.auditTimestamp,
      riskLevel: e.riskLevel,
      status: e.status,
      originCountry: e.originCountry,
      destinationCountry: e.destinationCountry,
      totalWeightKg: e.totalWeightKg,
      plannedMonth: e.plannedMonth,
      shippingMethod: e.shippingMethod,
      isDeleted: e.isDeleted,
      nationalExtensionCode: e.nationalExtensionCode,
      nationalExtensionDescription: e.nationalExtensionDescription,
      originPort: e.originPort,
      destinationPort: e.destinationPort,
      portCharges: e.portCharges,
    );
  }

  InvoiceModel _toInvoiceModel(InvoiceEntity e) {
    return InvoiceModel(
      id: e.id,
      userId: e.userId,
      consignee: e.consignee,
      cargoDescription: e.cargoDescription,
      hsCode: e.hsCode,
      dutyRate: e.dutyRate,
      status: e.status,
      timestamp: e.timestamp,
      isDeleted: e.isDeleted,
    );
  }
}
