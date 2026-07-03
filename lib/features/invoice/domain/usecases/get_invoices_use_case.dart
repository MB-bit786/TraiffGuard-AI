import '../entities/invoice_entity.dart';
import '../repository/invoice_repository.dart';

class GetInvoicesUseCase {
  final InvoiceRepository repository;

  GetInvoicesUseCase(this.repository);

  Future<List<InvoiceEntity>> execute(String userId) async {
    return await repository.getAllInvoices(userId);
  }
}
