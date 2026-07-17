import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:hscode_auditor/features/audit/data/models/hs_audit_result_model.dart';

/// Corporate-grade PDF Export Service for high-fidelity customs worksheets.
/// Generates A4-compliant manifests designed for physical port inspections and brokerage sign-offs.
class PdfExportService {
  
  /// Generates a professional customs worksheet and opens the native share/print dialog.
  Future<void> generateAndShareAuditPdf(HsAuditResultModel audit) async {
    final doc = pw.Document(
      title: 'Customs_Audit_${audit.invoiceNumber}',
      author: 'TariffGuard AI',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        build: (pw.Context context) {
          return [
            _buildHeader(audit),
            pw.SizedBox(height: 12),
            _buildSectionHeader('SHIPMENT SPECIFICATIONS'),
            _buildShipmentTable(audit),
            pw.SizedBox(height: 12),
            _buildSectionHeader('WCO CLASSIFICATION PANEL'),
            _buildClassificationPanel(audit),
            pw.SizedBox(height: 12),
            _buildSectionHeader('FINANCIAL ASSESSMENT LEDGER'),
            _buildFinancialLedger(audit),
            
            if (audit.complianceWarnings.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              _buildSectionHeader('REGULATORY VECTORS & WARNINGS'),
              _buildWarningBox(audit),
            ],
            
            if (audit.requiredDocuments.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              _buildSectionHeader('PORT CLEARANCE DOCUMENTATION CHECKLIST'),
              _buildDocumentChecklist(audit),
            ],
            
            pw.Spacer(),
            _buildFooter(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'TariffGuard_Report_${audit.invoiceNumber.replaceAll(RegExp(r'[^\w\s]+'), '_')}.pdf',
    );
  }

  // --- LAYOUT HELPERS ---

  pw.Widget _buildHeader(HsAuditResultModel audit) {
    final reportId = 'TG-${audit.invoiceNumber.hashCode.abs().toString().padLeft(8, '0').substring(0, 8)}';
    
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'TARIFFGUARD AI',
              style: pw.TextStyle(
                color: PdfColors.blue900,
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            pw.Text(
              'INTELLIGENCE & COMPLIANCE PLATFORM',
              style: pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 8, letterSpacing: 0.5),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Report No: $reportId',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.Text(
              'Generated: ${audit.auditTimestamp}',
              style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSectionHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            color: PdfColors.blue800,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Container(height: 1.5, color: PdfColors.blue800, width: 40),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildShipmentTable(HsAuditResultModel audit) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        _tableRow('CONSIGNEE', audit.consignee, 'ORIGIN', audit.originCountry),
        _tableRow('REF', audit.invoiceNumber, 'DESTINATION', audit.destinationCountry),
        _tableRow('WEIGHT', '${audit.totalWeightKg} KG', 'METHOD', audit.shippingMethod),
        _tableRow('VALUE', '${audit.currency} ${audit.declaredValue}', 'PLANNED', audit.plannedMonth),
      ],
    );
  }

  pw.TableRow _tableRow(String label1, String val1, String label2, String val2) {
    final labelStyle = pw.TextStyle(color: PdfColors.grey700, fontSize: 6, fontWeight: pw.FontWeight.bold);
    final valueStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8);
    
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label1, style: labelStyle),
              pw.Text(val1, style: valueStyle),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label2, style: labelStyle),
              pw.Text(val2, style: valueStyle),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildClassificationPanel(HsAuditResultModel audit) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('OFFICIAL HS CODE (6-DIGIT)', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 6)),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    audit.hsCode,
                    style: pw.TextStyle(
                      color: PdfColors.blue900, 
                      fontSize: 18, 
                      fontWeight: pw.FontWeight.bold, 
                      font: pw.Font.courierBold(),
                    ),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: audit.confidenceScore >= 80 ? PdfColors.green50 : PdfColors.amber50,
                  border: pw.Border.all(color: audit.confidenceScore >= 80 ? PdfColors.green200 : PdfColors.amber200),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  'CONFIDENCE: ${audit.confidenceScore}%',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: audit.confidenceScore >= 80 ? PdfColors.green900 : PdfColors.amber900,
                  ),
                ),
              ),
            ],
          ),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5, height: 12),
          pw.Text('COMMODITY DESCRIPTION (DECLARED)', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 6)),
          pw.Text(audit.cargoDescription, style: const pw.TextStyle(fontSize: 9, height: 1.2)),
          pw.SizedBox(height: 6),
          pw.Text('WCO TARIFF DESCRIPTION (NOMENCLATURE)', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 6)),
          pw.Text(audit.hsDescription, style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.blueGrey800)),
        ],
      ),
    );
  }

  pw.Widget _buildFinancialLedger(HsAuditResultModel audit) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)},
      children: [
        _ledgerRow('Estimated Standard Import Duty', audit.standardDutyRate),
        _ledgerRow('Estimated Value Added Tax (VAT / GST)', audit.vatRate),
        _ledgerRow('Total Estimated Duty Payable', '${audit.currency} ${audit.estimatedDutyAmount}', isBold: true),
        _ledgerRow('Cumulative Tax Burden (%)', audit.totalTaxBurden, isHighlighted: true),
      ],
    );
  }

  pw.TableRow _ledgerRow(String label, String value, {bool isBold = false, bool isHighlighted = false}) {
    final style = pw.TextStyle(
      fontSize: 9, 
      fontWeight: isBold || isHighlighted ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: isHighlighted ? PdfColors.blue800 : PdfColors.black,
    );
    
    return pw.TableRow(
      decoration: isHighlighted ? const pw.BoxDecoration(color: PdfColors.blue50) : null,
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(label, style: style)),
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(value, textAlign: pw.TextAlign.right, style: style)),
      ],
    );
  }

  pw.Widget _buildWarningBox(HsAuditResultModel audit) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: PdfColors.red50,
        border: pw.Border.all(color: PdfColors.red200),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text('!', style: pw.TextStyle(color: PdfColors.red900, fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(width: 8),
              pw.Text('CRITICAL REGULATORY COMPLIANCE ADVISORY', style: pw.TextStyle(color: PdfColors.red900, fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ],
          ),
          pw.SizedBox(height: 8),
          ...audit.complianceWarnings.map((w) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('* ', style: pw.TextStyle(color: PdfColors.red800)),
                pw.Expanded(child: pw.Text(w, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.red800))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  pw.Widget _buildDocumentChecklist(HsAuditResultModel audit) {
    return pw.Column(
      children: audit.requiredDocuments.map((doc) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          children: [
            pw.Container(
              width: 10,
              height: 10,
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey600, width: 1)),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(child: pw.Text(doc, style: const pw.TextStyle(fontSize: 9))),
          ],
        ),
      )).toList(),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Disclaimer: AI-generated advisory only. Not a legal customs ruling.', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 7)),
                pw.Text('Verify all classifications against current WCO nomenclature before filing.', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 7)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(width: 120, height: 0.5, color: PdfColors.black),
                pw.SizedBox(height: 4),
                pw.Text('SIGN-OFF AUTHORITY (Port Agent / Broker)', style: const pw.TextStyle(fontSize: 7)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Global Riverpod provider for the enterprise PDF export service.
final pdfExportServiceProvider = Provider<PdfExportService>((ref) => PdfExportService());
