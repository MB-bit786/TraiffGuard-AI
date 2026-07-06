import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import '../../../../core/util/auth_service.dart';
import '../../../audit/data/models/hs_audit_result_model.dart';
import '../providers/invoice_list_provider.dart';
import '../../../invoice/presentation/providers/invoice_providers.dart';
import '../../../invoice/domain/entities/invoice_entity.dart';

class EditAuditScreen extends ConsumerStatefulWidget {
  final HsAuditResultModel audit;
  const EditAuditScreen({super.key, required this.audit});

  @override
  ConsumerState<EditAuditScreen> createState() => _EditAuditScreenState();
}

class _EditAuditScreenState extends ConsumerState<EditAuditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _cargoDescController;
  late TextEditingController _hsCodeController;
  late TextEditingController _valueController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargoDescController = TextEditingController(text: widget.audit.cargoDescription);
    _hsCodeController = TextEditingController(text: widget.audit.hsCode);
    _valueController = TextEditingController(text: widget.audit.declaredValue);
  }

  @override
  void dispose() {
    _cargoDescController.dispose();
    _hsCodeController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repository = ref.read(invoiceRepositoryProvider);
      final user = ref.read(authStateProvider).value;
      final userId = user?.uid ?? 'anonymous';

      final updatedAudit = HsAuditResultModel(
        hsCode: _hsCodeController.text.trim(),
        userId: userId,
        hsDescription: widget.audit.hsDescription,
        chapter: widget.audit.chapter,
        consignee: widget.audit.consignee,
        invoiceNumber: widget.audit.invoiceNumber,
        cargoDescription: _cargoDescController.text.trim(),
        standardDutyRate: widget.audit.standardDutyRate,
        vatRate: widget.audit.vatRate,
        totalTaxBurden: widget.audit.totalTaxBurden,
        declaredValue: _valueController.text.trim(),
        currency: widget.audit.currency,
        estimatedDutyAmount: widget.audit.estimatedDutyAmount,
        confidenceScore: widget.audit.confidenceScore,
        complianceWarnings: widget.audit.complianceWarnings,
        requiredDocuments: widget.audit.requiredDocuments,
        auditTimestamp: widget.audit.auditTimestamp,
        riskLevel: widget.audit.riskLevel,
        originCountry: widget.audit.originCountry,
        destinationCountry: widget.audit.destinationCountry,
        totalWeightKg: widget.audit.totalWeightKg,
        plannedMonth: widget.audit.plannedMonth,
        shippingMethod: widget.audit.shippingMethod,
        isDeleted: widget.audit.isDeleted,
      );

      final updatedManifest = InvoiceEntity(
        id: updatedAudit.invoiceNumber,
        userId: updatedAudit.userId,
        consignee: updatedAudit.consignee,
        cargoDescription: updatedAudit.cargoDescription,
        hsCode: updatedAudit.hsCode,
        dutyRate: '${updatedAudit.standardDutyRate} Duty',
        status: 'synced', // Or keep original status
        timestamp: updatedAudit.auditTimestamp,
        isDeleted: updatedAudit.isDeleted,
      );

      await repository.cacheInvoiceManifest(updatedManifest, auditResult: updatedAudit);

      if (mounted) {
        ref.read(invoiceListProvider.notifier).fetchInvoices();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audit updated successfully'), backgroundColor: TariffColors.greenVerified),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving changes: $e'), backgroundColor: TariffColors.crimsonRisk),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TariffColors.navyDeep,
      appBar: AppBar(
        backgroundColor: TariffColors.navyMid,
        title: const Text('Edit Audit Details', style: TextStyle(color: TariffColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
        actions: [
          if (!_isSaving)
            TextButton(
              onPressed: _saveChanges,
              child: const Text('SAVE', style: TextStyle(color: TariffColors.amberPending, fontWeight: FontWeight.bold)),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: TariffColors.amberPending))),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildField('CARGO DESCRIPTION', _cargoDescController, maxLines: 3),
            const SizedBox(height: 20),
            _buildField('HS CODE', _hsCodeController),
            const SizedBox(height: 20),
            _buildField('DECLARED VALUE', _valueController, inputType: TextInputType.number),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {int maxLines = 1, TextInputType inputType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: TariffColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: inputType,
          style: const TextStyle(color: TariffColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: TariffColors.navySurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TariffColors.cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TariffColors.cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TariffColors.amberPending, width: 1.5)),
          ),
          validator: (v) => (v == null || v.isEmpty) ? 'Field cannot be empty' : null,
        ),
      ],
    );
  }
}
