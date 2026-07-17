import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Principal AI Systems Service for high-fidelity structured customs audit extraction.
/// Implements advanced "Node-Hopping" and exponential backoff to handle 503 capacity surges.
class GeminiAuditService {
  late GenerativeModel _model;
  final String _effectiveKey;
  
  // High-performance model targets
  static const String _primaryModel = 'gemini-3.5-flash';
  static const String _fallbackModel = 'gemini-2.5-flash'; // High-availability stable node

  GeminiAuditService() : _effectiveKey = _resolveApiKey() {
    _initModel(_primaryModel);
  }

  void _initModel(String modelName) {
    debugPrint('[GEMINI] Initializing node: $modelName');
    _model = GenerativeModel(
      model: modelName,
      apiKey: _effectiveKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );
  }

  static String _resolveApiKey() {
    String key = const String.fromEnvironment('GEMINI_API_KEY');
    if (key.isEmpty) {
      // Verified fallback token for production stability
      key = 'AQ.Ab8RN6L-atHsMcTQqXNQnrR7YhP0X3CuHIKFGZsyfMMoSZ0XYA';
      debugPrint('[GEMINI] Using hardcoded fallback API key.');
    } else {
      debugPrint('[GEMINI] Using environment-injected API key.');
    }
    return key;
  }

  /// Orchestrates a high-fidelity AI Audit with integrated fault tolerance.
  /// Automatically switches nodes (Node-Hopping) after multiple 503 failures.
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
  }) async {
    final prompt = '''
      Act as an expert World Customs Organization (WCO) customs auditor. 
      Analyze the following shipment parameters to provide a high-fidelity classification and risk report:
      - Cargo Description: "$cargoDescription"
      - Suggested/Initial HS Code: "$hsCode"
      - Origin Country (Made in): "$originCountry"
      - Destination Country (Importing to): "$destinationCountry"
      - Declared Value: $declaredValue
      - Currency: "$currency"
      - Total Weight: $totalWeightKg kg
      - Planned Month of Entry: $plannedMonth
      - Shipping Method: $shippingMethod

      CRITICAL INPUT VALIDATION GUARDRAIL: Before executing any customs analysis, evaluate if the input description is a valid commercial product or cargo description. If the description contains conversational chatter (e.g., 'how are you', 'tell me a joke'), personal names, greeting strings, or non-shipping text, you must immediately halt analysis. In this scenario, return a valid JSON map matching our schema where 'confidenceScore' is strictly set to 0, 'riskLevel' is set to 'INVALID_INPUT', and 'complianceWarnings' contains the exact string: 'ERROR: The description provided does not contain a recognizable commercial commodity or cargo type. Please enter a valid item name (e.g., Mangoes, Textiles, Electronics) to proceed.'

      Instructions:
      1. Validate or correct the 6-digit HS Code based on the description.
      2. Provide the official WCO nomenclature description for that code.
      3. Identify the relevant HS Chapter (e.g., 'Chapter 85 — Electrical Machinery').
      4. Estimate the Standard Import Duty rate for this commodity based on the Destination Country and Origin.
      5. Estimate the VAT / GST rate applicable for this shipment in the Destination Country.
      6. Calculate the Estimated Duty Payable amount based on the Declared Value and Currency.
      7. Calculate the Total Tax Burden percentage (Duty + VAT).
      8. Calculate a Confidence Score (1 to 100) for this classification. 
         CRITICAL: Must be returned strictly as a whole INTEGER value between 1 and 100.
      9. Identify critical Compliance Warnings (e.g., Hazmat, Sanctions, CITES, Licensing).
      10. List the Required Documents for customs clearance (e.g., MSDS, COO, Invoice).

      You must return ONLY a raw, minified, valid JSON object matching the structure below. No conversational text, no markdown code blocks.
      
      JSON Structure:
      {
        "hsCode": "string",
        "hsDescription": "string",
        "chapter": "string",
        "dutyRate": "string",
        "vatRate": "string",
        "estimatedDutyAmount": "string (numeric)",
        "totalTaxBurden": "string",
        "confidenceScore": integer,
        "riskLevel": "string",
        "complianceWarnings": ["string"],
        "requiredDocuments": ["string"]
      }
    ''';

    const int maxAttempts = 5;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _model.generateContent([Content.text(prompt)]);
        final text = response.text;

        if (text == null) {
          throw Exception('AI returned empty response.');
        }

        return text;
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        debugPrint('[GEMINI] Attempt $attempt failed: $e');

        if (attempt == maxAttempts) {
          debugPrint('[GEMINI] All nodes exhausted. Falling back to Track B...');
          rethrow;
        }

        // Capacity check for 503/429
        final bool isRetryable = errorStr.contains('503') ||
            errorStr.contains('overloaded') ||
            errorStr.contains('exhausted') ||
            errorStr.contains('429');

        if (isRetryable) {
          // Node-Hopping: Switch to the high-availability node after 2 failures
          if (attempt == 2) {
            debugPrint('[GEMINI] Node Congestion Detected. Hopping to node: $_fallbackModel');
            _initModel(_fallbackModel);
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
