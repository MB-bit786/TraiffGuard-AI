class AppConstants {
  AppConstants._();

  static const String appVersion = 'v1.0.0';
  static const String aiModelVersion = 'v3.2.1';
  static const String legalProtocolVersion = 'v1.0.0';
  
  static const String appName = 'TariffGuard AI';

  // Master Data Lists
  static const List<String> currencies = ['USD', 'EUR', 'GBP', 'INR', 'JPY', 'CNY', 'RUB'];
  static const List<String> months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const List<String> shippingMethods = ['Air Freight', 'Sea Freight'];

  static const List<String> mainCountries = [
    'China', 'United States', 'India', 'Germany', 'Japan', 
    'Vietnam', 'Mexico', 'United Kingdom', 'France', 'Canada', 
    'Netherlands', 'Singapore', 'Italy', 'South Korea', 'Brazil',
    'United Arab Emirates', 'Saudi Arabia', 'Qatar', 'Oman', 'Kuwait', 'Jordan'
  ];

  static const Map<String, List<String>> countryPorts = {
    'China': ['Shanghai', 'Ningbo-Zhoushan', 'Shenzhen', 'Guangzhou', 'Qingdao', 'Tianjin'],
    'United States': ['Los Angeles', 'Long Beach', 'New York/New Jersey', 'Savannah', 'Houston'],
    'India': ['Mumbai (JNPT)', 'Mundra', 'Chennai', 'Kolkata', 'Kochi', 'Visakhapatnam'],
    'Germany': ['Hamburg', 'Bremen/Bremerhaven', 'Wilhelmshaven'],
    'Japan': ['Tokyo', 'Yokohama', 'Nagoya', 'Osaka', 'Kobe'],
    'Vietnam': ['Ho Chi Minh City', 'Hai Phong', 'Da Nang'],
    'Mexico': ['Manzanillo', 'Lazaro Cardenas', 'Veracruz'],
    'United Kingdom': ['Felixstowe', 'Southampton', 'London Gateway', 'Liverpool'],
    'France': ['Le Havre', 'Marseille', 'Dunkerque'],
    'Canada': ['Vancouver', 'Montreal', 'Prince Rupert', 'Halifax'],
    'Netherlands': ['Rotterdam', 'Amsterdam'],
    'Singapore': ['Singapore'],
    'Italy': ['Genoa', 'Trieste', 'Gioia Tauro'],
    'South Korea': ['Busan', 'Incheon', 'Gwangyang'],
    'Brazil': ['Santos', 'Itajai', 'Paranagua'],
    'United Arab Emirates': ['Jebel Ali (Dubai)', 'Khalifa Port (Abu Dhabi)', 'Port Rashid'],
    'Saudi Arabia': ['Jeddah Islamic Port', 'King Abdulaziz Port (Dammam)', 'King Abdullah Port'],
    'Qatar': ['Hamad Port'],
    'Oman': ['Port of Salalah', 'Sohar Port', 'Port of Duqm'],
    'Kuwait': ['Shuwaikh Port', 'Shuaiba Port'],
    'Jordan': ['Port of Aqaba'],
  };

  static const int kPromptVersion = 1;
  static const int kTariffDatasetVersion = 2;

  static String normalizeHsCode(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 6 ? digits.substring(0, 6) : digits;
  }

  static const String kClassificationPromptTemplate = '''
      Act as an expert World Customs Organization (WCO) customs auditor. 
      Analyze the following shipment parameters to provide a high-fidelity classification and risk report:
      - Cargo Description: "{cargoDescription}"
      - Suggested/Initial HS Code: "{hsCode}"
      - Origin Country (Made in): "{originCountry}"
      - Destination Country (Importing to): "{destinationCountry}"
      - Origin Port (Departure): "{originPort}"
      - Destination Port (Arrival): "{destinationPort}"
      - Declared Value: {declaredValue}
      - Currency: "{currency}"
      - Total Weight: {totalWeightKg} kg
      - Planned Month of Entry: {plannedMonth}
      - Shipping Method: {shippingMethod}

      CRITICAL INPUT VALIDATION GUARDRAIL: Before executing any customs analysis, evaluate if the input description is a valid commercial product or cargo description. If the description contains conversational chatter (e.g., 'how are you', 'tell me a joke'), personal names, greeting strings, or non-shipping text, you must immediately halt analysis. In this scenario, return a valid JSON map matching our schema where 'confidenceScore' is strictly set to 0, 'riskLevel' is set to 'INVALID_INPUT', and 'complianceWarnings' contains the exact string: 'ERROR: The description provided does not contain a recognizable commercial commodity or cargo type. Please enter a valid item name (e.g., Mangoes, Textiles, Electronics) to proceed.'

      Instructions:
      1. CRITICAL: Provide the most accurate 6-digit universal HS Code for this specific cargo. This will be verified against our ground-truth database.
      2. Determine the country-specific national suffix extension (e.g. HTSUS for US, TARIC for EU, ITC-HS for India) based on the destination country. Provide both the code (8, 10, or 12 digits) and its specific tariff description.
      3. Identify the relevant HS Chapter (e.g., 'Chapter 85 — Electrical Machinery').
      4. Estimate the Standard Import Duty rate for this commodity based on the Destination Country and Origin.
      5. Estimate the VAT / GST rate applicable for this shipment in the Destination Country.
      6. Calculate the Estimated Duty Payable amount based on the Declared Value and Currency.
      7. Parse local seaport transit dues, security fees, and Terminal Handling Charges (THC) between "{originPort}" and "{destinationPort}".
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

  static final RegExp invoiceNumberRegex = RegExp(r'^INV-\d{4}-\d{1,10}$', caseSensitive: false);
}
