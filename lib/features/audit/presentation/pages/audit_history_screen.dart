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

  Future<void> _trashInvoice(InvoiceEntity invoice) async {
    final repository = ref.read(invoiceRepositoryProvider);
    await repository.softDeleteInvoice(invoice.id, true);
    ref.read(invoiceListProvider.notifier).fetchInvoices();

    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Audit moved to Trash Bin'),
        backgroundColor: TariffColors.navyElevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: TariffColors.amberPending,
          onPressed: () async {
            await repository.softDeleteInvoice(invoice.id, false);
            ref.read(invoiceListProvider.notifier).fetchInvoices();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeFilter = ref.watch(auditFilterProvider);
    final invoiceListAsync = ref.watch(invoiceListProvider);

    return Scaffold(
      backgroundColor: TariffColors.navyDeep,
      appBar: AppBar(
        backgroundColor: TariffColors.navyMid,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Audit History',
          style: TextStyle(
            color: TariffColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: () => ref.read(invoiceListProvider.notifier).syncWithCloud(),
            icon: const Icon(Icons.refresh_rounded, color: TariffColors.textMuted, size: 22),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: TariffColors.divider, height: 1),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(activeFilter),
          const SizedBox(height: 8),
          Expanded(
            child: invoiceListAsync.when(
              data: (invoices) {
                final filtered = _getFilteredInvoices(invoices, activeFilter);
                if (filtered.isEmpty) return _buildEmptyState();
                
                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final invoice = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Dismissible(
                        key: Key(invoice.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) => _trashInvoice(invoice),
                        background: Container(
                          padding: const EdgeInsets.only(right: 20),
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(
                            color: TariffColors.crimsonRisk,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.delete_sweep_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        child: _buildInvoiceCard(invoice),
                      ),
                    );
                  },
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
        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
        style: const TextStyle(color: TariffColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search consignee or cargo...',
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
            borderSide: const BorderSide(color: TariffColors.inputBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TariffColors.inputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TariffColors.amberPending, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(AuditFilter activeFilter) {
    final filters = [
      (AuditFilter.all, 'All History', Icons.all_inbox_rounded),
      (AuditFilter.synced, 'Verified', Icons.cloud_done_rounded),
      (AuditFilter.offlineDraft, 'Local Drafts', Icons.cloud_off_rounded),
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = activeFilter == filter.$1;
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => ref.read(auditFilterProvider.notifier).state = filter.$1,
              child: AnimatedScale(
                scale: isSelected ? 1.02 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? TariffColors.amberPending : TariffColors.navySurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? TariffColors.amberPending : TariffColors.cardBorder,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        filter.$3, 
                        size: 14, 
                        color: isSelected ? TariffColors.navyDeep : TariffColors.textSecondary
                      ),
                      const SizedBox(width: 6),
                      Text(
                        filter.$2,
                        style: TextStyle(
                          color: isSelected ? TariffColors.navyDeep : TariffColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<InvoiceEntity> _getFilteredInvoices(List<InvoiceEntity> invoices, AuditFilter filter) {
    return invoices.where((invoice) {
      final matchesStatus = filter == AuditFilter.all || 
          (filter == AuditFilter.synced && invoice.status == 'synced') ||
          (filter == AuditFilter.offlineDraft && invoice.status == 'offlineDraft');
      
      if (!matchesStatus) return false;

      if (_searchQuery.isEmpty) return true;

      return invoice.consignee.toLowerCase().contains(_searchQuery) ||
             invoice.cargoDescription.toLowerCase().contains(_searchQuery) ||
             invoice.hsCode.toLowerCase().contains(_searchQuery) ||
             invoice.id.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: TariffColors.navyElevated.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'No matching records',
            style: TextStyle(color: TariffColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try adjusting your search or filter.',
            style: TextStyle(color: TariffColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(InvoiceEntity invoice) {
    final isSynced = invoice.status == 'synced';
    final accentColor = isSynced ? TariffColors.greenVerified : TariffColors.amberPending;
    final bgColor = isSynced ? TariffColors.greenVerifiedSoft : TariffColors.amberPendingSoft;
    final borderColor = isSynced
        ? TariffColors.greenVerifiedBorder.withValues(alpha: 0.5)
        : TariffColors.amberPendingBorder.withValues(alpha: 0.5);

    return Card(
      margin: EdgeInsets.zero,
      color: TariffColors.navySurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: TariffColors.cardBorder, width: 1),
      ),
      child: InkWell(
          onTap: () => Navigator.of(context).pushNamed('/audit-result', arguments: invoice.id),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _buildHighlightedText(
                        invoice.consignee, 
                        _searchQuery,
                        style: const TextStyle(
                          color: TariffGuardColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        isSynced ? 'SYNCED' : 'DRAFT',
                        style: TextStyle(color: accentColor, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildHighlightedText(
                  invoice.cargoDescription,
                  _searchQuery,
                  maxLines: 2,
                  style: const TextStyle(color: TariffColors.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: TariffColors.divider),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.tag_rounded, size: 14, color: TariffColors.textMuted),
                    const SizedBox(width: 6),
                    _buildHighlightedText(
                      invoice.hsCode,
                      _searchQuery,
                      style: const TextStyle(color: TariffColors.amberPending, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    const Icon(Icons.access_time_rounded, size: 12, color: TariffColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      invoice.timestamp,
                      style: const TextStyle(color: TariffColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildHighlightedText(String text, String query, {required TextStyle style, int? maxLines}) {
    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
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
        style: style.copyWith(
          backgroundColor: TariffColors.amberPending.withValues(alpha: 0.3),
          color: TariffColors.amberPending,
        ),
      ));
      start = indexOfMatch + query.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return RichText(
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
      text: TextSpan(
        style: style,
        children: spans,
      ),
    );
  }
}

class TariffGuardColors {
  static const Color textPrimary = Color(0xFFF1F4F9);
}
