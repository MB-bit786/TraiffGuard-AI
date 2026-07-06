import '../entities/invoice_entity.dart';
import '../repository/invoice_repository.dart';

class TrashUseCases {
  final InvoiceRepository repository;
  TrashUseCases(this.repository);

  Future<List<InvoiceEntity>> getTrashedInvoices(String userId) async {
    return await repository.getTrashedInvoices(userId);
  }

  Future<void> restoreInvoice(String userId, String invoiceId) async {
    await repository.softDeleteInvoice(invoiceId, false);
  }

  Future<void> permanentlyDeleteInvoice(String userId, String invoiceId) async {
    await repository.hardDeleteInvoice(invoiceId);
  }
}
