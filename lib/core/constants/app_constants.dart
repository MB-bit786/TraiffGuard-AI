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

  static final RegExp invoiceNumberRegex = RegExp(r'^INV-\d{4}-\d{1,10}$', caseSensitive: false);
}
