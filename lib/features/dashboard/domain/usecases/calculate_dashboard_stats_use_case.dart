import 'package:hscode_auditor/features/invoice/domain/entities/invoice_entity.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/dashboard_stats_provider.dart';

class CalculateDashboardStatsUseCase {
  DashboardStats execute(List<InvoiceEntity> invoices) {
    return DashboardStats(
      total: invoices.length,
      synced: invoices.where((i) => i.status == 'synced').length,
      drafts: invoices.where((i) => i.status == 'offlineDraft').length,
    );
  }
}
