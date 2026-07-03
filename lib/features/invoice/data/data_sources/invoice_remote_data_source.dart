import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../audit/data/models/hs_audit_result_model.dart';

abstract class InvoiceRemoteDataSource {
  Future<void> syncAuditResult(HsAuditResultModel result);
  Future<void> updateDeletedStatus(String id, String userId, bool isDeleted);
  Future<void> permanentlyDelete(String id, String userId);
}

class InvoiceRemoteDataSourceImpl implements InvoiceRemoteDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> syncAuditResult(HsAuditResultModel result) async {
    await _firestore
        .collection('users')
        .doc(result.userId)
        .collection('invoices')
        .doc(result.invoiceNumber)
        .set(result.toMap());
  }

  @override
  Future<void> updateDeletedStatus(String id, String userId, bool isDeleted) async {
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('invoices')
        .doc(id);
    
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.update({'isDeleted': isDeleted ? 1 : 0});
    }
  }

  @override
  Future<void> permanentlyDelete(String id, String userId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('invoices')
        .doc(id)
        .delete();
  }
}
