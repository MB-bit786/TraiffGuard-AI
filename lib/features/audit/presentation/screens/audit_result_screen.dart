import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/core/theme/tariff_colors.dart';
import 'package:hscode_auditor/features/audit/domain/models/hs_audit_result_model.dart';
import 'package:hscode_auditor/features/audit/presentation/providers/audit_detail_provider.dart';

class AuditResultScreen extends ConsumerWidget {
  const AuditResultScreen({
    super.key,
    this.result,
  });

  final HsAuditResultModel? result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Extract the result or invoice ID from route arguments
    final arg = ModalRoute.of(context)?.settings.arguments;
    
    // If we have a full model already (passed from form), use it.
    if (result != null) return _buildScaffold(context, result!);
    if (arg is HsAuditResultModel) return _buildScaffold(context, arg);

    // 2. If we only have an ID (passed from Dashboard), fetch the model from the DB.
    if (arg is String) {
      final detailAsync = ref.watch(auditDetailProvider(arg));
      
      return detailAsync.when(
        data: (fetchedResult) {
          if (fetchedResult == null) {
            return _buildErrorScaffold(context, 'Audit report not found in database.');
          }
          return _buildScaffold(context, fetchedResult);
        },
        loading: () => const Scaffold(
          backgroundColor: TariffColors.navyDeep,
          body: Center(child: CircularProgressIndicator(color: TariffColors.amberPending)),
        ),
        error: (err, _) => _buildErrorScaffold(context, 'Error loading report: $err'),
      );
    }

    // 3. Fallback for invalid state (e.g., deep linking without parameters)
    return _buildErrorScaffold(context, 'Invalid audit report state.');
  }

  Widget _buildScaffold(BuildContext context, HsAuditResultModel finalResult) {
    return Scaffold(
      backgroundColor: TariffColors.navyDeep,
      appBar: _buildAppBar(context),
      body: _buildBody(context, finalResult),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildErrorScaffold(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: TariffColors.navyDeep,
      appBar: AppBar(
        backgroundColor: TariffColors.navyMid,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
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
                onPressed: () => Navigator.of(context).pop(),
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: TariffColors.navyMid,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: TariffColors.textSecondary,
          size: 20,
        ),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Audit Result',
            style: TextStyle(
              color: TariffColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'CUSTOMS CLASSIFICATION REPORT',
            style: TextStyle(
              color: TariffColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.share_rounded,
            color: TariffColors.textSecondary,
            size: 20,
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.more_vert_rounded,
            color: TariffColors.textSecondary,
            size: 20,
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: TariffColors.divider),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HsAuditResultModel result) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeroHSCodeCard(context, result),
        const SizedBox(height: 14),
        _buildConfidenceBar(result),
        const SizedBox(height: 14),
        _buildTariffBreakdownCard(result),
        const SizedBox(height: 14),
        _buildRiskWarningCard(result),
        const SizedBox(height: 14),
        _buildRequiredDocumentsCard(result),
        const SizedBox(height: 14),
        _buildInvoiceMetaCard(result),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildHeroHSCodeCard(BuildContext context, HsAuditResultModel result) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: TariffColors.navySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TariffColors.navyElevated, width: 1),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(painter: _GridPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: TariffColors.greenVerifiedSoft,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: TariffColors.greenVerifiedBorder,
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 12,
                            color: TariffColors.greenVerified,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'AI CLASSIFIED',
                            style: TextStyle(
                              color: TariffColors.greenVerified,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: result.hsCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('HS Code copied'),
                            backgroundColor: TariffColors.navyElevated,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: TariffColors.navyElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: TariffColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'HS CODE',
                  style: TextStyle(
                    color: TariffColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                  ),
                ),const SizedBox(height: 6),
                Text(
                  result.hsCode,
                  style: const TextStyle(
                    color: TariffColors.textPrimary,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    fontFamily: 'monospace',
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  result.hsDescription,
                  style: const TextStyle(
                    color: TariffColors.amberPending,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.chapter,
                  style: const TextStyle(
                    color: TariffColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 18),
                Container(height: 1, color: TariffColors.divider),
                const SizedBox(height: 14),
                Text(
                  result.cargoDescription,
                  style: const TextStyle(
                    color: TariffColors.textSecondary,
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

  Widget _buildConfidenceBar(HsAuditResultModel result) {
    final score = result.confidenceScore;
    final barColor = score >= 85
        ? TariffColors.greenVerified
        : score >= 65
            ? TariffColors.amberPending
            : TariffColors.crimsonRisk;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TariffColors.navySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TariffColors.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AI CLASSIFICATION CONFIDENCE',
                style: TextStyle(
                  color: TariffColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '$score%',
                style: TextStyle(
                  color: barColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: TariffColors.navyElevated,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            score >= 85
                ? 'High confidence — classification validated against WCO nomenclature'
                : score >= 65
                    ? 'Medium confidence — manual review recommended before clearance'
                    : 'Low confidence — classification requires human expert review',
            style: TextStyle(
              color: barColor.withValues(alpha: 0.8),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTariffBreakdownCard(HsAuditResultModel result) {
    return Container(
      decoration: BoxDecoration(
        color: TariffColors.navySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TariffColors.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: const Row(
              children: [
                Icon(
                  Icons.percent_rounded,
                  size: 16,
                  color: TariffColors.amberPending,
                ),
                SizedBox(width: 8),
                Text(
                  'TARIFF & DUTY BREAKDOWN',
                  style: TextStyle(
                    color: TariffColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: TariffColors.divider),
          _TariffRow(
            label: 'Standard Import Duty',
            value: result.standardDutyRate,
            valueColor: TariffColors.textPrimary,
            showDivider: true,
          ),
          _TariffRow(
            label: 'VAT / GST',
            value: result.vatRate,
            valueColor: TariffColors.textPrimary,
            showDivider: true,
          ),
          _TariffRow(
            label: 'Declared Cargo Value',
            value: '${result.currency} ${result.declaredValue}',
            valueColor: TariffColors.textSecondary,
            showDivider: true,
          ),
          _TariffRow(
            label: 'Estimated Duty Payable',
            value: '${result.currency} ${result.estimatedDutyAmount}',
            valueColor: TariffColors.amberPending,
            showDivider: true,
            isBold: true,
          ),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: TariffColors.amberPendingSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: TariffColors.amberPendingBorder.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'TOTAL TAX BURDEN',
                    style: TextStyle(
                      color: TariffColors.amberPending,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    result.totalTaxBurden,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: TariffColors.amberPending,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskWarningCard(HsAuditResultModel result) {
    final isHighRisk = result.riskLevel == RiskLevel.high;
    final riskColor =
        isHighRisk ? TariffColors.crimsonRisk : TariffColors.amberPending;
    final riskBgColor =
        isHighRisk ? TariffColors.crimsonRiskSoft : TariffColors.amberPendingSoft;
    final riskBorderColor = isHighRisk
        ? TariffColors.crimsonRiskBorder.withValues(alpha: 0.5)
        : TariffColors.amberPendingBorder.withValues(alpha: 0.5);
    final riskLabel = isHighRisk ? 'HIGH RISK' : 'MEDIUM RISK';

    return Container(
      decoration: BoxDecoration(
        color: riskBgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: riskBorderColor, width: 1.5),
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
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    color: riskColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customs Compliance & Risk Warnings',
                        style: TextStyle(
                          color: riskColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${result.complianceWarnings.length} alerts requiring attention',
                        style: TextStyle(
                          color: riskColor.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: riskColor.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Text(
                    riskLabel,
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: riskColor.withValues(alpha: 0.15)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: result.complianceWarnings
                  .asMap()
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(
                        bottom: entry.key < result.complianceWarnings.length - 1
                            ? 10
                            : 0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: riskColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                color: riskColor.withValues(alpha: 0.9),
                                fontSize: 13,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequiredDocumentsCard(HsAuditResultModel result) {
    return Container(
      decoration: BoxDecoration(
        color: TariffColors.navySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TariffColors.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: const Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: Color(0xFF64B5F6),
                ),
                SizedBox(width: 8),
                Text(
                  'REQUIRED DOCUMENTATION',
                  style: TextStyle(
                    color: TariffColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: TariffColors.divider),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: result.requiredDocuments
                  .asMap()
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(
                        bottom:
                            entry.key < result.requiredDocuments.length - 1
                                ? 10
                                : 0,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: TariffColors.navyElevated,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(
                                  color: TariffColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                color: TariffColors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: TariffColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceMetaCard(HsAuditResultModel result) {
    return Container(
      decoration: BoxDecoration(
        color: TariffColors.navySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TariffColors.cardBorder, width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: const Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 16,
                  color: TariffColors.textMuted,
                ),
                SizedBox(width: 8),
                Text(
                  'AUDIT METADATA',
                  style: TextStyle(
                    color: TariffColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: TariffColors.divider),
          _MetaRow(label: 'Consignee', value: result.consignee),
          _MetaRow(label: 'Invoice No.', value: result.invoiceNumber, mono: true),
          _MetaRow(label: 'Audit Time', value: result.auditTimestamp),
          const _MetaRow(
            label: 'Model Version',
            value: 'TariffGuard AI v3.2.1',
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: TariffColors.navyMid,
        border: Border(
          top: BorderSide(color: TariffColors.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: TariffColors.textSecondary,
                side: const BorderSide(
                    color: TariffColors.cardBorder, width: 1),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text(
                'Export PDF',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: TariffColors.greenVerified,
                foregroundColor: const Color(0xFF0A1628),
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
}

class _TariffRow extends StatelessWidget {
  const _TariffRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.showDivider = false,
    this.isBold = false,
  });

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: TariffColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: isBold ? 15 : 13,
                    fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                    fontFamily: value.contains('%') || value.contains('USD')
                        ? 'monospace'
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Container(height: 1, color: TariffColors.divider),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.showDivider = true,
    this.mono = false,
  });

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
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: TariffColors.textMuted,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: TariffColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: mono ? 'monospace' : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Container(height: 1, color: TariffColors.divider),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E3A63).withValues(alpha: 0.5)
      ..strokeWidth = 0.5;

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
