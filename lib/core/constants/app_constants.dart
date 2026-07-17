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
    'Netherlands', 'Singapore', 'Italy', 'South Korea', 'Brazil'
  ];

  static final RegExp invoiceNumberRegex = RegExp(r'^[A-Z0-9-]{3,20}$');
}
