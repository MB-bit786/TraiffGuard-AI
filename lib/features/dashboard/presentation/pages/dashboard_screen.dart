import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/connection_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/invoice_list_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/dashboard_stats_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/audit_filter_provider.dart';
import 'package:hscode_auditor/features/invoice/domain/entities/invoice_entity.dart';
import 'package:hscode_auditor/features/invoice/presentation/providers/invoice_providers.dart' as inv;
import 'package:hscode_auditor/features/auth/presentation/providers/auth_providers.dart';
import 'package:hscode_auditor/core/constants/app_constants.dart';
import 'package:go_router/go_router.dart';
import 'package:hscode_auditor/config/routes/app_routes.dart';

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
    context.push(AppRoutes.auditHistory);
  }

  Future<void> _trashInvoice(InvoiceEntity invoice) async {
    final repository = ref.read(inv.invoiceRepositoryProvider);
    final user = ref.read(authStateProvider).value;
    final userId = user?.uid ?? 'anonymous';
    
    await repository.softDeleteInvoice(invoice.id, userId, true);
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
            await repository.softDeleteInvoice(invoice.id, userId, false);
            ref.read(invoiceListProvider.notifier).fetchInvoices();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(connectionProvider);
    final isOnline = connection.effectivelyOnline;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: _buildSideDrawer(),
      appBar: _buildAppBar(isOnline, connection.isManualOverride),
      body: _buildScrollableBody(),
      floatingActionButton: _buildFab(),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isOnline, bool isManual) {
    final user = ref.watch(authStateProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      backgroundColor: theme.appBarTheme.backgroundColor,
      elevation: 0,
      centerTitle: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
            ),
            child: Image.asset(
              'assets/images/logo.png',
              width: 34,
              height: 34,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.shield_rounded,
                  color: isDark ? TariffColors.amberPending : Colors.white,
                  size: 20,
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TariffGuard',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? TariffColors.textPrimary : Colors.white, 
                    fontSize: 15, 
                    fontWeight: FontWeight.w700
                  ),
                ),
                Text(
                  user?.email ?? 'OPERATOR',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? TariffColors.textMuted : Colors.white70, 
                    fontSize: 8, 
                    fontWeight: FontWeight.w700, 
                    letterSpacing: 0.5
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _buildConnectionBadge(isOnline, isManual),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: isDark ? TariffColors.divider : Colors.white24, height: 1),
      ),
    );
  }

  Widget _buildConnectionBadge(bool isOnline, bool isManual) {
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
            isManual ? (isOnline ? 'FORCED ON' : 'FORCED OFF') : (isOnline ? 'ONLINE' : 'OFFLINE'),
            style: TextStyle(color: isOnline ? TariffColors.greenVerified : TariffColors.amberPending, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSideDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Drawer(
      backgroundColor: isDark ? TariffColors.navyMid : Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: isDark ? TariffColors.navyDeep : Colors.blue[900]),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 48,
                    height: 48,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.shield_rounded,
                      color: TariffColors.amberPending,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('TARIFFGUARD AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  Text('${AppConstants.appVersion.toUpperCase()} (STABLE)', style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          _buildDrawerItem(
            icon: Icons.history_rounded,
            title: 'Audit History',
            onTap: () {
              context.pop();
              _navigateToHistory();
            },
          ),
          _buildDrawerItem(
            icon: Icons.menu_book_rounded,
            title: 'Tariff Directory Lookup',
            onTap: () {
              context.pop();
              context.push(AppRoutes.tariffDirectory);
            },
          ),
          _buildDrawerItem(
            icon: Icons.delete_outline_rounded,
            title: 'Trash Bin',
            onTap: () {
              context.pop();
              context.push(AppRoutes.trash);
            },
          ),
          _buildDrawerItem(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {
              context.pop();
              context.push(AppRoutes.settings);
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              '${AppConstants.appName} ${AppConstants.appVersion}', 
              style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[600], fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      leading: Icon(icon, color: isDark ? TariffColors.textSecondary : Colors.blueGrey),
      title: Text(
        title, 
        style: TextStyle(
          color: isDark ? TariffColors.textPrimary : Colors.black87, 
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Operational Overview', 
                style: TextStyle(
                  color: isDark ? TariffColors.textPrimary : Colors.black87, 
                  fontSize: 22, 
                  fontWeight: FontWeight.w800, 
                  letterSpacing: -0.5
                )
              ),
              IconButton(
                onPressed: () => ref.read(invoiceListProvider.notifier).syncWithCloud(),
                icon: Icon(
                  Icons.refresh_rounded, 
                  color: isDark ? TariffColors.textMuted : Colors.grey[400], 
                  size: 22
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStatsGrid(),
          const SizedBox(height: 32),
          Text(
            'RECENT CARGO MANIFESTS', 
            style: TextStyle(
              color: isDark ? TariffColors.textMuted : Colors.grey[600], 
              fontSize: 10, 
              fontWeight: FontWeight.w800, 
              letterSpacing: 2.0
            )
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = ref.watch(dashboardStatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Expanded(child: _buildStatCard('TOTAL AUDITS', stats.total.toString(), Icons.analytics_outlined, isDark ? TariffColors.textPrimary : const Color(0xFF1565C0))),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('SYNCED', stats.synced.toString(), Icons.cloud_done_outlined, TariffColors.greenVerified)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('PENDING', stats.drafts.toString(), Icons.bolt_rounded, TariffColors.amberPending)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? TariffColors.navySurface : Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(
          color: isDark ? TariffColors.cardBorder : Colors.grey[300]!, 
          width: 1
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.8), size: 20),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(color: isDark ? color : color.withValues(alpha: 0.9), fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[500], fontSize: 9, fontWeight: FontWeight.w800)),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      color: isDark ? TariffColors.navySurface : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? TariffColors.cardBorder : Colors.grey[200]!, width: 1),
      ),
      child: InkWell(
          onTap: () => context.push(AppRoutes.auditResultPath(invoice.id)),
          onLongPress: () async {
            final repository = ref.read(inv.invoiceRepositoryProvider);
            final user = ref.read(authStateProvider).value;
            final userId = user?.uid ?? 'anonymous';
            final audit = await repository.getAuditResultByInvoiceId(invoice.id, userId);
            if (!mounted) return;
            if (audit != null) context.push(AppRoutes.editAuditPath(invoice.id));
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
                        color: isSynced 
                            ? (isDark ? TariffColors.greenVerifiedSoft : Colors.green[50]) 
                            : (isDark ? TariffColors.amberPendingSoft : Colors.amber[50]),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSynced 
                              ? TariffColors.greenVerifiedBorder.withValues(alpha: 0.5) 
                              : TariffColors.amberPendingBorder.withValues(alpha: 0.5), 
                          width: 1
                        ),
                      ),
                      child: Icon(
                        isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, 
                        color: accentColor, 
                        size: 20
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.consignee, 
                            style: TextStyle(
                              color: isDark ? TariffColors.textPrimary : Colors.black87, 
                              fontSize: 15, 
                              fontWeight: FontWeight.w700, 
                              letterSpacing: 0.2
                            )
                          ),
                          const SizedBox(height: 3),
                          Text(
                            invoice.cargoDescription, 
                            style: TextStyle(
                              color: isDark ? TariffColors.textSecondary : Colors.black54, 
                              fontSize: 13
                            ), 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          invoice.id.split('-').last, 
                          style: TextStyle(
                            color: isDark ? TariffColors.textMuted : Colors.grey[400], 
                            fontSize: 10, 
                            fontFamily: 'monospace', 
                            fontWeight: FontWeight.bold
                          )
                        ),
                        const SizedBox(height: 4),
                        Text(
                          invoice.timestamp.split(' ').first, 
                          style: TextStyle(
                            color: isDark ? TariffColors.textMuted : Colors.grey[400], 
                            fontSize: 10
                          )
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMiniChip(invoice.hsCode, TariffColors.amberPending),
                    _buildMiniChip(invoice.dutyRate, isDark ? TariffColors.textSecondary : Colors.blueGrey),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildMiniChip(String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.1 : 0.08), 
        borderRadius: BorderRadius.circular(6), 
        border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.2), width: 1)
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: () => context.push(AppRoutes.invoiceForm),
      backgroundColor: TariffColors.amberPending,
      foregroundColor: TariffColors.navyDeep,
      elevation: 4,
      icon: const Icon(Icons.bolt_rounded),
      label: const Text('NEW AUDIT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
    );
  }
}
