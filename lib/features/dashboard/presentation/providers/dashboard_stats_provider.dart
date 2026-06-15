import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../invoice/domain/models/invoice_model.dart';
import 'invoice_list_provider.dart';

class DashboardStats {
  final int total;
  final int synced;
  final int drafts;

  DashboardStats({required this.total, required this.synced, required this.drafts});
}

/// Specialized provider that computes summary statistics from the invoice list.
/// Using a separate provider ensures that components watching stats only rebuild
/// when the calculated counts change, not on every list update.
final dashboardStatsProvider = Provider.autoDispose<DashboardStats>((ref) {
  final invoiceListAsync = ref.watch(invoiceListProvider);
  
  return invoiceListAsync.maybeWhen(
    data: (invoices) => DashboardStats(
      total: invoices.length,
      synced: invoices.where((i) => i.status == InvoiceSyncStatus.synced).length,
      drafts: invoices.where((i) => i.status == InvoiceSyncStatus.offlineDraft).length,
    ),
    orElse: () => DashboardStats(total: 0, synced: 0, drafts: 0),
  );
});
