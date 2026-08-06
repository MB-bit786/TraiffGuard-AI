import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/features/audit/domain/entities/hs_audit_result_entity.dart';
import 'package:hscode_auditor/features/audit/data/models/hs_audit_result_model.dart';
import 'package:hscode_auditor/features/audit/presentation/providers/audit_detail_provider.dart';
import 'package:hscode_auditor/core/services/pdf_export_service.dart';
import 'package:hscode_auditor/core/constants/app_constants.dart';

import 'package:go_router/go_router.dart';
import 'package:hscode_auditor/config/routes/app_routes.dart';
import 'package:hscode_auditor/features/invoice/presentation/providers/invoice_providers.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/invoice_list_provider.dart';
import 'package:hscode_auditor/features/auth/presentation/providers/auth_providers.dart';

class AuditResultScreen extends ConsumerWidget {
  const AuditResultScreen({
    super.key,
    this.result,
    this.activeInvoiceId,
  });

  final HsAuditResultEntity? result;
  final String? activeInvoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? currentInvoiceId = activeInvoiceId;

    if (currentInvoiceId != null) {
      final detailAsync = ref.watch(auditDetailProvider(currentInvoiceId));
      
      return detailAsync.when(
        data: (fetchedResult) {
          if (fetchedResult == null) {
            if (result != null) return _buildScaffold(context, ref, result!);
            return _buildErrorScaffold(context, 'Audit report not found.');
          }
          return _buildScaffold(context, ref, fetchedResult);
        },
        loading: () => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: const Center(child: CircularProgressIndicator(color: TariffColors.amberPending)),
        ),
        error: (err, _) => _buildErrorScaffold(context, 'Critical: $err'),
      );
    }

    if (result != null) return _buildScaffold(context, ref, result!);

    return _buildErrorScaffold(context, 'Invalid state: No ID provided.');
  }

  Widget _buildScaffold(BuildContext context, WidgetRef ref, HsAuditResultEntity finalResult) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context, ref, finalResult),
      body: _buildBody(context, ref, finalResult),
      bottomNavigationBar: _buildBottomBar(context, ref, finalResult),
    );
  }

  Widget _buildErrorScaffold(BuildContext context, String message) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? TariffColors.navyMid : const Color(0xFF1565C0),
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.push(AppRoutes.dashboard),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: TariffColors.crimsonRisk, size: 64),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? TariffColors.textPrimary : Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? TariffColors.navyElevated : const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref, HsAuditResultEntity finalResult) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      backgroundColor: isDark ? TariffColors.navyMid : const Color(0xFF1565C0),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Audit Result',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          Text(
            'CUSTOMS CLASSIFICATION REPORT',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.8),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            context.push(AppRoutes.editAuditPath(finalResult.invoiceNumber));
          },
          icon: const Icon(Icons.edit_note_rounded, color: TariffColors.amberPending, size: 24),
          tooltip: 'Edit Audit',
        ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'delete') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: isDark ? TariffColors.navyMid : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!)),
                  title: Text('Delete Audit Report?', style: TextStyle(color: isDark ? TariffColors.textPrimary : Colors.black87, fontWeight: FontWeight.bold)),
                  content: Text('This will move the audit record to the warehouse trash. You can restore it later from settings.', style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.black54, fontSize: 14)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('CANCEL', style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[600], fontWeight: FontWeight.w600))),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: TariffColors.crimsonRisk, fontWeight: FontWeight.w900))),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                try {
                  final userId = ref.read(authStateProvider).value?.uid ?? 'anonymous';
                  await ref.read(invoiceUseCasesProvider).deleteInvoice(userId, finalResult.invoiceNumber);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('🗑️ Audit moved to Trash', style: TextStyle(fontWeight: FontWeight.w600)),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                    ref.invalidate(invoiceListProvider);
                    context.pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
            }
          },
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
          color: isDark ? TariffColors.navyMid : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: isDark ? const BorderSide(color: TariffColors.cardBorder) : BorderSide(color: Colors.grey[200]!)),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline_rounded, color: TariffColors.crimsonRisk, size: 18),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Delete Audit', 
                      style: TextStyle(color: TariffColors.crimsonRisk),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, HsAuditResultEntity result) {
    if (result.riskLevel == RiskLevel.invalidInput) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildRiskWarningCard(context, result),
          const SizedBox(height: 20),
          _buildInvoiceMetaCard(context, result),
        ],
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeroHSCodeCard(context, result),
        const SizedBox(height: 14),
        _buildNationalExtensionCard(context, result),
        const SizedBox(height: 14),
        _buildSeaportRoutingCard(context, result),
        const SizedBox(height: 14),
        _buildConfidenceBar(context, result),
        const SizedBox(height: 14),
        _buildTariffBreakdownCard(context, result),
        const SizedBox(height: 14),
        _buildPortChargesCard(context, result),
        const SizedBox(height: 14),
        _buildRiskWarningCard(context, result),
        const SizedBox(height: 14),
        _buildRequiredDocumentsCard(context, result),
        const SizedBox(height: 14),
        _buildHistorySection(context, ref, result),
        const SizedBox(height: 14),
        _buildInvoiceMetaCard(context, result),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildHistorySection(BuildContext context, WidgetRef ref, HsAuditResultEntity result) {
    final historyAsync = ref.watch(auditHistoryProvider(result.invoiceNumber));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return historyAsync.maybeWhen(
      data: (history) {
        if (history.length <= 1) return const SizedBox.shrink();
        
        return Container(
          decoration: BoxDecoration(
            color: isDark ? TariffColors.navySurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 16, color: TariffColors.amberPending),
                    const SizedBox(width: 8),
                    Text(
                      'CORRECTION HISTORY',
                      style: TextStyle(
                        color: isDark ? TariffColors.textMuted : Colors.grey[600],
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: isDark ? TariffColors.divider : Colors.grey[200]),
              ...history.map((record) {
                final isCurrent = record.recordId == result.recordId;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isCurrent ? (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.blue[50]?.withValues(alpha: 0.3)) : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent ? TariffColors.greenVerified : TariffColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.hsCode,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? TariffColors.textPrimary : Colors.black87,
                                decoration: record.isHidden ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            Text(
                              record.auditTimestamp,
                              style: TextStyle(color: TariffColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: TariffColors.greenVerified.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CURRENT',
                            style: TextStyle(color: TariffColors.greenVerified, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildNationalExtensionCard(BuildContext context, HsAuditResultEntity result) {
    if (result.nationalExtensionCode.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? TariffColors.navySurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? TariffColors.navyElevated : Colors.grey[300]!, width: 1),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: CustomPaint(painter: _GridPainter(isDark: isDark)))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? TariffColors.amberPendingSoft : Colors.amber[50], 
                          borderRadius: BorderRadius.circular(6), 
                          border: Border.all(color: isDark ? TariffColors.amberPendingBorder : Colors.amber[200]!, width: 1)
                        ),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 5,
                          children: [
                            const Icon(Icons.flag_rounded, size: 12, color: TariffColors.amberPending),
                            const Text(
                              'NATIONAL EXTENSION', 
                              style: TextStyle(color: TariffColors.amberPending, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: result.nationalExtensionCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('National HS Code copied'), 
                            behavior: SnackBarBehavior.floating, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                          )
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: isDark ? TariffColors.navyElevated : Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.copy_rounded, size: 16, color: isDark ? TariffColors.textSecondary : Colors.blueGrey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('NATIONAL HS CODE', style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.5)),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    result.nationalExtensionCode,
                    style: TextStyle(
                      color: isDark ? TariffColors.textPrimary : Colors.black87,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(height: 1, color: isDark ? TariffColors.divider : Colors.grey[300]),
                const SizedBox(height: 14),
                Text(
                  result.nationalExtensionDescription,
                  style: TextStyle(
                    color: isDark ? TariffColors.textSecondary : Colors.black87,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeaportRoutingCard(BuildContext context, HsAuditResultEntity result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String origin = result.originPort.isNotEmpty ? result.originPort : result.originCountry;
    final String dest = result.destinationPort.isNotEmpty ? result.destinationPort : result.destinationCountry;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? TariffColors.navySurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DEPARTURE PORT', style: TextStyle(color: TariffColors.textMuted, fontSize: 9, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      origin, 
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward_rounded, color: TariffColors.amberPending, size: 20),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('ARRIVAL PORT', style: TextStyle(color: TariffColors.textMuted, fontSize: 9, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      dest, 
                      textAlign: TextAlign.right, 
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildMiniMeta('SHIPPING', result.shippingMethod)),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniMeta('WEIGHT', '${result.totalWeightKg} KG')),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniMeta('ENTRY', result.plannedMonth)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMeta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: TariffColors.textMuted, fontSize: 8, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      ],
    );
  }

  Widget _buildPortChargesCard(BuildContext context, HsAuditResultEntity result) {
    if (result.portCharges.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? TariffColors.navySurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(Icons.anchor_rounded, size: 16, color: TariffColors.textMuted),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'PORT HANDLING \u0026 SURCHARGES',
                    style: TextStyle(color: TariffColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ...result.portCharges.map((charge) => Column(
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        charge['chargeName'] ?? 'Unknown Handling',
                        style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.black54, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${charge['currency']} ${charge['amount']}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildHeroHSCodeCard(BuildContext context, HsAuditResultEntity result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? TariffColors.navySurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? TariffColors.navyElevated : Colors.grey[300]!, width: 1),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: CustomPaint(painter: _GridPainter(isDark: isDark)))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: _buildVerificationBadge(context, result),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: result.hsCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('HS Code copied'), 
                            behavior: SnackBarBehavior.floating, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                          )
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: isDark ? TariffColors.navyElevated : Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.copy_rounded, size: 16, color: isDark ? TariffColors.textSecondary : Colors.blueGrey),
                      ),
                    ),
                  ],
                ),
                if (result.supersedesId.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.auto_fix_high_rounded, size: 12, color: TariffColors.amberPending),
                      const SizedBox(width: 4),
                      Text(
                        'CORRECTED FROM PREVIOUS CLASSIFICATION',
                        style: TextStyle(color: TariffColors.amberPending, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Text('HS CODE (UNIVERSAL)', style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.5)),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        result.hsCode, 
                        style: TextStyle(
                          color: isDark ? TariffColors.textPrimary : Colors.black87, 
                          fontSize: 52, 
                          fontWeight: FontWeight.w900, 
                          letterSpacing: -1.0, 
                          fontFamily: 'monospace', 
                          height: 1.0
                        ),
                      ),
                    ),
                    if (result.nationalExtensionCode.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: TariffColors.amberPending.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: TariffColors.amberPending.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          result.status == 'synced' ? 'NATIONAL READY' : 'LOCAL ESTIMATE',
                          style: TextStyle(color: TariffColors.amberPending, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (result.verificationStatus == VerificationStatus.verified) ...[
                  Text(result.hsDescriptionOfficial, style: const TextStyle(color: TariffColors.greenVerified, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Official WCO Tariff Nomenclature', style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.grey[600], fontSize: 11, fontStyle: FontStyle.italic)),
                ] else if (result.verificationStatus == VerificationStatus.headingMatch) ...[
                  Text(result.hsDescriptionOfficial, style: const TextStyle(color: TariffColors.amberPending, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Official Heading-Level Description (Partial Match)', style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.grey[600], fontSize: 11, fontStyle: FontStyle.italic)),
                ] else ...[
                  Text(result.hsDescription, style: const TextStyle(color: TariffColors.amberPending, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'AI Predicted Classification', 
                    style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.grey[600], fontSize: 11, fontStyle: FontStyle.italic)
                  ),
                ],
                const SizedBox(height: 4),
                Text(result.chapter, style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w400)),
                const SizedBox(height: 18),
                Container(height: 1, color: isDark ? TariffColors.divider : Colors.grey[300]),
                const SizedBox(height: 14),
                Text(result.cargoDescription, style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.black87, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBadge(BuildContext context, HsAuditResultEntity result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color bgColor;
    Color borderColor;
    Color textColor;
    String label;
    IconData icon;

    if (result.status == 'offlineDraft') {
        bgColor = isDark ? TariffColors.amberPendingSoft : Colors.amber[50]!;
        borderColor = isDark ? TariffColors.amberPendingBorder : Colors.amber[200]!;
        textColor = TariffColors.amberPending;
        label = 'PENDING SYNC';
        icon = Icons.cloud_sync_rounded;
    } else {
        switch (result.verificationStatus) {
          case VerificationStatus.verified:
            bgColor = isDark ? TariffColors.greenVerifiedSoft : Colors.green[50]!;
            borderColor = isDark ? TariffColors.greenVerifiedBorder : Colors.green[200]!;
            textColor = TariffColors.greenVerified;
            label = 'VERIFIED';
            icon = Icons.verified_user_rounded;
            break;
          case VerificationStatus.unverified:
            bgColor = isDark ? TariffColors.amberPendingSoft : Colors.amber[50]!;
            borderColor = isDark ? TariffColors.amberPendingBorder : Colors.amber[200]!;
            textColor = TariffColors.amberPending;
            label = 'UNVERIFIED';
            icon = Icons.help_outline_rounded;
            break;
          case VerificationStatus.headingMatch:
            bgColor = isDark ? TariffColors.amberPendingSoft : Colors.amber[50]!;
            borderColor = isDark ? TariffColors.amberPendingBorder : Colors.amber[200]!;
            textColor = TariffColors.amberPending;
            label = 'HEADING MATCH';
            icon = Icons.account_tree_rounded;
            break;
        }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 5,
        children: [
          Icon(icon, size: 12, color: textColor),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBar(BuildContext context, HsAuditResultEntity result) {
    final score = result.confidenceScore;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = score >= 85 ? TariffColors.greenVerified : score >= 65 ? TariffColors.amberPending : TariffColors.crimsonRisk;

    String scoreLabel = score >= 85 ? 'HIGH (SELF-REPORTED)' : score >= 65 ? 'MEDIUM (SELF-REPORTED)' : 'LOW (SELF-REPORTED)';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? TariffColors.navySurface : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!, width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'MODEL PREDICTION CONFIDENCE', 
                  style: TextStyle(
                    color: isDark ? TariffColors.textMuted : Colors.grey[600], 
                    fontSize: 10, 
                    fontWeight: FontWeight.w700, 
                    letterSpacing: 1.5
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(scoreLabel, style: TextStyle(color: barColor, fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: score / 100, minHeight: 8, backgroundColor: isDark ? TariffColors.navyElevated : Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(barColor)),
          ),
          const SizedBox(height: 8),
          Text(
            score >= 85 ? 'Model reports high probability based on description patterns.' : score >= 65 ? 'Model reports moderate probability; manual verification advised.' : 'Model reports low probability; classification may be inaccurate.',
            style: TextStyle(color: barColor.withValues(alpha: 0.8), fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            'Reported by the AI model; not an independent accuracy measure.',
            style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[500], fontSize: 9, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildTariffBreakdownCard(BuildContext context, HsAuditResultEntity result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(color: isDark ? TariffColors.navySurface : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!, width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.percent_rounded, size: 16, color: TariffColors.amberPending),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'TARIFF & DUTY BREAKDOWN', 
                    style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[600], fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.8),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: isDark ? TariffColors.divider : Colors.grey[200]),
          _TariffRow(label: 'Standard Import Duty', value: result.standardDutyRate, valueColor: isDark ? TariffColors.textPrimary : Colors.black87, showDivider: true),
          _TariffRow(label: 'VAT / GST', value: result.vatRate, valueColor: isDark ? TariffColors.textPrimary : Colors.black87, showDivider: true),
          _TariffRow(label: 'Declared Cargo Value', value: '${result.currency} ${result.declaredValue}', valueColor: isDark ? TariffColors.textSecondary : Colors.grey[700]!, showDivider: true),
          _TariffRow(label: 'Estimated Duty Payable', value: '${result.currency} ${result.estimatedDutyAmount.replaceAll(result.currency, '').trim()}', valueColor: TariffColors.amberPending, showDivider: true, isBold: true),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: isDark ? TariffColors.amberPendingSoft : Colors.amber[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? TariffColors.amberPendingBorder.withValues(alpha: 0.5) : Colors.amber[200]!, width: 1)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('TOTAL TAX BURDEN', style: TextStyle(color: TariffColors.amberPending, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Flexible(child: Text(result.totalTaxBurden, textAlign: TextAlign.right, style: const TextStyle(color: TariffColors.amberPending, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskWarningCard(BuildContext context, HsAuditResultEntity result) {
    final List<String> warnings = List.from(result.complianceWarnings);
    
    // UI-level Risk Escalation: If we have compliance warnings, we should not show "SECURE"
    RiskLevel effectiveRisk = result.riskLevel;
    if (warnings.isNotEmpty && effectiveRisk == RiskLevel.low) {
      effectiveRisk = RiskLevel.medium;
    }

    if (result.verificationStatus == VerificationStatus.unverified) {
      warnings.insert(0, 'UNVERIFIED: HS Code ${result.hsCode} was not found in the local Master Tariff Database. This classification relies solely on AI prediction — please confirm its validity manually.');
      if (effectiveRisk == RiskLevel.low) effectiveRisk = RiskLevel.medium;
    } else if (result.verificationStatus == VerificationStatus.headingMatch) {
      warnings.insert(0, 'PARTIAL MATCH: The exact 6-digit subheading ${result.hsCode} was not found. We matched the nearest 4-digit Heading instead — please confirm the correct subheading before filing.');
      if (effectiveRisk == RiskLevel.low) effectiveRisk = RiskLevel.medium;
    }

    if (warnings.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visuals = _RiskVisuals.fromLevel(effectiveRisk, isDark);

    return Container(
      decoration: BoxDecoration(
        color: visuals.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: visuals.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(visuals.icon, color: visuals.color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    visuals.label,
                    style: TextStyle(color: visuals.color, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: visuals.color.withValues(alpha: 0.15)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: warnings.asMap().entries.map((entry) => Padding(
                padding: EdgeInsets.only(bottom: entry.key < warnings.length - 1 ? 12 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(Icons.circle, size: 6, color: visuals.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value, 
                        style: TextStyle(
                          color: isDark ? TariffColors.textPrimary : Colors.black87, 
                          fontSize: 13, 
                          height: 1.5, 
                          fontWeight: FontWeight.w500
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequiredDocumentsCard(BuildContext context, HsAuditResultEntity result) {
    if (result.requiredDocuments.isEmpty) return const SizedBox.shrink();

    const docAccent = Color(0xFF1565C0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? TariffColors.navySurface : Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!, width: 1),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8), 
                  decoration: BoxDecoration(color: docAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), 
                  child: const Icon(Icons.description_outlined, size: 20, color: docAccent)
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('REQUIRED DOCUMENTATION', style: TextStyle(color: docAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                      const SizedBox(height: 2),
                      Text('MANDATORY CLEARANCE PROTOCOLS', style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[600], fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: isDark ? TariffColors.divider : Colors.grey[200]),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: result.requiredDocuments.asMap().entries.map((entry) => Padding(
                padding: EdgeInsets.only(bottom: entry.key < result.requiredDocuments.length - 1 ? 12 : 0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 16, color: TariffColors.greenVerified),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value, 
                        style: TextStyle(
                          color: isDark ? TariffColors.textPrimary : Colors.black87, 
                          fontSize: 13, 
                          fontWeight: FontWeight.w500, 
                          height: 1.4
                        ),
                      )
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceMetaCard(BuildContext context, HsAuditResultEntity result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(color: isDark ? TariffColors.navySurface : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!, width: 1)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded, size: 16, color: isDark ? TariffColors.textMuted : Colors.grey[500]),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'AUDIT METADATA', 
                    style: TextStyle(color: TariffColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.8),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: isDark ? TariffColors.divider : Colors.grey[200]),
          _MetaRow(label: 'Consignee', value: result.consignee),
          _MetaRow(label: 'Invoice No.', value: result.invoiceNumber, mono: true),
          _MetaRow(label: 'Audit Time', value: result.auditTimestamp),
          _MetaRow(label: 'Model Version', value: '${AppConstants.appName} ${AppConstants.aiModelVersion}', showDivider: false),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, WidgetRef ref, HsAuditResultEntity result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: isDark ? TariffColors.navyMid : Colors.white, 
        border: Border(top: BorderSide(color: isDark ? TariffColors.divider : Colors.grey[200]!, width: 1))
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                if (result is HsAuditResultModel) {
                  ref.read(pdfExportServiceProvider).generateAndShareAuditPdf(result);
                } else {
                  // Fallback for immediate entity injection (convert to model)
                  final model = HsAuditResultModel(
                    hsCode: result.hsCode,
                    userId: result.userId,
                    hsDescription: result.hsDescription,
                    chapter: result.chapter,
                    consignee: result.consignee,
                    invoiceNumber: result.invoiceNumber,
                    cargoDescription: result.cargoDescription,
                    standardDutyRate: result.standardDutyRate,
                    vatRate: result.vatRate,
                    totalTaxBurden: result.totalTaxBurden,
                    declaredValue: result.declaredValue,
                    currency: result.currency,
                    estimatedDutyAmount: result.estimatedDutyAmount,
                    confidenceScore: result.confidenceScore,
                    complianceWarnings: result.complianceWarnings,
                    requiredDocuments: result.requiredDocuments,
                    auditTimestamp: result.auditTimestamp,
                    riskLevel: result.riskLevel,
                    status: result.status,
                    originCountry: result.originCountry,
                    destinationCountry: result.destinationCountry,
                    totalWeightKg: result.totalWeightKg,
                    plannedMonth: result.plannedMonth,
                    shippingMethod: result.shippingMethod,
                    isDeleted: result.isDeleted,
                  );
                  ref.read(pdfExportServiceProvider).generateAndShareAuditPdf(model);
                }
              }, 
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? TariffColors.navyElevated : const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ), 
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 20), 
              label: const Text(
                'EXPORT AUDIT REPORT (PDF)', 
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0),
                overflow: TextOverflow.ellipsis,
              )
            )
          ),
        ],
      ),
    );
  }
}

class _RiskVisuals {
  final Color color;
  final Color background;
  final Color border;
  final IconData icon;
  final String label;

  const _RiskVisuals({
    required this.color,
    required this.background,
    required this.border,
    required this.icon,
    required this.label,
  });

  factory _RiskVisuals.fromLevel(RiskLevel level, bool isDark) {
    switch (level) {
      case RiskLevel.low:
        return _RiskVisuals(
          color: TariffColors.greenVerified,
          background: isDark ? const Color(0xFF0F2618) : const Color(0xFFE8F5E9),
          border: isDark ? TariffColors.greenVerifiedBorder.withValues(alpha: 0.3) : const Color(0xFFA5D6A7),
          icon: Icons.verified_user_rounded,
          label: 'SECURE / LOW RISK',
        );
      case RiskLevel.medium:
        return _RiskVisuals(
          color: TariffColors.amberPending,
          background: isDark ? const Color(0xFF261D00) : const Color(0xFFFFF8E1),
          border: isDark ? TariffColors.amberPendingBorder.withValues(alpha: 0.3) : const Color(0xFFFFE082),
          icon: Icons.assignment_late_rounded,
          label: 'CAUTION / MEDIUM RISK',
        );
      case RiskLevel.high:
        return _RiskVisuals(
          color: TariffColors.crimsonRisk,
          background: isDark ? const Color(0xFF260D0D) : const Color(0xFFFFEBEE),
          border: isDark ? TariffColors.crimsonRiskBorder.withValues(alpha: 0.3) : const Color(0xFFEF9A9A),
          icon: Icons.gpp_maybe_rounded,
          label: 'ALERT / HIGH RISK',
        );
      case RiskLevel.invalidInput:
        return _RiskVisuals(
          color: isDark ? TariffColors.textSecondary : Colors.blueGrey[700]!,
          background: isDark ? const Color(0xFF1C252E) : const Color(0xFFECEFF1),
          border: isDark ? Colors.white10 : const Color(0xFFCFD8DC),
          icon: Icons.block_rounded,
          label: 'SECURITY BLOCK / INVALID INPUT',
        );
    }
  }
}

class _TariffRow extends StatelessWidget {
  const _TariffRow({required this.label, required this.value, required this.valueColor, this.showDivider = false, this.isBold = false});
  final String label;
  final String value;
  final Color valueColor;
  final bool showDivider;
  final bool isBold;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(flex: 2, child: Text(label, style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w400))),
              const SizedBox(width: 12),
              Flexible(flex: 3, child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: valueColor, fontSize: isBold ? 15 : 13, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, fontFamily: value.contains('%') || value.contains('USD') ? 'monospace' : null))),
            ],
          ),
        ),
        if (showDivider) Container(height: 1, color: isDark ? TariffColors.divider : Colors.grey[200]),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value, this.showDivider = true, this.mono = false});
  final String label;
  final String value;
  final bool showDivider;
  final bool mono;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label, style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[500], fontSize: 12), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 12),
              Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.black87, fontSize: 12, fontWeight: FontWeight.w500, fontFamily: mono ? 'monospace' : null), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        if (showDivider) Container(height: 1, color: isDark ? TariffColors.divider : Colors.grey[200]),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final bool isDark;
  _GridPainter({this.isDark = true});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = (isDark ? const Color(0xFF1E3A63) : Colors.blue[50]!).withValues(alpha: 0.5)..strokeWidth = 0.5;
    const double spacing = 28;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
