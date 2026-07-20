import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Principal AI Systems Service for high-fidelity structured customs audit extraction.
/// Implements persistent node-hopping and environment-secured credentials.
class GeminiAuditService {
  final GenerativeModel _primaryNode;
  final GenerativeModel _fallbackNode;
  bool _useFallback = false;

  // High-performance model targets
  static const String _primaryModelName = 'gemini-3.5-flash';
  static const String _fallbackModelName = 'gemini-2.5-flash';

  GeminiAuditService()
      : _primaryNode = _createModel(_primaryModelName),
        _fallbackNode = _createModel(_fallbackModelName);

  /// Resolved active model reference based on current node health status.
  GenerativeModel get _activeModel => _useFallback ? _fallbackNode : _primaryNode;

  static GenerativeModel _createModel(String modelName) {
    final apiKey = _resolveApiKey();
    return GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );
  }

  /// Secure API Key resolution.
  /// Throws a StateError if the environment variable is missing to prevent runtime crashes.
  static String _resolveApiKey() {
    const key = String.fromEnvironment('GEMINI_API_KEY');
    if (key.isEmpty) {
      throw StateError(
        'CRITICAL: GEMINI_API_KEY environment variable is not defined.\n'
        'Please run the application with: --dart-define=GEMINI_API_KEY=your_key_here\n'
        'or use --dart-define-from-file=secrets.json',
      );
    }
    return key;
  }

  /// Strips Markdown code blocks and cleans the AI response for JSON parsing.
  String _cleanJsonResponse(String rawResponse) {
    String cleaned = rawResponse.trim();
    // Strip leading ```json or ```
    if (cleaned.startsWith('```')) {
      final lines = cleaned.split('\n');
      if (lines.first.startsWith('```')) {
        lines.removeAt(0);
      }
      if (lines.isNotEmpty && lines.last.startsWith('```')) {
        lines.removeLast();
      }
      cleaned = lines.join('\n').trim();
    }
    return cleaned;
  }

  /// Orchestrates a high-fidelity AI Audit with integrated fault tolerance.
  /// Node-Hopping occurs after multiple capacity failures without object recreation.
  Future<String> fetchAiCustomsAudit({
    required String cargoDescription,
    required String hsCode,
    required String originCountry,
    required String destinationCountry,
    required double declaredValue,
    required String currency,
    required String totalWeightKg,
    required String plannedMonth,
    required String shippingMethod,
    required String originPort,
    required String destinationPort,
  }) async {
    final prompt = '''
      Act as an expert World Customs Organization (WCO) customs auditor. 
      Analyze the following shipment parameters to provide a high-fidelity classification and risk report:
      - Cargo Description: "$cargoDescription"
      - Suggested/Initial HS Code: "$hsCode"
      - Origin Country (Made in): "$originCountry"
      - Destination Country (Importing to): "$destinationCountry"
      - Origin Port (Departure): "$originPort"
      - Destination Port (Arrival): "$destinationPort"
      - Declared Value: $declaredValue
      - Currency: "$currency"
      - Total Weight: $totalWeightKg kg
      - Planned Month of Entry: $plannedMonth
      - Shipping Method: $shippingMethod

      CRITICAL INPUT VALIDATION GUARDRAIL: Before executing any customs analysis, evaluate if the input description is a valid commercial product or cargo description. If the description contains conversational chatter (e.g., 'how are you', 'tell me a joke'), personal names, greeting strings, or non-shipping text, you must immediately halt analysis. In this scenario, return a valid JSON map matching our schema where 'confidenceScore' is strictly set to 0, 'riskLevel' is set to 'INVALID_INPUT', and 'complianceWarnings' contains the exact string: 'ERROR: The description provided does not contain a recognizable commercial commodity or cargo type. Please enter a valid item name (e.g., Mangoes, Textiles, Electronics) to proceed.'

      Instructions:
      1. Validate or correct the 6-digit HS Code based on the description.
      2. Determine the country-specific national suffix extension (e.g. HTSUS for US, TARIC for EU, ITC-HS for India) based on the destination country. Provide both the code (8, 10, or 12 digits) and its specific tariff description.
      3. Identify the relevant HS Chapter (e.g., 'Chapter 85 — Electrical Machinery').
      4. Estimate the Standard Import Duty rate for this commodity based on the Destination Country and Origin.
      5. Estimate the VAT / GST rate applicable for this shipment in the Destination Country.
      6. Calculate the Estimated Duty Payable amount based on the Declared Value and Currency.
      7. Parse local seaport transit dues, security fees, and Terminal Handling Charges (THC) between "$originPort" and "$destinationPort".
      8. Calculate the Total Tax Burden percentage (Duty + VAT).
      9. Calculate a Confidence Score (1 to 100) for this classification. 
      10. Identify critical Compliance Warnings (e.g., Hazmat, Sanctions, CITES, Licensing).
      11. List the Required Documents for customs clearance.

      You must return ONLY a raw, minified, valid JSON object matching the structure below. No conversational text, no markdown code blocks.
      
      JSON Structure:
      {
        "hsCode": "string (6-digit universal)",
        "nationalExtensionCode": "string (full national code)",
        "nationalExtensionDescription": "string (detailed national tariff text)",
        "hsDescription": "string (universal description)",
        "chapter": "string",
        "dutyRate": "string",
        "vatRate": "string",
        "estimatedDutyAmount": "string (numeric)",
        "totalTaxBurden": "string",
        "confidenceScore": integer,
        "riskLevel": "string",
        "complianceWarnings": ["string"],
        "requiredDocuments": ["string"],
        "originPort": "string",
        "destinationPort": "string",
        "portCharges": [{"chargeName": "string", "amount": "string", "currency": "string"}]
      }
    ''';

    const int maxAttempts = 5;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _activeModel.generateContent([Content.text(prompt)]);
        final rawText = response.text;

        if (rawText == null) {
          throw Exception('AI returned empty response.');
        }

        final cleanedText = _cleanJsonResponse(rawText);

        // Integrity Check: Verify JSON structure before returning
        try {
          jsonDecode(cleanedText);
        } catch (e) {
          throw Exception('AI response failed integrity check: Invalid JSON structure.');
        }

        return cleanedText;
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        debugPrint('[GEMINI] Attempt $attempt failed: $e');

        if (attempt == maxAttempts) {
          debugPrint('[GEMINI] All nodes exhausted.');
          rethrow;
        }

        // Capacity check for 503/429
        final bool isRetryable = errorStr.contains('503') ||
            errorStr.contains('overloaded') ||
            errorStr.contains('exhausted') ||
            errorStr.contains('429');

        if (isRetryable) {
          // Node-Hopping: Switch to the high-availability node after 2 failures
          if (attempt == 2 && !_useFallback) {
            debugPrint('[GEMINI] Node Congestion. Hopping to High-Availability node: $_fallbackModelName');
            _useFallback = true;
          }
          debugPrint('[GEMINI] Server busy, retrying attempt ${attempt + 1}...');
        } else {
          debugPrint('[GEMINI] Network/Internal error, retrying attempt ${attempt + 1}...');
        }

        // Exponential backoff: 2s, 4s, 8s, 16s
        await Future.delayed(Duration(seconds: 1 << attempt));
      }
    }

    throw Exception('Unknown pipeline error in AI Audit Service.');
  }
}

/// Global provider for the Gemini Audit Service.
final geminiAuditServiceProvider = Provider<GeminiAuditService>((ref) {
  return GeminiAuditService();
});
