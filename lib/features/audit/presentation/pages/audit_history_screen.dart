import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/audit_filter_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/invoice_list_provider.dart';
import 'package:hscode_auditor/features/invoice/domain/entities/invoice_entity.dart';
import 'package:go_router/go_router.dart';
import 'package:hscode_auditor/config/routes/app_routes.dart';

class AuditHistoryScreen extends ConsumerStatefulWidget {
  const AuditHistoryScreen({super.key});

  @override
  ConsumerState<AuditHistoryScreen> createState() => _AuditHistoryScreenState();
}

class _AuditHistoryScreenState extends ConsumerState<AuditHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Reactive: ensure data is synced from cloud when entering history
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(invoiceListProvider.notifier).syncWithCloud();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(auditFilterProvider);
    final invoiceListAsync = ref.watch(invoiceListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? TariffColors.navyMid : const Color(0xFF1565C0),
        elevation: 0,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audit History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            Text('HISTORICAL MANIFESTS', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white.withValues(alpha: 0.1), height: 1),
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
              error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: isDark ? Colors.white : Colors.black))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
        style: TextStyle(color: isDark ? TariffColors.textPrimary : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search consignee, cargo, or HS code...',
          hintStyle: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[400]),
          prefixIcon: Icon(Icons.search_rounded, color: isDark ? TariffColors.textMuted : Colors.grey[400]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? TariffColors.textMuted : Colors.grey[400]),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? TariffColors.navySurface : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? TariffColors.amberPending : const Color(0xFF1565C0), width: 1.5),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? (isDark ? TariffColors.navyDeep : Colors.white) : (isDark ? TariffColors.textSecondary : Colors.black54),
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        ),
        selected: isSelected,
        onSelected: (val) => ref.read(auditFilterProvider.notifier).state = filter,
        backgroundColor: isDark ? TariffColors.navySurface : Colors.grey[200],
        selectedColor: isDark ? TariffColors.amberPending : const Color(0xFF1565C0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        showCheckmark: false,
        side: BorderSide(color: isSelected ? (isDark ? TariffColors.amberPending : const Color(0xFF1565C0)) : (isDark ? TariffColors.cardBorder : Colors.grey[300]!)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? TariffColors.navySurface : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14), 
        side: BorderSide(color: isDark ? TariffColors.cardBorder : Colors.grey[200]!)
      ),
      child: InkWell(
        onTap: () => context.push(AppRoutes.auditResultPath(invoice.id)),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHighlightedText(
                      invoice.consignee, 
                      _searchQuery, 
                      style: TextStyle(color: isDark ? TariffColors.textPrimary : Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)
                    ),
                    const SizedBox(height: 4),
                    _buildHighlightedText(
                      invoice.cargoDescription, 
                      _searchQuery, 
                      style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.black54, fontSize: 13)
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildMiniBadgeWithHighlight(invoice.hsCode, _searchQuery, TariffColors.amberPending),
                        const SizedBox(width: 8),
                        _miniBadge(isSynced ? 'VERIFIED' : 'PENDING', isSynced ? TariffColors.greenVerified : (isDark ? TariffColors.textMuted : Colors.grey[400]!)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: isDark ? TariffColors.textMuted : Colors.grey[300]),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), 
        borderRadius: BorderRadius.circular(6), 
        border: Border.all(color: color.withValues(alpha: isDark ? 0.2 : 0.4))
      ),
      child: _buildHighlightedText(text, query, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _miniBadge(String text, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), 
        borderRadius: BorderRadius.circular(6), 
        border: Border.all(color: color.withValues(alpha: isDark ? 0.2 : 0.4))
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }
}
