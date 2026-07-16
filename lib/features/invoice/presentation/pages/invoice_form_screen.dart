import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/connection_provider.dart';
import 'package:hscode_auditor/features/invoice/presentation/providers/invoice_form_notifier.dart';
import 'package:hscode_auditor/features/search/presentation/providers/tariff_search_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hscode_auditor/config/routes/app_routes.dart';
import 'package:hscode_auditor/core/constants/app_constants.dart';

class InvoiceFormScreen extends ConsumerStatefulWidget {
  const InvoiceFormScreen({super.key});

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _consigneeController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _cargoDescController = TextEditingController();
  final _originCountryController = TextEditingController();
  final _destCountryController = TextEditingController();
  final _valueController = TextEditingController();
  final _weightController = TextEditingController();

  String _selectedCurrency = 'USD';
  String? _selectedHsCode;
  String _selectedMonth = 'January';
  String _selectedShippingMethod = 'Sea Freight';



  @override
  void initState() {
    super.initState();
    _cargoDescController.addListener(() {
      setState(() {});
      ref.read(tariffSearchProvider.notifier).updateQuery(_cargoDescController.text);
    });
  }

  @override
  void dispose() {
    _consigneeController.dispose();
    _invoiceNumberController.dispose();
    _cargoDescController.dispose();
    _originCountryController.dispose();
    _destCountryController.dispose();
    _valueController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _runAudit() async {
    if (!_formKey.currentState!.validate()) return;

    final String description = _cargoDescController.text.trim();
    final String lowerDesc = description.toLowerCase();

    // 🚫 Heuristic Checklist for Conversational Text
    bool isConversational = lowerDesc.contains('?') ||
        lowerDesc.contains('how are') ||
        lowerDesc.contains('who is') ||
        lowerDesc.contains('thank you') ||
        lowerDesc.startsWith('please ') ||
        lowerDesc == 'hi' ||
        lowerDesc == 'hello';

    if (description.isEmpty || description.length < 3 || isConversational) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '⚠️ Invalid cargo description. Please enter a commercial item or commodity name (e.g., "Cotton T-Shirts" or "Industrial Parts").'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return; // Stop execution to protect API costs
    }

    final success = await ref.read(invoiceFormNotifierProvider.notifier).processCustomsAudit(
          invoiceNumber: _invoiceNumberController.text,
          consignee: _consigneeController.text,
          cargoDescription: _cargoDescController.text,
          originCountry: _originCountryController.text,
          destCountry: _destCountryController.text,
          declaredValue: double.tryParse(_valueController.text) ?? 0.0,
          currency: _selectedCurrency,
          hsCode: _selectedHsCode,
          totalWeightKg: _weightController.text,
          plannedMonth: _selectedMonth,
          shippingMethod: _selectedShippingMethod,
        );

    if (mounted && success) {
      final state = ref.read(invoiceFormNotifierProvider);
      
      if (state.error != null) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error!),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (state.result != null) {
        context.push(AppRoutes.auditResultPath(state.result!.invoiceNumber));
      } else {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(connectionProvider);
    final isOnline = connection.effectivelyOnline;
    final isOffline = !isOnline;
    final isAnalyzing = ref.watch(invoiceFormNotifierProvider.select((s) => s.isAnalyzing));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _buildBody(isOffline, isAnalyzing),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
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
            'New Customs Audit',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'INVOICE ENTRY FORM',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.save_outlined,
                color: Colors.white,
                size: 15,
              ),
              SizedBox(width: 5),
              Text(
                'Draft',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
      ),
    );
  }

  Widget _buildBody(bool isOffline, bool isAnalyzing) {
    return Form(
      key: _formKey,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (isOffline) ...[
            _buildOfflineBanner(),
            const SizedBox(height: 16),
          ],
          _buildSectionLabel('CONSIGNEE DETAILS'),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _consigneeController,
            label: 'Consignee Name',
            hint: 'e.g. Global Logistics Inc.',
            icon: Icons.business_rounded,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Consignee name is required' : null,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _invoiceNumberController,
            label: 'Invoice Number',
            hint: 'e.g. INV-2024-00341',
            icon: Icons.tag_rounded,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Invoice number required'
                : null,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _originCountryController,
                  label: 'Origin Country',
                  hint: 'e.g. CN, US',
                  icon: Icons.location_on_outlined,
                  inputType: TextInputType.text,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _destCountryController,
                  label: 'Importing Country',
                  hint: 'e.g. IN, US',
                  icon: Icons.flag_rounded,
                  inputType: TextInputType.text,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
          const SizedBox(height: 24),
          _buildSectionLabel('OPTIONAL REFERENCES'),
          const SizedBox(height: 12),
          _buildOptionalReferenceChips(),
          const SizedBox(height: 32),
          _buildAuditButton(isAnalyzing),
          const SizedBox(height: 20),
          _buildFooterNote(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: TariffColors.amberPendingSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TariffColors.amberPendingBorder.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: TariffColors.amberPending.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: TariffColors.amberPending,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠️ Running in Offline Mode',
                  style: TextStyle(
                    color: TariffColors.amberPending,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Data will be safely cached locally in the warehouse vault. All entries will auto-sync when connectivity is restored.',
                  style: TextStyle(
                    color: TariffColors.amberPending.withValues(alpha: 0.8),
                    fontSize: 12,
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
        Expanded(
          child: Container(height: 1, color: isDark ? TariffColors.divider : Colors.grey[300]),
        ),
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
    Widget? suffix,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      validator: validator,
      style: TextStyle(
        color: isDark ? TariffColors.textPrimary : Colors.black87,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
        prefixIcon: Icon(icon, size: 18, color: isDark ? TariffColors.textMuted : Colors.grey[400]),
        labelStyle: TextStyle(
          color: isDark ? TariffColors.textSecondary : Colors.grey[700],
          fontSize: 13,
        ),
        hintStyle: TextStyle(
          color: isDark ? TariffColors.textMuted : Colors.grey[400],
          fontSize: 13,
        ),
        filled: true,
        fillColor: isDark ? TariffColors.navySurface : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: isDark ? TariffColors.inputBorder : Colors.grey[300]!, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: isDark ? TariffColors.inputBorder : Colors.grey[300]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: TariffColors.inputFocusBorder, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: TariffColors.crimsonRisk, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: TariffColors.crimsonRisk, width: 2),
        ),
        errorStyle: const TextStyle(color: TariffColors.crimsonRisk),
      ),
    );
  }

  Widget _buildCargoDescriptionField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: _cargoDescController,
      maxLines: 5,
      minLines: 4,
      validator: (v) => (v == null || v.trim().length < 10)
          ? 'Please describe the cargo (min. 10 characters)'
          : null,
      style: TextStyle(
        color: isDark ? TariffColors.textPrimary : Colors.black87,
        fontSize: 14,
        height: 1.6,
      ),
      decoration: InputDecoration(
        labelText: 'Cargo Description',
        alignLabelWithHint: true,
        hintText:
            'e.g. Rechargeable lithium-ion battery packs, 3.7V, 5Ah capacity, for use in electric vehicles...',
        helperText:
            '💡 Describe the cargo in plain words to allow AI classification. Be specific — include material, composition, end-use, and voltage ratings if applicable.',
        helperMaxLines: 3,
        hintMaxLines: 4,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: Icon(
            Icons.description_rounded,
            size: 18,
            color: isDark ? TariffColors.textMuted : Colors.grey[400],
          ),
        ),
        labelStyle: TextStyle(
          color: isDark ? TariffColors.textSecondary : Colors.grey[700],
          fontSize: 13,
        ),
        hintStyle: TextStyle(
          color: isDark ? TariffColors.textMuted : Colors.grey[400],
          fontSize: 13,
          height: 1.6,
        ),
        helperStyle: TextStyle(
          color: isDark ? TariffColors.textMuted : Colors.grey[600],
          fontSize: 11.5,
          height: 1.5,
        ),
        filled: true,
        fillColor: isDark ? TariffColors.navySurface : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: isDark ? TariffColors.inputBorder : Colors.grey[300]!, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: isDark ? TariffColors.inputBorder : Colors.grey[300]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: TariffColors.inputFocusBorder, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: TariffColors.crimsonRisk, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: TariffColors.crimsonRisk, width: 2),
        ),
        errorStyle: const TextStyle(color: TariffColors.crimsonRisk),
      ),
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
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
          suffix: const Padding(
            padding: EdgeInsets.only(top: 14, right: 12),
            child: Text('kg', style: TextStyle(color: TariffColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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

  Widget _buildDropdown({
    required String label,
    required String initialValue,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: initialValue,
      dropdownColor: TariffColors.navyMid,
      style: const TextStyle(color: TariffColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: TariffColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: TariffColors.navySurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: TariffColors.inputBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: TariffColors.inputBorder, width: 1),
        ),
      ),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildOptionalReferenceChips() {
    final options = [
      ('Hazmat Declared', Icons.warning_amber_rounded),
      ('Dual-Use Goods', Icons.security_rounded),
      ('CITES Applicable', Icons.eco_rounded),
      ('Bonded Warehouse', Icons.warehouse_rounded),
    ];
    final selected = <String>{};

    return StatefulBuilder(
      builder: (context, localSet) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected.contains(opt.$1);
            return GestureDetector(
              onTap: () => localSet(() {
                isSelected ? selected.remove(opt.$1) : selected.add(opt.$1);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? TariffColors.amberPendingSoft
                      : TariffColors.navySurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? TariffColors.amberPendingBorder
                        : TariffColors.inputBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      opt.$2,
                      size: 14,
                      color: isSelected
                          ? TariffColors.amberPending
                          : TariffColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      opt.$1,
                      style: TextStyle(
                        color: isSelected
                            ? TariffColors.amberPending
                            : TariffColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAuditButton(bool isAnalyzing) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: isAnalyzing ? null : _runAudit,
        style: ElevatedButton.styleFrom(
          backgroundColor: TariffColors.amberPending,
          foregroundColor: TariffColors.navyDeep,
          disabledBackgroundColor: TariffColors.amberPendingSoft,
          disabledForegroundColor: TariffColors.amberPending,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: isAnalyzing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(TariffColors.amberPending),
                ),
              )
            : const Icon(Icons.bolt_rounded, size: 24),
        label: Text(
          isAnalyzing ? 'Analyzing Cargo...' : '⚡ Run AI Customs Audit',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTariffSearchResults() {
    if (_cargoDescController.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final searchResultAsync = ref.watch(tariffSearchProvider);

    return searchResultAsync.maybeWhen(
      data: (results) {
        if (results.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 8),
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: TariffColors.navySurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: TariffColors.inputBorder),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: results.length,
            separatorBuilder: (_, _) => const Divider(color: TariffColors.divider, height: 1),
            itemBuilder: (context, index) {
              final item = results[index];
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  dense: true,
                  title: Text(
                    item['hs_code'] ?? '',
                    style: const TextStyle(color: TariffColors.amberPending, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    item['description'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: TariffColors.textSecondary, fontSize: 12),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedHsCode = item['hs_code'];
                      _cargoDescController.text = item['description'] ?? '';
                    });
                    ref.read(tariffSearchProvider.notifier).updateQuery('');
                  },
                ),
              );
            },
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: TariffColors.amberPending))),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildFooterNote() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 12,
          color: TariffColors.textMuted,
        ),
        SizedBox(width: 5),
        Text(
          'AES-256 encrypted · Stored in local vault · Tamper-evident',
          style: TextStyle(
            color: TariffColors.textMuted,
            fontSize: 11,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
