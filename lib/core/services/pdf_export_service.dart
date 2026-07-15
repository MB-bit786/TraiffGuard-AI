import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExportService {
  static Future<void> exportAuditReport(BuildContext context, Map<String, dynamic> auditData) async {
    try {
      debugPrint('[PDF] Starting export for ${auditData['invoiceNumber']}');
      final doc = pw.Document();

      // 1. Robust Data Extraction
      final String invoiceNumber = auditData['invoiceNumber']?.toString() ?? 'N/A';
      final String consignee = auditData['consignee']?.toString() ?? 'N/A';
      final String hsCode = auditData['hsCode']?.toString() ?? 'N/A';
      final String currency = auditData['currency']?.toString() ?? 'USD';
      final String declaredValue = auditData['declaredValue']?.toString() ?? '0.00';
      final String estimatedDuty = auditData['estimatedDutyAmount']?.toString() ?? '0.00';
      final String dutyRate = auditData['standardDutyRate']?.toString() ?? '0.0%';
      final String vatRate = auditData['vatRate']?.toString() ?? '0.0%';
      final String riskLevel = auditData['riskLevel']?.toString() ?? 'low';
      final String confidence = auditData['confidenceScore']?.toString() ?? '0';

      // 2. Advanced List Parsing (Handles raw lists and JSON strings)
      List<String> parseList(dynamic raw) {
        if (raw == null) return [];
        if (raw is List) return List<String>.from(raw);
        if (raw is String && raw.isNotEmpty) {
          try {
            if (raw.startsWith('[')) {
              final decoded = json.decode(raw);
              if (decoded is List) return List<String>.from(decoded);
            }
            // If it's a non-JSON string, treat as single item if not empty
            if (raw.trim().isNotEmpty) return [raw.trim()];
          } catch (e) {
            debugPrint('[PDF] List parse warning: $e');
            return [raw];
          }
        }
        return [];
      }

      final List<String> warningsList = parseList(auditData['complianceWarnings']);
      final List<String> documentsList = parseList(auditData['requiredDocuments']);
      
      debugPrint('[PDF] Extracted ${warningsList.length} warnings and ${documentsList.length} docs');

      // 3. Professional Status Mapping
      String statusLabel = 'PASSED';
      PdfColor statusColor = PdfColors.green700;
      
      final String rl = riskLevel.toLowerCase();
      if (rl == 'low') {
        statusLabel = 'VERIFIED';
        statusColor = PdfColors.green700;
      } else if (rl == 'medium') {
        statusLabel = 'FLAGGED';
        statusColor = PdfColors.orange700;
      } else if (rl == 'high') {
        statusLabel = 'CRITICAL';
        statusColor = PdfColors.red700;
      } else if (rl.contains('offline')) {
        statusLabel = 'OFFLINE DRAFT';
        statusColor = PdfColor.fromHex('#D97706');
      }

      // 4. Color Definitions
      final PdfColor primaryColor = PdfColor.fromHex('#1A2530');
      final PdfColor accentColor = PdfColor.fromHex('#D97706');
      final PdfColor lightBgColor = PdfColor.fromHex('#F8FAFC');
      final PdfColor borderGrey = PdfColor.fromHex('#E2E8F0');

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 1. HEADER BANNER (Compressed)
                pw.Container(
                  color: primaryColor,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  width: double.infinity,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'TARIFFGUARD AI',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 1),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'OFFICIAL CUSTOMS COMPLIANCE ASSESSMENT',
                            style: pw.TextStyle(color: PdfColors.grey400, fontSize: 8, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'AUDIT CERTIFICATE',
                            style: pw.TextStyle(color: accentColor, fontSize: 10, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Issued: ${DateTime.now().toString().substring(0, 16)}',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // 2. SHIPMENT IDENTIFICATION
                pw.Text('SHIPMENT IDENTIFICATION', style: pw.TextStyle(color: primaryColor, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Container(
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: borderGrey, width: 1), color: lightBgColor),
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.RichText(text: pw.TextSpan(children: [
                            pw.TextSpan(text: 'Invoice Reference: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            pw.TextSpan(text: invoiceNumber, style: const pw.TextStyle(fontSize: 10)),
                          ]))),
                          pw.Expanded(child: pw.RichText(text: pw.TextSpan(children: [
                            pw.TextSpan(text: 'Consignee: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            pw.TextSpan(text: consignee, style: const pw.TextStyle(fontSize: 10)),
                          ]))),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.RichText(text: pw.TextSpan(children: [
                            pw.TextSpan(text: 'Assessed HS Code: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: accentColor)),
                            pw.TextSpan(text: hsCode, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ]))),
                          pw.Expanded(child: pw.RichText(text: pw.TextSpan(children: [
                            pw.TextSpan(text: 'System Status: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            pw.TextSpan(text: statusLabel, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: statusColor)),
                          ]))),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // 3. FINANCIAL TARIFF BREAKDOWN
                pw.Text('FINANCIAL TARIFF BREAKDOWN', style: pw.TextStyle(color: primaryColor, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(color: borderGrey, width: 1),
                  columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2)},
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: primaryColor),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Assessment Item Line', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Calculated Value', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Declared Customs Cargo Valuation', style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$currency $declaredValue', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
                      ],
                    ),
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: lightBgColor),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Standard Statutory Import Duty Rate', style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(dutyRate, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Value Added Tax / GST Rate', style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(vatRate, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FEF3C7')),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('ESTIMATED TOTAL DUTY PAYABLE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor))),
                        pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('$currency $estimatedDuty', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#B45309')))),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 18),

                // 4. REGULATORY RISK & COMPLIANCE
                pw.Text('REGULATORY RISK VECTORS & COMPLIANCE NOTES', style: pw.TextStyle(color: primaryColor, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Container(
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    border: pw.Border(left: pw.BorderSide(color: accentColor, width: 4)),
                    color: lightBgColor,
                  ),
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('AI Verification Confidence:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primaryColor)),
                          pw.Text('$confidence%', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: (int.tryParse(confidence) ?? 0) > 70 ? PdfColors.green700 : accentColor)),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Screening Logs:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                      if (warningsList.isEmpty) 
                        pw.Padding(padding: const pw.EdgeInsets.only(left: 10, top: 2), child: pw.Text('No compliance warnings flagged.', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)))
                      else
                        ...warningsList.map((w) => pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 10, top: 2),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('- ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                              pw.Expanded(child: pw.Text(w, style: const pw.TextStyle(fontSize: 9.5))),
                            ],
                          ),
                        )),
                      pw.SizedBox(height: 8),
                      pw.Text('Required Port Clearance Documentation:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                      if (documentsList.isEmpty)
                        pw.Padding(padding: const pw.EdgeInsets.only(left: 10, top: 2), child: pw.Text('Standard trade documentation required.', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)))
                      else
                        ...documentsList.map((d) => pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 10, top: 2),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('- ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                              pw.Expanded(child: pw.Text(d, style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic))),
                            ],
                          ),
                        )),
                    ],
                  ),
                ),
                
                pw.Spacer(),

                // 5. FOOTER
                pw.Column(
                  children: [
                    pw.Divider(color: borderGrey, thickness: 1),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TariffGuard AI Enterprise Compliance Protocol v3.0', style: pw.TextStyle(color: PdfColors.grey500, fontSize: 7)),
                        pw.Text('Certification ID: ${invoiceNumber.hashCode.abs().toString().padLeft(8, '0')}', style: pw.TextStyle(color: PdfColors.grey500, fontSize: 7)),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final Uint8List bytes = await doc.save();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'TariffGuard_Audit_${invoiceNumber.replaceAll('/', '_')}',
      );
    } catch (e) {
      debugPrint('[PDF] Export Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
