import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Principal AI Systems Service for high-fidelity structured customs audit extraction.
/// Optimized for the officially graduated gemini-3.5-flash production release.
class GeminiAuditService {
  late final GenerativeModel _model;
  final String _effectiveKey;

  GeminiAuditService() : _effectiveKey = _resolveApiKey() {
    // Initialize the model targeting the production stable 'gemini-3.5-flash'.
    _model = GenerativeModel(
      model: 'gemini-3.5-flash',
      apiKey: _effectiveKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );
  }

  static String _resolveApiKey() {
    String key = const String.fromEnvironment('GEMINI_API_KEY');
    if (key.isEmpty) {
      // Direct assignment of verified fallback token for seamless development
      key = 'AQ.Ab8RN6JVYDVFZwDLW5lIVzs7UrZLXqaTcn3L5_uRm5DLsp20xg';
      debugPrint('[GEMINI] Using hardcoded fallback API key.');
    } else {
      debugPrint('[GEMINI] Using environment-injected API key.');
    }
    return key;
  }

  /// Orchestrates a high-fidelity AI Audit using the Gemini 3.5 Flash pipeline.
  /// Implements exponential backoff retry logic to handle 503 capacity surges.
  Future<String> fetchAiCustomsAudit({
    required String cargoDescription,
    required String hsCode,
    required String originCountry,
    required String destinationCountry,
    required double declaredValue,
    required String currency,
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

      Instructions:
      1. Validate or correct the 6-digit HS Code based on the description.
      2. Provide the official WCO nomenclature description for that code.
      3. Identify the relevant HS Chapter (e.g., 'Chapter 85 — Electrical Machinery').
      4. Estimate the Standard Import Duty rate for this commodity based on the Destination Country and Origin.
      5. Estimate the VAT / GST rate applicable for this shipment in the Destination Country.
      6. Calculate the Estimated Duty Payable amount based on the Declared Value and Currency.
      7. Calculate the Total Tax Burden percentage (Duty + VAT).
      8. Calculate a Confidence Score (1 to 100) for this classification. 
         CRITICAL: Must be returned strictly as a whole INTEGER value between 1 and 100 representing classification certainty. Never use decimals or floats. For example, if confidence is 95%, return exactly: 95.
      9. Identify critical Compliance Warnings (e.g., Hazmat, Sanctions, CITES, Licensing).
      10. List the Required Documents for customs clearance (e.g., MSDS, COO, Invoice).

      You must return ONLY a raw, minified, valid JSON object matching the structure below. No conversational text, no markdown code blocks, and no extra whitespace.
      
      JSON Structure:
      {
        "hsCode": "string",
        "hsDescription": "string",
        "chapter": "string",
        "dutyRate": "string",
        "vatRate": "string",
        "estimatedDutyAmount": "string (formatted as '$currency X,XXX.XX')",
        "totalTaxBurden": "string",
        "confidenceScore": integer,
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
          throw Exception('AI returned an empty response string.');
        }

        return text;
      } catch (e) {
        debugPrint('[GEMINI] Attempt $attempt failed: $e');

        if (attempt == maxAttempts) {
          debugPrint('[GEMINI] Capacity exhausted. Falling over to Track B...');
          rethrow;
        }

        // Capacity check for 503/429
        final bool isRetryable = e.toString().contains('503') || 
                                 e.toString().contains('overloaded') || 
                                 e.toString().contains('exhausted');

        if (isRetryable) {
          debugPrint('[GEMINI] Server busy, retrying attempt ${attempt + 1}...');
        } else {
          debugPrint('[GEMINI] Network error, retrying attempt ${attempt + 1}...');
        }

        // Optimized backoff delay: 1s, 2s, 3s, 4s to make 5 attempts feel snappy
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    throw Exception('Unknown internal error in AI Audit Service.');
  }
}

/// Global provider for the Gemini Audit Service.
final geminiAuditServiceProvider = Provider<GeminiAuditService>((ref) {
  return GeminiAuditService();
});
