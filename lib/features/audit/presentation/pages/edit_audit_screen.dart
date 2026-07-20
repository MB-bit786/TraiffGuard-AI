import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/features/search/presentation/providers/tariff_search_provider.dart';
import 'package:hscode_auditor/features/audit/presentation/providers/audit_detail_provider.dart';
import 'package:hscode_auditor/core/providers/auto_sync_provider.dart';
import 'package:hscode_auditor/features/auth/presentation/providers/auth_providers.dart';
import 'package:hscode_auditor/features/audit/data/models/hs_audit_result_model.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/connection_provider.dart';
import '../../../dashboard/presentation/providers/invoice_list_provider.dart';
import '../../../invoice/presentation/providers/invoice_providers.dart';
import '../../../invoice/domain/entities/invoice_entity.dart';
import 'package:go_router/go_router.dart';
import 'package:hscode_auditor/core/constants/app_constants.dart';

class EditAuditScreen extends ConsumerStatefulWidget {
  final HsAuditResultModel audit;
  const EditAuditScreen({super.key, required this.audit});

  @override
  ConsumerState<EditAuditScreen> createState() => _EditAuditScreenState();
}

class _EditAuditScreenState extends ConsumerState<EditAuditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _consigneeController;
  late TextEditingController _invoiceNumberController;
  late TextEditingController _cargoDescController;
  late TextEditingController _originCountryController;
  late TextEditingController _destCountryController;
  late TextEditingController _valueController;
  late TextEditingController _weightController;

  late String _selectedCurrency;
  String? _selectedHsCode;
  late String _selectedMonth;
  late String _selectedShippingMethod;
  late String _selectedOriginCountry;
  late String _selectedDestCountry;
  bool _isOtherOrigin = false;
  bool _isOtherDest = false;
  final _otherOriginController = TextEditingController();
  final _otherDestController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _consigneeController = TextEditingController(text: widget.audit.consignee);
    _invoiceNumberController = TextEditingController(text: widget.audit.invoiceNumber);
    _cargoDescController = TextEditingController(text: widget.audit.cargoDescription);
    _originCountryController = TextEditingController(text: widget.audit.originCountry);
    _destCountryController = TextEditingController(text: widget.audit.destinationCountry);
    _valueController = TextEditingController(text: widget.audit.declaredValue);
    _weightController = TextEditingController(text: widget.audit.totalWeightKg);
    
    _selectedCurrency = widget.audit.currency;
    _selectedHsCode = widget.audit.hsCode;
    _selectedMonth = widget.audit.plannedMonth;
    _selectedShippingMethod = widget.audit.shippingMethod;

    // Initialize dropdown vs manual text state
    if (AppConstants.mainCountries.contains(widget.audit.originCountry)) {
      _selectedOriginCountry = widget.audit.originCountry;
      _isOtherOrigin = false;
    } else {
      _selectedOriginCountry = 'Other...';
      _isOtherOrigin = true;
      _otherOriginController.text = widget.audit.originCountry;
    }

    if (AppConstants.mainCountries.contains(widget.audit.destinationCountry)) {
      _selectedDestCountry = widget.audit.destinationCountry;
      _isOtherDest = false;
    } else {
      _selectedDestCountry = 'Other...';
      _isOtherDest = true;
      _otherDestController.text = widget.audit.destinationCountry;
    }

    _cargoDescController.addListener(_onCargoDescChanged);
  }

  void _onCargoDescChanged() {
    final isOnline = ref.read(connectionProvider).effectivelyOnline;
    if (!isOnline) {
      ref.read(tariffSearchProvider.notifier).updateQuery(_cargoDescController.text);
    } else {
      ref.read(tariffSearchProvider.notifier).updateQuery('');
    }
    setState(() {});
  }

  @override
  void dispose() {
    _cargoDescController.removeListener(_onCargoDescChanged);
    _consigneeController.dispose();
    _invoiceNumberController.dispose();
    _cargoDescController.dispose();
    _originCountryController.dispose();
    _destCountryController.dispose();
    _valueController.dispose();
    _weightController.dispose();
    _otherOriginController.dispose();
    _otherDestController.dispose();
    super.dispose();
  }

  Future<void> _saveQuicklyAndAnalyzeInBackground() async {
    if (!_formKey.currentState!.validate()) return;

    // 0. CHECK FOR CHANGES: If nothing changed, just exit to save API costs and time.
    final bool hasChanged =
        _consigneeController.text.trim() != widget.audit.consignee ||
        _invoiceNumberController.text.trim() != widget.audit.invoiceNumber ||
        _cargoDescController.text.trim() != widget.audit.cargoDescription ||
        _originCountryController.text.trim() != widget.audit.originCountry ||
        _destCountryController.text.trim() != widget.audit.destinationCountry ||
        _valueController.text.trim() != widget.audit.declaredValue ||
        _weightController.text.trim() != widget.audit.totalWeightKg ||
        _selectedCurrency != widget.audit.currency ||
        _selectedHsCode != widget.audit.hsCode ||
        _selectedMonth != widget.audit.plannedMonth ||
        _selectedShippingMethod != widget.audit.shippingMethod;

    if (!hasChanged) {
      context.pop();
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repository = ref.read(invoiceRepositoryProvider);
      final user = ref.read(authStateProvider).value;
      final userId = user?.uid ?? 'anonymous';
      final String currentId = _invoiceNumberController.text.trim();
      final String timestamp = DateTime.now().toString().split('.').first;

      // 1. Create a "High-Fidelity Draft" model with user's manual changes.
      // We set confidenceScore to 0 to trigger the background AutoSyncService.
      final manualDraft = HsAuditResultModel(
        hsCode: _selectedHsCode != null ? '$_selectedHsCode (Offline Draft)' : 'PENDING (Offline Draft)',
        userId: userId,
        hsDescription: 'Local manual update (Analysis Pending...)',
        chapter: (_selectedHsCode != null && _selectedHsCode!.length >= 2) 
            ? 'Chapter ${_selectedHsCode!.substring(0, 2)}' 
            : '00',
        consignee: _consigneeController.text.trim(),
        invoiceNumber: currentId,
        cargoDescription: _cargoDescController.text.trim(),
        standardDutyRate: widget.audit.standardDutyRate, // Keep old rates until AI updates
        vatRate: widget.audit.vatRate,
        totalTaxBurden: widget.audit.totalTaxBurden,
        declaredValue: _valueController.text.trim(),
        currency: _selectedCurrency,
        estimatedDutyAmount: widget.audit.estimatedDutyAmount,
        confidenceScore: 0, // CRITICAL: This triggers the background sync
        riskLevel: widget.audit.riskLevel,
        status: 'offlineDraft',
        auditTimestamp: timestamp,
        originCountry: _isOtherOrigin ? _otherOriginController.text.trim() : _selectedOriginCountry,
        destinationCountry: _isOtherDest ? _otherDestController.text.trim() : _selectedDestCountry,
        totalWeightKg: _weightController.text.trim(),
        plannedMonth: _selectedMonth,
        shippingMethod: _selectedShippingMethod,
        isDeleted: widget.audit.isDeleted,
        complianceWarnings: ['🔄 RE-AUDIT QUEUED: Manual corrections are being analyzed by AI...'],
        requiredDocuments: widget.audit.requiredDocuments,
      );

      final manifest = InvoiceEntity(
        id: manualDraft.invoiceNumber,
        userId: manualDraft.userId,
        consignee: manualDraft.consignee,
        cargoDescription: manualDraft.cargoDescription,
        hsCode: manualDraft.hsCode,
        dutyRate: manualDraft.standardDutyRate,
        status: manualDraft.status,
        timestamp: manualDraft.auditTimestamp,
        isDeleted: manualDraft.isDeleted,
      );

      // 2. Perform optimistic local save
      await repository.cacheInvoiceManifest(manifest, auditResult: manualDraft);

      // 3. CLEANUP: If the user changed the invoice number, delete the old record.
      if (currentId != widget.audit.invoiceNumber) {
        await repository.hardDeleteInvoice(widget.audit.invoiceNumber, userId);
      }

      if (mounted) {
        // Immediate UI feedback
        context.pop();

        // Defer heavy work to post-transition frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // 1. Refresh global lists
          ref.read(invoiceListProvider.notifier).fetchInvoices();
          
          // 2. Clear stale cache for the detail view
          ref.invalidate(auditDetailProvider(widget.audit.invoiceNumber));
          if (currentId != widget.audit.invoiceNumber) {
            ref.invalidate(auditDetailProvider(currentId));
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Changes saved locally. AI analysis started in background.'), 
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );

          // 3. Trigger AI sync after a slight delay to keep animations smooth
          Future.delayed(const Duration(milliseconds: 600), () {
            ref.read(autoSyncServiceProvider).syncPendingAudits();
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: TariffColors.crimsonRisk),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? TariffColors.navyMid : const Color(0xFF1565C0),
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Audit Details', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            Text('OPTIMISTIC CORRECTION', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.8)),
          ],
        ),
        actions: [
          if (!_isSaving)
            TextButton(
              onPressed: _saveQuicklyAndAnalyzeInBackground,
              child: const Text('SAVE & ANALYZE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionLabel('CONSIGNEE DETAILS'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _consigneeController, 
              label: 'Consignee Name', 
              hint: 'e.g. Global Logistics Inc.', 
              icon: Icons.business_rounded,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Consignee name is required' : null,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _invoiceNumberController, 
              label: 'Invoice Number', 
              hint: 'e.g. INV-2026-3000', 
              icon: Icons.tag_rounded,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Invoice number required';
                if (!AppConstants.invoiceNumberRegex.hasMatch(v.trim())) {
                  return 'Use format: INV-YYYY-SERIAL (e.g. INV-2026-3000)';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Origin Port',
                    initialValue: _selectedOriginCountry,
                    items: [...AppConstants.mainCountries, 'Other...'],
                    onChanged: (v) => setState(() {
                      _selectedOriginCountry = v!;
                      _isOtherOrigin = v == 'Other...';
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    label: 'Importing Port',
                    initialValue: _selectedDestCountry,
                    items: [...AppConstants.mainCountries, 'Other...'],
                    onChanged: (v) => setState(() {
                      _selectedDestCountry = v!;
                      _isOtherDest = v == 'Other...';
                    }),
                  ),
                ),
              ],
            ),
            if (_isOtherOrigin || _isOtherDest) const SizedBox(height: 14),
            if (_isOtherOrigin || _isOtherDest)
              Row(
                children: [
                  if (_isOtherOrigin)
                    Expanded(
                      child: _buildTextField(
                        controller: _otherOriginController,
                        label: 'Type Origin',
                        hint: 'Enter country',
                        icon: Icons.edit_location_alt_outlined,
                        validator: (v) => (_isOtherOrigin && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                      ),
                    ),
                  if (_isOtherOrigin && _isOtherDest) const SizedBox(width: 12),
                  if (_isOtherDest)
                    Expanded(
                      child: _buildTextField(
                        controller: _otherDestController,
                        label: 'Type Importing',
                        hint: 'Enter country',
                        icon: Icons.edit_location_alt_outlined,
                        validator: (v) => (_isOtherDest && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            _buildSectionLabel('CARGO & VALUATION'),
            const SizedBox(height: 12),
            _buildCargoDescriptionField(),
            _buildTariffSearchResults(),
            const SizedBox(height: 14),
            _buildValuationRow(),
            const SizedBox(height: 14),
            _buildLogisticsMetricsRow(),
            const SizedBox(height: 32),
            _buildInfoNote(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? TariffColors.textMuted : Colors.grey[600],
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: isDark ? TariffColors.divider : Colors.grey[300])),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      validator: validator,
      style: TextStyle(color: isDark ? TariffColors.textPrimary : Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: isDark ? TariffColors.textMuted : Colors.grey[400]),
        labelStyle: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.grey[700], fontSize: 13),
        hintStyle: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[400], fontSize: 13),
        filled: true,
        fillColor: isDark ? TariffColors.navySurface : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? TariffColors.inputBorder : Colors.grey[300]!, width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? TariffColors.inputBorder : Colors.grey[300]!, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: TariffColors.amberPending, width: 2)),
      ),
    );
  }

  Widget _buildCargoDescriptionField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: _cargoDescController,
      maxLines: 4,
      style: TextStyle(color: isDark ? TariffColors.textPrimary : Colors.black87, fontSize: 14, height: 1.6),
      decoration: InputDecoration(
        labelText: 'Cargo Description',
        alignLabelWithHint: true,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: Icon(Icons.description_rounded, size: 18, color: isDark ? TariffColors.textMuted : Colors.grey[400]),
        ),
        labelStyle: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.grey[700], fontSize: 13),
        filled: true,
        fillColor: isDark ? TariffColors.navySurface : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? TariffColors.inputBorder : Colors.grey[300]!, width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? TariffColors.inputBorder : Colors.grey[300]!, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: TariffColors.amberPending, width: 2)),
      ),
      validator: (v) => (v == null || v.trim().length < 10) ? 'Min. 10 characters' : null,
    );
  }

  Widget _buildValuationRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _buildTextField(
            controller: _valueController,
            label: 'Declared Value',
            hint: 'e.g. 48500',
            icon: Icons.attach_money_rounded,
            inputType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _buildDropdown(
            label: 'Currency',
            initialValue: _selectedCurrency,
            items: AppConstants.currencies,
            onChanged: (v) => setState(() => _selectedCurrency = v!),
          ),
        ),
      ],
    );
  }

  Widget _buildLogisticsMetricsRow() {
    return Column(
      children: [
        _buildTextField(
          controller: _weightController,
          label: 'Total Weight',
          hint: 'e.g. 450.5',
          icon: Icons.monitor_weight_outlined,
          inputType: TextInputType.number,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: 'Planned Month',
                initialValue: _selectedMonth,
                items: AppConstants.months,
                onChanged: (v) => setState(() => _selectedMonth = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown(
                label: 'Shipping Method',
                initialValue: _selectedShippingMethod,
                items: AppConstants.shippingMethods,
                onChanged: (v) => setState(() => _selectedShippingMethod = v!),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown({required String label, required String initialValue, required List<String> items, required void Function(String?) onChanged}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DropdownButtonFormField<String>(
      initialValue: initialValue,
      dropdownColor: isDark ? TariffColors.navyMid : Colors.white,
      style: TextStyle(color: isDark ? TariffColors.textPrimary : Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.grey[700], fontSize: 13),
        filled: true,
        fillColor: isDark ? TariffColors.navySurface : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? TariffColors.inputBorder : Colors.grey[300]!, width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? TariffColors.inputBorder : Colors.grey[300]!, width: 1)),
      ),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTariffSearchResults() {
    final connection = ref.watch(connectionProvider);
    // Search panel strictly restricted to Offline Mode as per user request
    if (connection.effectivelyOnline || _cargoDescController.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final searchResultAsync = ref.watch(tariffSearchProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return searchResultAsync.maybeWhen(
      data: (results) {
        if (results.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 8),
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: isDark ? TariffColors.navySurface : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? TariffColors.inputBorder : Colors.grey[300]!),
            boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: results.length,
            separatorBuilder: (_, _) => Divider(color: isDark ? TariffColors.divider : Colors.grey[200], height: 1),
            itemBuilder: (context, index) {
              final item = results[index];
              final hsCode = item['hs_code'] ?? '';
              final description = item['description'] ?? '';

              return Material(
                color: Colors.transparent,
                child: ListTile(
                  dense: true,
                  title: Text(
                    hsCode,
                    style: TextStyle(
                      color: TariffColors.amberPending, 
                      fontWeight: FontWeight.w900, 
                      fontSize: 14,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5
                    ),
                  ),
                  subtitle: _buildHighlightedText(description, _cargoDescController.text),
                  onTap: () {
                    setState(() {
                      _selectedHsCode = hsCode;
                      _cargoDescController.text = description;
                    });
                    ref.read(tariffSearchProvider.notifier).updateQuery('');
                  },
                ),
              );
            },
          ),
        );
      },
      loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: TariffColors.amberPending)))),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.black54, fontSize: 13, height: 1.4),
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
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.black54, fontSize: 13, height: 1.4, fontFamily: 'Roboto'),
        children: spans,
      ),
    );
  }

  Widget _buildInfoNote() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? TariffColors.navySurface : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TariffColors.amberPending.withValues(alpha: isDark ? 0.2 : 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bolt_rounded, color: TariffColors.amberPending, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Changes save instantly. High-fidelity AI analysis (duty rates, descriptions) will complete in the background.',
              style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.blueGrey[800], fontSize: 12, height: 1.4, fontWeight: isDark ? FontWeight.normal : FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
