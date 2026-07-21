import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/invoice_list_provider.dart';
import 'package:hscode_auditor/features/dashboard/domain/usecases/calculate_dashboard_stats_use_case.dart';

class DashboardStats {
  final int total;
  final int synced;
  final int drafts;

  DashboardStats({required this.total, required this.synced, required this.drafts});
}

final calculateDashboardStatsUseCaseProvider = Provider<CalculateDashboardStatsUseCase>((ref) {
  return CalculateDashboardStatsUseCase();
});

final dashboardStatsProvider = Provider.autoDispose<DashboardStats>((ref) {
  final invoiceListAsync = ref.watch(invoiceListProvider);
  final useCase = ref.watch(calculateDashboardStatsUseCaseProvider);
  
  return invoiceListAsync.maybeWhen(
    data: (invoices) => useCase.execute(invoices),
    orElse: () => DashboardStats(total: 0, synced: 0, drafts: 0),
  );
});
