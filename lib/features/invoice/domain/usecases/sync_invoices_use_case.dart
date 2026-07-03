import '../repository/invoice_repository.dart';
import '../../../../core/util/auth_service.dart';

class SyncInvoicesUseCase {
  final InvoiceRepository repository;
  final AuthService authService;

  SyncInvoicesUseCase(this.repository, this.authService);

  Future<void> execute(String userId) async {
    if (userId != 'anonymous') {
      await authService.hydrateLocalDatabaseFromServer(userId);
    }
  }
}
