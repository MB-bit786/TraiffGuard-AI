import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/core/theme/tariff_colors.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/connection_provider.dart';
import 'package:hscode_auditor/features/invoice/presentation/providers/invoice_form_notifier.dart';
import 'package:hscode_auditor/features/search/presentation/providers/tariff_search_provider.dart';

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

  String _selectedCurrency = 'USD';
  String? _selectedHsCode;

  static const List<String> _currencies = [ 'USD', 'EUR', 'GBP', 'INR', 'JPY', 'CNY', 'RUB'];

  @override
  void initState() {
    super.initState();
    _cargoDescController.addListener(() {
      // Trigger a local rebuild to show/hide the results overlay based on text presence
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
    super.dispose();
  }

  Future<void> _runAudit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(invoiceFormNotifierProvider.notifier).processCustomsAudit(
          invoiceNumber: _invoiceNumberController.text,
          consignee: _consigneeController.text,
          cargoDescription: _cargoDescController.text,
          originCountry: _originCountryController.text,
          destCountry: _destCountryController.text,
          declaredValue: double.tryParse(_valueController.text) ?? 0.0,
          currency: _selectedCurrency,
          hsCode: _selectedHsCode,
        );

    if (mounted && success) {
      final state = ref.read(invoiceFormNotifierProvider);
      
      if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error!),
            backgroundColor: TariffColors.amberPending,
          ),
        );
      }

      if (state.result != null) {
        Navigator.of(context).pushNamed('/audit-result', arguments: state.result);
      } else {
        // If it was just a local save (offline), go back to dashboard
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(connectionProvider);
    final isOnline = connection.isOnline;
    final isOffline = !isOnline;
    final isAnalyzing = ref.watch(invoiceFormNotifierProvider.select((s) => s.isAnalyzing));

    return Scaffold(
      backgroundColor: TariffColors.navyDeep,
      appBar: _buildAppBar(context),
      body: _buildBody(isOffline, isAnalyzing),
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
            'New Customs Audit',
            style: TextStyle(
              color: TariffColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'INVOICE ENTRY FORM',
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
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: TariffColors.navySurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: TariffColors.cardBorder, width: 1),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.save_outlined,
                color: TariffColors.textSecondary,
                size: 15,
              ),
              SizedBox(width: 5),
              Text(
                'Draft',
                style: TextStyle(
                  color: TariffColors.textSecondary,
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
        child: Container(height: 1, color: TariffColors.divider),
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
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: TariffColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: TariffColors.divider),
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      validator: validator,
      style: const TextStyle(
        color: TariffColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: TariffColors.textMuted),
        labelStyle: const TextStyle(
          color: TariffColors.textSecondary,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          color: TariffColors.textMuted,
          fontSize: 13,
        ),
        filled: true,
        fillColor: TariffColors.navySurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: TariffColors.inputBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: TariffColors.inputBorder, width: 1),
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
    return TextFormField(
      controller: _cargoDescController,
      maxLines: 5,
      minLines: 4,
      validator: (v) => (v == null || v.trim().length < 10)
          ? 'Please describe the cargo (min. 10 characters)'
          : null,
      style: const TextStyle(
        color: TariffColors.textPrimary,
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
        prefixIcon: const Padding(
          padding: EdgeInsets.only(bottom: 60),
          child: Icon(
            Icons.description_rounded,
            size: 18,
            color: TariffColors.textMuted,
          ),
        ),
        labelStyle: const TextStyle(
          color: TariffColors.textSecondary,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          color: TariffColors.textMuted,
          fontSize: 13,
          height: 1.6,
        ),
        helperStyle: const TextStyle(
          color: TariffColors.textMuted,
          fontSize: 11.5,
          height: 1.5,
        ),
        filled: true,
        fillColor: TariffColors.navySurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: TariffColors.inputBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: TariffColors.inputBorder, width: 1),
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
          child: TextFormField(
            controller: _valueController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: TariffColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: 'Declared Value',
              hintText: 'e.g. 48500',
              prefixIcon: const Icon(
                Icons.attach_money_rounded,
                size: 18,
                color: TariffColors.textMuted,
              ),
              labelStyle: const TextStyle(
                color: TariffColors.textSecondary,
                fontSize: 13,
              ),
              hintStyle: const TextStyle(
                color: TariffColors.textMuted,
                fontSize: 13,
              ),
              filled: true,
              fillColor: TariffColors.navySurface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: TariffColors.inputBorder, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: TariffColors.inputBorder, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: TariffColors.inputFocusBorder, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            height: 51,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: TariffColors.navySurface,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: TariffColors.inputBorder, width: 1),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCurrency,
                dropdownColor: TariffColors.navyElevated,
                icon: const Icon(
                  Icons.expand_more_rounded,
                  color: TariffColors.textSecondary,
                  size: 20,
                ),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedCurrency = value);
                },
                items: _currencies
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          c,
                          style: const TextStyle(
                            color: TariffColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
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
    // UI Guard: Do not show the suggestion overlay if the user hasn't typed anything
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
                    // Clear search results after selection
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
