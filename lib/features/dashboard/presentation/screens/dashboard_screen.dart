import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/core/theme/tariff_colors.dart';
import 'package:hscode_auditor/features/invoice/domain/models/invoice_model.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/connection_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/invoice_list_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/audit_filter_provider.dart';
import 'package:hscode_auditor/features/invoice/data/repositories/sql_invoice_repository.dart';
import 'package:hscode_auditor/features/search/presentation/screens/tariff_directory_screen.dart';

import '../../../../core/services/auto_sync_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _navigateToHistory() {
    // Reset filter to All before navigating
    ref.read(auditFilterProvider.notifier).state = AuditFilter.all;
    Navigator.of(context).pushNamed('/audit-history');
  }

  Future<void> _trashInvoice(InvoiceModel invoice) async {
    final repository = ref.read(sqlInvoiceRepositoryProvider);
    
    // 1. Set isDeleted = 1 in DB
    await repository.softDeleteInvoice(invoice.id, true);
    
    // 2. Refresh local provider
    ref.read(invoiceListProvider.notifier).fetchInvoices();

    if (!mounted) return;

    // 3. Show SnackBar with Undo
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
  Widget build(BuildContext context) {
    // Only rebuild the whole screen when the connection status changes
    final connection = ref.watch(connectionProvider);
    final isOnline = connection.isOnline;

    return Scaffold(
      backgroundColor: TariffColors.navyDeep,
      appBar: _buildAppBar(isOnline, connection.isManual),
      drawer: _buildDrawer(context),
      body: _buildScrollableBody(),
      floatingActionButton: _buildFAB(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget _buildAppBar(bool isOnline, bool isManual) {
    return AppBar(
      backgroundColor: TariffColors.navyMid,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: TariffColors.amberPending,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: TariffColors.navyDeep,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Flexible(
                child: Text(
                  'TariffGuard',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: TariffColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Text(
                ' AI',
                style: TextStyle(
                  color: TariffColors.amberPending,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Text(
            'Dashboard',
            style: TextStyle(
              color: TariffColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: () => ref.read(connectionProvider.notifier).toggle(),
          onLongPress: () {
            ref.read(connectionProvider.notifier).resetToAuto();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Network detection reset to Auto')),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isOnline
                  ? TariffColors.greenVerifiedSoft
                  : TariffColors.amberPendingSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOnline
                    ? TariffColors.greenVerifiedBorder
                    : TariffColors.amberPendingBorder,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isManual)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.edit_location_alt_rounded, size: 10, color: TariffColors.textSecondary),
                  ),
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Opacity(
                    opacity: isOnline ? 1.0 : _pulseAnimation.value,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? TariffColors.greenVerified
                            : TariffColors.amberPending,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    color: isOnline
                        ? TariffColors.greenVerified
                        : TariffColors.amberPending,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            ref.read(invoiceListProvider.notifier).fetchInvoices();
            ref.read(autoSyncServiceProvider).syncPendingAudits();
          },
          icon: const Icon(Icons.refresh_rounded),
          color: TariffColors.textSecondary,
          iconSize: 22,
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: TariffColors.divider,
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: TariffColors.navyDeep,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: TariffColors.navyMid,
              border: Border(bottom: BorderSide(color: TariffColors.divider, width: 1)),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: TariffColors.amberPending,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: TariffColors.navyDeep,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'TariffGuard',
                    style: TextStyle(
                      color: TariffColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_rounded, color: TariffColors.textSecondary),
            title: const Text(
              'Dashboard',
              style: TextStyle(color: TariffColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded, color: TariffColors.textSecondary),
            title: const Text(
              'Tariff Directory Lookup',
              style: TextStyle(color: TariffColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TariffDirectoryScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: TariffColors.textSecondary),
            title: const Text(
              'Trash Bin',
              style: TextStyle(color: TariffColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/trash');
            },
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              'TariffGuard AI v1.0.0',
              style: TextStyle(color: TariffColors.textMuted, fontSize: 11),
            ),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'RECENT AUDITS',
            style: TextStyle(
              color: TariffColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
          InkWell(
            onTap: () => _navigateToHistory(),
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                'View All →',
                style: TextStyle(
                  color: TariffColors.amberPending,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Optimized list that uses local Consumer to prevent whole-screen rebuilds
  /// on data fetching or list updates.
  Widget _buildOptimizedInvoiceList() {
    return Consumer(
      builder: (context, ref, child) {
        final invoiceListAsync = ref.watch(invoiceListProvider);
        
        return invoiceListAsync.when(
          data: (invoices) {
            // Dashboard always shows the most recent 5 items across ALL categories
            // to give a quick overview of latest activity.
            if (invoices.isEmpty) {
              return const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No audits found.\nStart by adding a new invoice.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: TariffColors.textMuted, fontSize: 14),
                  ),
                ),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final invoice = invoices[index];
                  return Dismissible(
                    key: Key(invoice.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) => _trashInvoice(invoice),
                    background: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                  );
                },
                childCount: invoices.length > 5 ? 5 : invoices.length,
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: TariffColors.amberPending)),
          ),
          error: (err, st) => SliverFillRemaining(
            child: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
          ),
        );
      },
    );
  }

  Widget _buildInvoiceCard(InvoiceModel invoice) {
    final isSynced = invoice.status == InvoiceSyncStatus.synced;
    final accentColor =
        isSynced ? TariffColors.greenVerified : TariffColors.amberPending;
    final bgColor =
        isSynced ? TariffColors.greenVerifiedSoft : TariffColors.amberPendingSoft;
    final borderColor = isSynced
        ? TariffColors.greenVerifiedBorder.withValues(alpha: 0.5)
        : TariffColors.amberPendingBorder.withValues(alpha: 0.5);
    final cloudIcon =
        isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Card(
        color: TariffColors.navySurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: TariffColors.cardBorder, width: 1),
        ),
        child: InkWell(
          onTap: () => Navigator.of(context).pushNamed('/audit-result', arguments: invoice.id),
          borderRadius: BorderRadius.circular(14),
          splashColor: accentColor.withValues(alpha: 0.05),
          highlightColor: accentColor.withValues(alpha: 0.03),
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
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Icon(cloudIcon, color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.consignee,
                            style: const TextStyle(
                              color: TariffColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            invoice.cargoDescription,
                            style: const TextStyle(
                              color: TariffColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: TariffColors.divider),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Flexible(
                      child: _MetaChip(
                        label: 'HS CODE',
                        value: invoice.hsCode,
                        valueColor: isSynced
                            ? TariffColors.textPrimary
                            : TariffColors.amberPending,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: _MetaChip(
                        label: 'DUTY',
                        value: invoice.dutyRate,
                        valueColor: TariffColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: TariffColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          invoice.timestamp,
                          style: const TextStyle(
                            color: TariffColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  invoice.id,
                  style: const TextStyle(
                    color: TariffColors.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () async {
        await Navigator.of(context).pushNamed('/invoice-form');
        ref.read(invoiceListProvider.notifier).fetchInvoices();
      },
      backgroundColor: TariffColors.amberPending,
      foregroundColor: TariffColors.navyDeep,
      elevation: 4,
      icon: const Icon(Icons.add_rounded, size: 22),
      label: const Text(
        'New Audit',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: TariffColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: value.contains('.') ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}
