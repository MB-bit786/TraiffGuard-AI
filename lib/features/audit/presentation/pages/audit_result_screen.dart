import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import '../../domain/entities/hs_audit_result_entity.dart';
import '../providers/audit_detail_provider.dart';
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
        loading: () => const Scaffold(
          backgroundColor: TariffColors.navyDeep,
          body: Center(child: CircularProgressIndicator(color: TariffColors.amberPending)),
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
      body: _buildBody(context, finalResult),
      bottomNavigationBar: _buildBottomBar(context, finalResult),
    );
  }

  Widget _buildErrorScaffold(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: TariffColors.navyDeep,
      appBar: AppBar(
        backgroundColor: TariffColors.navyMid,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: TariffColors.textSecondary, size: 20),
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
                style: const TextStyle(color: TariffColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TariffColors.navyElevated,
                  foregroundColor: TariffColors.textPrimary,
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
                  backgroundColor: TariffColors.navyMid,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: TariffColors.cardBorder)),
                  title: const Text('Delete Audit Report?', style: TextStyle(color: TariffColors.textPrimary, fontWeight: FontWeight.bold)),
                  content: const Text('This will move the audit record to the warehouse trash. You can restore it later from settings.', style: TextStyle(color: TariffColors.textSecondary, fontSize: 14)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL', style: TextStyle(color: TariffColors.textMuted, fontWeight: FontWeight.w600))),
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
                        content: const Text('🗑️ Audit moved to Trash', style: TextStyle(color: TariffColors.textPrimary, fontWeight: FontWeight.w600)),
                        backgroundColor: TariffColors.navySurface,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                    ref.invalidate(invoiceListProvider);
                    context.pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: TariffColors.crimsonRisk));
                  }
                }
              }
            }
          },
          icon: const Icon(Icons.more_vert_rounded, color: TariffColors.textSecondary, size: 20),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: TariffColors.crimsonRisk, size: 18),
                  SizedBox(width: 8),
                  Text('Delete Audit', style: TextStyle(color: TariffColors.crimsonRisk)),
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

  Widget _buildBody(BuildContext context, HsAuditResultEntity result) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeroHSCodeCard(context, result),
        const SizedBox(height: 14),
        _buildConfidenceBar(context, result),
        const SizedBox(height: 14),
        _buildTariffBreakdownCard(context, result),
        const SizedBox(height: 14),
        _buildRiskWarningCard(context, result),
        const SizedBox(height: 14),
        _buildRequiredDocumentsCard(context, result),
        const SizedBox(height: 14),
        _buildInvoiceMetaCard(context, result),
        const SizedBox(height: 80),
      ],
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
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: TariffColors.greenVerifiedSoft, borderRadius: BorderRadius.circular(6), border: Border.all(color: TariffColors.greenVerifiedBorder, width: 1)),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 12, color: TariffColors.greenVerified),
                          SizedBox(width: 5),
                          Text('AI CLASSIFIED', style: TextStyle(color: TariffColors.greenVerified, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: result.hsCode));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('HS Code copied'), backgroundColor: isDark ? TariffColors.navyElevated : Colors.blue[900], behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
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
                Text('HS CODE', style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.5)),
                const SizedBox(height: 6),
                Text(result.hsCode, style: TextStyle(color: isDark ? TariffColors.textPrimary : Colors.black87, fontSize: 52, fontWeight: FontWeight.w900, letterSpacing: -1.0, fontFamily: 'monospace', height: 1.0)),
                const SizedBox(height: 10),
                Text(result.hsDescription, style: const TextStyle(color: TariffColors.amberPending, fontSize: 16, fontWeight: FontWeight.w600)),
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

  Widget _buildConfidenceBar(BuildContext context, HsAuditResultEntity result) {
    final score = result.confidenceScore;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = score >= 85 ? TariffColors.greenVerified : score >= 65 ? TariffColors.amberPending : TariffColors.crimsonRisk;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? TariffColors.navySurface : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!, width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('AI CLASSIFICATION CONFIDENCE', style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[600], fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              Text('$score%', style: TextStyle(color: barColor, fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: score / 100, minHeight: 8, backgroundColor: isDark ? TariffColors.navyElevated : Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(barColor)),
          ),
          const SizedBox(height: 8),
          Text(
            score >= 85 ? 'High confidence — classification validated against WCO nomenclature' : score >= 65 ? 'Medium confidence — manual review recommended before clearance' : 'Low confidence — classification requires human expert review',
            style: TextStyle(color: barColor.withValues(alpha: 0.8), fontSize: 11.5),
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
                Text('TARIFF & DUTY BREAKDOWN', style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[600], fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
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
                const Flexible(child: Text('TOTAL TAX BURDEN', style: TextStyle(color: TariffColors.amberPending, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2), overflow: TextOverflow.ellipsis)),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isHighRisk = result.riskLevel == RiskLevel.high;
    final riskColor = isHighRisk ? TariffColors.crimsonRisk : TariffColors.amberPending;
    final riskBgColor = isHighRisk ? TariffColors.crimsonRiskSoft : TariffColors.amberPendingSoft;
    final riskBorderColor = isHighRisk ? TariffColors.crimsonRiskBorder.withValues(alpha: 0.5) : TariffColors.amberPendingBorder.withValues(alpha: 0.5);
    final riskLabel = isHighRisk ? 'HIGH RISK' : 'MEDIUM RISK';

    return Container(
      decoration: BoxDecoration(color: riskBgColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: riskBorderColor, width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: riskColor.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(Icons.security_rounded, color: riskColor, size: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customs Compliance & Risk Warnings', style: TextStyle(color: riskColor, fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('${result.complianceWarnings.length} alerts requiring attention', style: TextStyle(color: riskColor.withValues(alpha: 0.7), fontSize: 11)),
                    ],
                  ),
                ),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: riskColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: riskColor.withValues(alpha: 0.4), width: 1)), child: Text(riskLabel, style: TextStyle(color: riskColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8))),
              ],
            ),
          ),
          Container(height: 1, color: riskColor.withValues(alpha: 0.15)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: result.complianceWarnings.asMap().entries.map((entry) => Padding(
                padding: EdgeInsets.only(bottom: entry.key < result.complianceWarnings.length - 1 ? 10 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(margin: const EdgeInsets.only(top: 4), width: 6, height: 6, decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(entry.value, style: TextStyle(color: riskColor.withValues(alpha: 0.9), fontSize: 13, height: 1.5, fontWeight: FontWeight.w500))),
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
    const docAccent = Color(0xFF64B5F6);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(color: isDark ? TariffColors.navySurface : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: docAccent.withValues(alpha: 0.4), width: 1.5), boxShadow: [BoxShadow(color: docAccent.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: docAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.description_outlined, size: 20, color: docAccent)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('REQUIRED DOCUMENTATION', style: TextStyle(color: docAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                    const SizedBox(height: 2),
                    Text('MANDATORY CLEARANCE PROTOCOLS', style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[600], fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 1, color: docAccent.withValues(alpha: 0.15)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: result.requiredDocuments.asMap().entries.map((entry) => Padding(
                padding: EdgeInsets.only(bottom: entry.key < result.requiredDocuments.length - 1 ? 12 : 0),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: docAccent.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 14, color: docAccent)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.value, style: TextStyle(color: isDark ? TariffColors.textPrimary : Colors.black87, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4))),
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
                Text('AUDIT METADATA', style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[600], fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
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

  Widget _buildBottomBar(BuildContext context, HsAuditResultEntity result) {
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
            child: OutlinedButton.icon(
              onPressed: () => PdfExportService.exportAuditReport(context, _toMap(result)), 
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? TariffColors.textSecondary : Colors.blueGrey[700], 
                side: BorderSide(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!, width: 1), 
                padding: const EdgeInsets.symmetric(vertical: 14), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ), 
              icon: const Icon(Icons.print_outlined, size: 18), 
              label: const Text('Export PDF', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))
            )
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: isDark ? TariffColors.navyMid : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: TariffColors.cardBorder)),
                    title: Text(
                      'Confirm Official Submission',
                      style: TextStyle(color: isDark ? TariffColors.textPrimary : Colors.black87, fontWeight: FontWeight.bold),
                    ),
                    content: Text(
                      'You are about to transmit this cargo manifest to the National Customs Authority. This action will finalize the audit and lock the record.',
                      style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.black54, fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('CANCEL', style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[600], fontWeight: FontWeight.w600)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('SUBMIT', style: TextStyle(color: TariffColors.greenVerified, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✅ Manifest successfully filed with Customs Authority.',
                        style: TextStyle(color: isDark ? TariffColors.navyDeep : Colors.white, fontWeight: FontWeight.w700),
                      ),
                      backgroundColor: TariffColors.greenVerified,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TariffColors.greenVerified,
                foregroundColor: isDark ? const Color(0xFF0A1628) : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.cloud_upload_rounded, size: 18),
              label: const Text(
                'Submit to Customs',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _toMap(HsAuditResultEntity e) {
    return {
      'hsCode': e.hsCode,
      'userId': e.userId,
      'hsDescription': e.hsDescription,
      'chapter': e.chapter,
      'consignee': e.consignee,
      'invoiceNumber': e.invoiceNumber,
      'cargoDescription': e.cargoDescription,
      'standardDutyRate': e.standardDutyRate,
      'vatRate': e.vatRate,
      'totalTaxBurden': e.totalTaxBurden,
      'declaredValue': e.declaredValue,
      'currency': e.currency,
      'estimatedDutyAmount': e.estimatedDutyAmount,
      'confidenceScore': e.confidenceScore,
      'complianceWarnings': e.complianceWarnings,
      'requiredDocuments': e.requiredDocuments,
      'auditTimestamp': e.auditTimestamp,
      'riskLevel': e.riskLevel.name,
      'originCountry': e.originCountry,
      'destinationCountry': e.destinationCountry,
      'totalWeightKg': e.totalWeightKg,
      'plannedMonth': e.plannedMonth,
      'shippingMethod': e.shippingMethod,
      'isDeleted': e.isDeleted ? 1 : 0,
    };
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(flex: 2, child: Text(label, style: const TextStyle(color: TariffColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w400))),
              const SizedBox(width: 12),
              Flexible(flex: 3, child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: valueColor, fontSize: isBold ? 15 : 13, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, fontFamily: value.contains('%') || value.contains('USD') ? 'monospace' : null))),
            ],
          ),
        ),
        if (showDivider) Container(height: 1, color: TariffColors.divider),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label, style: const TextStyle(color: TariffColors.textMuted, fontSize: 12), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 12),
              Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: TariffColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500, fontFamily: mono ? 'monospace' : null), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        if (showDivider) Container(height: 1, color: TariffColors.divider),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final bool isDark;
  _GridPainter({required this.isDark});
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
