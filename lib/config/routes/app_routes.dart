class AppRoutes {
  AppRoutes._();

  static const String root = '/';
  static const String splash = '/splash';
  static const String auth = '/auth';
  static const String dashboard = '/dashboard';
  static const String invoiceForm = '/invoice-form';
  static const String auditResult = '/audit-result/:id';
  static const String auditHistory = '/audit-history';
  static const String editAudit = '/edit-audit/:id';
  static const String trash = '/trash';
  static const String terms = '/terms';
  static const String tariffDirectory = '/tariff-directory';

  // Helper methods to generate paths with parameters
  static String auditResultPath(String id) => '/audit-result/$id';
  static String editAuditPath(String id) => '/edit-audit/$id';
}
