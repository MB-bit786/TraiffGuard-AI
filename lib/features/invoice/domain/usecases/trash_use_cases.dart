import '../entities/invoice_entity.dart';
import '../repository/invoice_repository.dart';

class GetTrashedInvoicesUseCase {
  final InvoiceRepository repository;
  GetTrashedInvoicesUseCase(this.repository);

  Future<List<InvoiceEntity>> execute(String userId) async {
    return await repository.getTrashedInvoices(userId);
  }
}

class RestoreInvoiceUseCase {
  final InvoiceRepository repository;
  RestoreInvoiceUseCase(this.repository);

  Future<void> execute(String userId, String invoiceId) async {
    await repository.softDeleteInvoice(invoiceId, false);
  }
}

class PermanentlyDeleteInvoiceUseCase {
  final InvoiceRepository repository;
  PermanentlyDeleteInvoiceUseCase(this.repository);

  Future<void> execute(String userId, String invoiceId) async {
    await repository.hardDeleteInvoice(invoiceId);
  }
}
