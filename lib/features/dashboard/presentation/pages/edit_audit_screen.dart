import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import '../../../audit/domain/entities/hs_audit_result_entity.dart';
import '../../../invoice/domain/entities/invoice_entity.dart';
import '../providers/invoice_list_provider.dart';
import 'package:hscode_auditor/core/util/auto_sync_service.dart';

class EditAuditScreen extends ConsumerStatefulWidget {
  final HsAuditResultEntity audit;

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
  late String _selectedMonth;
  late String _selectedShippingMethod;

  static const List<String> _currencies = ['USD', 'EUR', 'GBP', 'INR', 'JPY', 'CNY', 'RUB'];
  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const List<String> _shippingMethods = ['Air Freight', 'Sea Freight'];

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
    _selectedMonth = widget.audit.plannedMonth;
    _selectedShippingMethod = widget.audit.shippingMethod;
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final repository = ref.read(invoiceRepositoryProvider);
    
    final bool hasStructuralChange = 
        _cargoDescController.text.trim() != widget.audit.cargoDescription ||
        _valueController.text.trim() != widget.audit.declaredValue ||
        _originCountryController.text.trim().toUpperCase() != widget.audit.originCountry ||
        _destCountryController.text.trim().toUpperCase() != widget.audit.destinationCountry ||
        _weightController.text.trim() != widget.audit.totalWeightKg ||
        _selectedMonth != widget.audit.plannedMonth ||
        _selectedShippingMethod != widget.audit.shippingMethod;

    final String finalInvoiceId = widget.audit.invoiceNumber;
    
    HsAuditResultEntity updatedResult;
    String syncStatus;

    if (hasStructuralChange) {
      updatedResult = HsAuditResultEntity(
        hsCode: '${widget.audit.hsCode.replaceAll(' (Offline Draft)', '')} (Offline Draft)',
        userId: widget.audit.userId,
        hsDescription: widget.audit.hsDescription,
        chapter: widget.audit.chapter,
        consignee: _consigneeController.text.trim(),
        invoiceNumber: finalInvoiceId,
        cargoDescription: _cargoDescController.text.trim(),
        standardDutyRate: widget.audit.standardDutyRate,
        vatRate: widget.audit.vatRate,
        totalTaxBurden: widget.audit.totalTaxBurden,
        declaredValue: _valueController.text.trim(),
        currency: _selectedCurrency,
        estimatedDutyAmount: widget.audit.estimatedDutyAmount,
        confidenceScore: 0,
        riskLevel: RiskLevel.medium,
        auditTimestamp: '${DateTime.now().toString().split('.').first} (Edited)',
        originCountry: _originCountryController.text.trim().toUpperCase(),
        destinationCountry: _destCountryController.text.trim().toUpperCase(),
        totalWeightKg: _weightController.text.trim(),
        plannedMonth: _selectedMonth,
        shippingMethod: _selectedShippingMethod,
        isDeleted: widget.audit.isDeleted,
        complianceWarnings: widget.audit.complianceWarnings,
        requiredDocuments: widget.audit.requiredDocuments,
      );
      syncStatus = 'offlineDraft';
    } else {
      updatedResult = HsAuditResultEntity(
        hsCode: widget.audit.hsCode,
        userId: widget.audit.userId,
        hsDescription: widget.audit.hsDescription,
        chapter: widget.audit.chapter,
        consignee: _consigneeController.text.trim(),
        invoiceNumber: finalInvoiceId,
        cargoDescription: widget.audit.cargoDescription,
        standardDutyRate: widget.audit.standardDutyRate,
        vatRate: widget.audit.vatRate,
        totalTaxBurden: widget.audit.totalTaxBurden,
        declaredValue: widget.audit.declaredValue,
        currency: _selectedCurrency,
        estimatedDutyAmount: widget.audit.estimatedDutyAmount,
        confidenceScore: widget.audit.confidenceScore,
        riskLevel: widget.audit.riskLevel,
        auditTimestamp: widget.audit.auditTimestamp,
        originCountry: widget.audit.originCountry,
        destinationCountry: widget.audit.destinationCountry,
        totalWeightKg: widget.audit.totalWeightKg,
        plannedMonth: widget.audit.plannedMonth,
        shippingMethod: widget.audit.shippingMethod,
        isDeleted: widget.audit.isDeleted,
        complianceWarnings: widget.audit.complianceWarnings,
        requiredDocuments: widget.audit.requiredDocuments,
      );
      syncStatus = widget.audit.confidenceScore > 0 ? 'synced' : 'offlineDraft';
    }

    final updatedManifest = InvoiceEntity(
      id: finalInvoiceId,
      userId: widget.audit.userId,
      consignee: updatedResult.consignee,
      cargoDescription: updatedResult.cargoDescription,
      hsCode: updatedResult.hsCode,
      dutyRate: hasStructuralChange ? 'Pending Re-calculation' : widget.audit.standardDutyRate,
      status: syncStatus,
      timestamp: updatedResult.auditTimestamp,
      isDeleted: widget.audit.isDeleted,
    );

    await repository.updateAuditSyncStatus(updatedManifest, updatedResult);

    ref.read(invoiceListProvider.notifier).fetchInvoices();

    if (hasStructuralChange) {
      ref.read(autoSyncServiceProvider).syncPendingAudits();
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasStructuralChange 
              ? 'Changes saved. Record flagged for AI re-verification.' 
              : 'Audit updated successfully.'),
          backgroundColor: TariffColors.greenVerified,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TariffColors.navyDeep,
      appBar: AppBar(
        backgroundColor: TariffColors.navyMid,
        elevation: 0,
        title: const Text('Edit Audit Record', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: const Text('SAVE', style: TextStyle(color: TariffColors.amberPending, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionLabel('CONSIGNEE & REFERENCE'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _consigneeController,
              label: 'Consignee Name',
              icon: Icons.business_rounded,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _invoiceNumberController,
              label: 'Invoice Number',
              icon: Icons.tag_rounded,
              enabled: false,
              helperText: 'Reference ID is immutable',
            ),
            const SizedBox(height: 32),
            _buildSectionLabel('TRADE CORRIDOR'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _originCountryController,
                    label: 'Origin (ISO)',
                    icon: Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _destCountryController,
                    label: 'Import (ISO)',
                    icon: Icons.flag_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionLabel('CARGO & VALUATION'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _cargoDescController,
              label: 'Cargo Description',
              icon: Icons.description_rounded,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _valueController,
                    label: 'Declared Value',
                    icon: Icons.attach_money_rounded,
                    inputType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    label: 'Currency',
                    initialValue: _selectedCurrency,
                    items: _currencies,
                    onChanged: (val) => setState(() => _selectedCurrency = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionLabel('LOGISTICS METRICS'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _weightController,
              label: 'Total Weight',
              icon: Icons.monitor_weight_outlined,
              inputType: TextInputType.number,
              suffix: const Padding(
                padding: EdgeInsets.only(top: 14, right: 12),
                child: Text('kg', style: TextStyle(color: TariffColors.textMuted, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Planned Month',
                    initialValue: _selectedMonth,
                    items: _months,
                    onChanged: (val) => setState(() => _selectedMonth = val!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    label: 'Shipping Method',
                    initialValue: _selectedShippingMethod,
                    items: _shippingMethods,
                    onChanged: (val) => setState(() => _selectedShippingMethod = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TariffColors.navySurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TariffColors.navyElevated),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: TariffColors.textMuted, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Modifying description, value, countries, or logistics metrics will invalidate the current AI certification and flag this record for re-audit.',
                      style: TextStyle(color: TariffColors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(color: TariffColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    String? helperText,
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: inputType,
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      style: const TextStyle(color: TariffColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        suffixIcon: suffix,
        prefixIcon: Icon(icon, size: 20, color: TariffColors.textMuted),
        filled: true,
        fillColor: TariffColors.navySurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TariffColors.inputBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TariffColors.inputBorder)),
      ),
    );
  }
}
