import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/audit_filter_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/invoice_list_provider.dart';
import 'package:hscode_auditor/features/invoice/domain/entities/invoice_entity.dart';

class AuditHistoryScreen extends ConsumerWidget {
  const AuditHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(auditFilterProvider);
    final invoiceListAsync = ref.watch(invoiceListProvider);

    return Scaffold(
      backgroundColor: TariffColors.navyDeep,
      appBar: AppBar(
        backgroundColor: TariffColors.navyMid,
        elevation: 0,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audit Archive', style: TextStyle(color: TariffColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            Text('HISTORICAL MANIFESTS', style: TextStyle(color: TariffColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: TariffColors.divider, height: 1),
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(ref, filter),
          Expanded(
            child: invoiceListAsync.when(
              data: (invoices) {
                final filtered = _applyFilter(invoices, filter);
                if (filtered.isEmpty) return _buildEmptyState();
                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _buildHistoryCard(context, ref, filtered[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: TariffColors.amberPending)),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(WidgetRef ref, AuditFilter activeFilter) {
    return Container(
      height: 60,
      color: TariffColors.navyMid,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _filterChip(ref, 'ALL', AuditFilter.all, activeFilter == AuditFilter.all),
          _filterChip(ref, 'SYNCED', AuditFilter.synced, activeFilter == AuditFilter.synced),
          _filterChip(ref, 'PENDING', AuditFilter.offlineDraft, activeFilter == AuditFilter.offlineDraft),
        ],
      ),
    );
  }

  Widget _filterChip(WidgetRef ref, String label, AuditFilter filter, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSelected ? TariffColors.navyDeep : TariffColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900)),
        selected: isSelected,
        onSelected: (val) => ref.read(auditFilterProvider.notifier).state = filter,
        backgroundColor: TariffColors.navySurface,
        selectedColor: TariffColors.amberPending,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        showCheckmark: false,
        side: BorderSide(color: isSelected ? TariffColors.amberPending : TariffColors.cardBorder),
      ),
    );
  }

  List<InvoiceEntity> _applyFilter(List<InvoiceEntity> invoices, AuditFilter filter) {
    switch (filter) {
      case AuditFilter.all:
        return invoices;
      case AuditFilter.synced:
        return invoices.where((i) => i.status == 'synced').toList();
      case AuditFilter.offlineDraft:
        return invoices.where((i) => i.status == 'offlineDraft').toList();
    }
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text('No audits found for this filter.', style: TextStyle(color: TariffColors.textMuted)),
    );
  }

  Widget _buildHistoryCard(BuildContext context, WidgetRef ref, InvoiceEntity invoice) {
    final isSynced = invoice.status == 'synced';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: TariffColors.navySurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: const BorderSide(color: TariffColors.cardBorder)
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => Navigator.of(context).pushNamed('/audit-result', arguments: invoice.id),
        title: Text(invoice.consignee, style: const TextStyle(color: TariffColors.textPrimary, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(invoice.cargoDescription, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TariffColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                _miniBadge(invoice.hsCode, TariffColors.amberPending),
                const SizedBox(width: 8),
                _miniBadge(invoice.status.toUpperCase(), isSynced ? TariffColors.greenVerified : TariffColors.textMuted),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: TariffColors.textMuted),
      ),
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), 
        borderRadius: BorderRadius.circular(4), 
        border: Border.all(color: color.withValues(alpha: 0.2))
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}
