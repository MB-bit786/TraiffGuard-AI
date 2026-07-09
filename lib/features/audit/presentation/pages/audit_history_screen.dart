import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/audit_filter_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/invoice_list_provider.dart';
import 'package:hscode_auditor/features/invoice/domain/entities/invoice_entity.dart';

class AuditHistoryScreen extends ConsumerStatefulWidget {
  const AuditHistoryScreen({super.key});

  @override
  ConsumerState<AuditHistoryScreen> createState() => _AuditHistoryScreenState();
}

class _AuditHistoryScreenState extends ConsumerState<AuditHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          _buildSearchBar(),
          _buildFilterBar(ref, filter),
          Expanded(
            child: invoiceListAsync.when(
              data: (invoices) {
                final filtered = _applyFilter(invoices, filter, _searchQuery);
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
        style: const TextStyle(color: TariffColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search consignee, cargo, or HS code...',
          hintStyle: const TextStyle(color: TariffColors.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, color: TariffColors.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: TariffColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: TariffColors.navySurface,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TariffColors.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TariffColors.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TariffColors.amberPending, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(WidgetRef ref, AuditFilter activeFilter) {
    return Container(
      height: 60,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _filterChip(ref, 'All Results', AuditFilter.all, activeFilter == AuditFilter.all),
          _filterChip(ref, 'Verified', AuditFilter.synced, activeFilter == AuditFilter.synced),
          _filterChip(ref, 'Pending Sync', AuditFilter.offlineDraft, activeFilter == AuditFilter.offlineDraft),
        ],
      ),
    );
  }

  Widget _filterChip(WidgetRef ref, String label, AuditFilter filter, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? TariffColors.navyDeep : TariffColors.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        ),
        selected: isSelected,
        onSelected: (val) => ref.read(auditFilterProvider.notifier).state = filter,
        backgroundColor: TariffColors.navySurface,
        selectedColor: TariffColors.amberPending,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        showCheckmark: false,
        side: BorderSide(color: isSelected ? TariffColors.amberPending : TariffColors.cardBorder),
      ),
    );
  }

  List<InvoiceEntity> _applyFilter(List<InvoiceEntity> invoices, AuditFilter filter, String query) {
    List<InvoiceEntity> result = invoices;

    // Apply Filter
    switch (filter) {
      case AuditFilter.all:
        break;
      case AuditFilter.synced:
        result = result.where((i) => i.status == 'synced').toList();
        break;
      case AuditFilter.offlineDraft:
        result = result.where((i) => i.status == 'offlineDraft').toList();
        break;
    }

    // Apply Search Query
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      result = result.where((i) =>
          i.consignee.toLowerCase().contains(q) ||
          i.cargoDescription.toLowerCase().contains(q) ||
          i.hsCode.toLowerCase().contains(q)).toList();
    }

    return result;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: TariffColors.textMuted),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isEmpty ? 'No records in archive' : 'No matching audits found',
            style: const TextStyle(color: TariffColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, WidgetRef ref, InvoiceEntity invoice) {
    final isSynced = invoice.status == 'synced';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: TariffColors.navySurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14), 
        side: const BorderSide(color: TariffColors.cardBorder)
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/audit-result', arguments: invoice.id),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHighlightedText(invoice.consignee, _searchQuery, style: const TextStyle(color: TariffColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    _buildHighlightedText(invoice.cargoDescription, _searchQuery, style: const TextStyle(color: TariffColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildMiniBadgeWithHighlight(invoice.hsCode, _searchQuery, TariffColors.amberPending),
                        const SizedBox(width: 8),
                        _miniBadge(isSynced ? 'VERIFIED' : 'PENDING', isSynced ? TariffColors.greenVerified : TariffColors.textMuted),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: TariffColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, {required TextStyle style}) {
    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();
    int start = 0;
    int indexOfMatch;

    while ((indexOfMatch = lowerText.indexOf(lowerQuery, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfMatch)));
      }
      spans.add(TextSpan(
        text: text.substring(indexOfMatch, indexOfMatch + query.length),
        style: TextStyle(
          color: TariffColors.amberPending,
          fontWeight: FontWeight.bold,
          backgroundColor: TariffColors.amberPending.withValues(alpha: 0.15),
        ),
      ));
      start = indexOfMatch + query.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style.copyWith(fontFamily: 'Roboto'),
        children: spans,
      ),
    );
  }

  Widget _buildMiniBadgeWithHighlight(String text, String query, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), 
        borderRadius: BorderRadius.circular(6), 
        border: Border.all(color: color.withValues(alpha: 0.2))
      ),
      child: _buildHighlightedText(text, query, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), 
        borderRadius: BorderRadius.circular(6), 
        border: Border.all(color: color.withValues(alpha: 0.2))
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }
}
