import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/connection_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/invoice_list_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/dashboard_stats_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/audit_filter_provider.dart';
import '../../../invoice/domain/entities/invoice_entity.dart';
import '../../../search/presentation/pages/tariff_directory_screen.dart';
import 'package:hscode_auditor/core/util/auth_service.dart';
import 'package:hscode_auditor/core/util/app_constants.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(invoiceListProvider.notifier).syncWithCloud();
    });
  }

  void _navigateToHistory() {
    ref.read(auditFilterProvider.notifier).state = AuditFilter.all;
    Navigator.of(context).pushNamed('/audit-history');
  }

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
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectionProvider).isOnline;

    return Scaffold(
      backgroundColor: TariffColors.navyDeep,
      drawer: _buildSideDrawer(),
      appBar: _buildAppBar(isOnline),
      body: _buildScrollableBody(),
      floatingActionButton: _buildFab(),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isOnline) {
    final user = ref.watch(authStateProvider).value;

    return AppBar(
      backgroundColor: TariffColors.navyMid,
      elevation: 0,
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TariffGuard Intelligence',
            style: TextStyle(color: TariffColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(
            user?.email ?? 'OPERATOR SESSION',
            style: const TextStyle(color: TariffColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
          ),
        ],
      ),
      actions: [
        _buildConnectionBadge(isOnline),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: TariffColors.divider, height: 1),
      ),
    );
  }

  Widget _buildConnectionBadge(bool isOnline) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline ? TariffColors.greenVerifiedSoft : TariffColors.amberPendingSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isOnline ? TariffColors.greenVerifiedBorder.withValues(alpha: 0.5) : TariffColors.amberPendingBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: isOnline ? TariffColors.greenVerified : TariffColors.amberPending, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(color: isOnline ? TariffColors.greenVerified : TariffColors.amberPending, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSideDrawer() {
    return Drawer(
      backgroundColor: TariffColors.navyMid,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: TariffColors.navyDeep),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_rounded, color: TariffColors.amberPending, size: 40),
                  const SizedBox(height: 12),
                  const Text('TARIFFGUARD AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  Text('${AppConstants.appVersion.toUpperCase()} (STABLE)', style: const TextStyle(color: TariffColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.history_rounded, color: TariffColors.textSecondary),
            title: const Text('Audit History', style: TextStyle(color: TariffColors.textPrimary, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              _navigateToHistory();
            },
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded, color: TariffColors.textSecondary),
            title: const Text('Tariff Directory Lookup', style: TextStyle(color: TariffColors.textPrimary, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TariffDirectoryScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: TariffColors.textSecondary),
            title: const Text('Trash Bin', style: TextStyle(color: TariffColors.textPrimary, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/trash');
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text('${AppConstants.appName} ${AppConstants.appVersion}', style: const TextStyle(color: TariffColors.textMuted, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableBody() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildSectionHeader()),
        _buildOptimizedInvoiceList(),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Operational Overview', style: TextStyle(color: TariffColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              IconButton(
                onPressed: () => ref.read(invoiceListProvider.notifier).syncWithCloud(),
                icon: const Icon(Icons.refresh_rounded, color: TariffColors.textMuted, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStatsGrid(),
          const SizedBox(height: 32),
          const Text('RECENT CARGO MANIFESTS', style: TextStyle(color: TariffColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = ref.watch(dashboardStatsProvider);
    return Row(
      children: [
        Expanded(child: _buildStatCard('TOTAL AUDITS', stats.total.toString(), Icons.analytics_outlined, TariffColors.textPrimary)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('SYNCED', stats.synced.toString(), Icons.cloud_done_outlined, TariffColors.greenVerified)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('PENDING', stats.drafts.toString(), Icons.bolt_rounded, TariffColors.amberPending)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: TariffColors.navySurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: TariffColors.cardBorder, width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.8), size: 20),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: TariffColors.textMuted, fontSize: 9, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildOptimizedInvoiceList() {
    final invoiceListAsync = ref.watch(invoiceListProvider);
    return invoiceListAsync.when(
      data: (invoices) {
        if (invoices.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No manifests found.\nTap the lightning bolt to start.', textAlign: TextAlign.center, style: TextStyle(color: TariffColors.textMuted, height: 1.5))),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final invoice = invoices[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Dismissible(
                  key: Key('invoice_${invoice.id}'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) => _trashInvoice(invoice),
                  background: Container(
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: TariffColors.crimsonRisk, 
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
                  ),
                  child: _buildInvoiceCard(invoice),
                ),
              );
            },
            childCount: invoices.length,
          ),
        );
      },
      loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: TariffColors.amberPending))),
      error: (err, st) => SliverFillRemaining(child: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white)))),
    );
  }

  Widget _buildInvoiceCard(InvoiceEntity invoice) {
    final isSynced = invoice.status == 'synced';
    final accentColor = isSynced ? TariffColors.greenVerified : TariffColors.amberPending;
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
          onLongPress: () async {
            final repository = ref.read(invoiceRepositoryProvider);
            final audit = await repository.getAuditResultByInvoiceId(invoice.id);
            if (!mounted) return;
            if (audit != null) Navigator.of(context).pushNamed('/edit-audit', arguments: audit);
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSynced ? TariffColors.greenVerifiedSoft : TariffColors.amberPendingSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSynced ? TariffColors.greenVerifiedBorder.withValues(alpha: 0.5) : TariffColors.amberPendingBorder.withValues(alpha: 0.5), width: 1),
                      ),
                      child: Icon(isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(invoice.consignee, style: const TextStyle(color: TariffColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                          const SizedBox(height: 3),
                          Text(invoice.cargoDescription, style: const TextStyle(color: TariffColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(invoice.id.split('-').last, style: const TextStyle(color: TariffColors.textMuted, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(invoice.timestamp.split(' ').first, style: const TextStyle(color: TariffColors.textMuted, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildMiniChip(invoice.hsCode, TariffColors.amberPending),
                    const SizedBox(width: 8),
                    _buildMiniChip(invoice.dutyRate, TariffColors.textSecondary),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildMiniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.3), width: 1)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.of(context).pushNamed('/invoice-form'),
      backgroundColor: TariffColors.amberPending,
      foregroundColor: TariffColors.navyDeep,
      elevation: 4,
      icon: const Icon(Icons.bolt_rounded),
      label: const Text('NEW AUDIT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
    );
  }
}
