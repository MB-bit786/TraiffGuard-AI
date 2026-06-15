// TariffGuard AI — Customs Export Intelligence Platform

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'package:hscode_auditor/core/theme/tariff_colors.dart';
import 'package:hscode_auditor/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:hscode_auditor/features/invoice/presentation/screens/invoice_form_screen.dart';
import 'package:hscode_auditor/features/audit/presentation/screens/audit_result_screen.dart';

import 'package:hscode_auditor/features/audit/presentation/screens/audit_history_screen.dart';
import 'package:hscode_auditor/features/dashboard/presentation/screens/trash_screen.dart';
import 'package:hscode_auditor/core/services/auto_sync_service.dart';

void main() async {
  // 1. Ensure Flutter bindings are ready for FFI and System calls
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[STARTUP] WidgetsFlutterBinding active');

  // 2. Cross-platform Database Factory Initialization
  // This must happen before any database calls (e.g. in SqlDatabaseService)
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
    debugPrint('[STARTUP] Database: Initialized for Web');
  } else {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      debugPrint('[STARTUP] Database: Initialized for Desktop (FFI)');
    }
  }

  // 3. System-level UI configuration
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: TariffColors.navyDeep,
    ),
  );

  debugPrint('[STARTUP] Launching TariffGuardApp instance...');
  
  final container = ProviderContainer();
  // Trigger AutoSyncService initialization
  container.read(autoSyncServiceProvider);

  // 4. Ex dart run sqflite_common_ffi_web:setupecution hand-off to Riverpod and the UI loop
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TariffGuardApp(),
    ),
  );
}

class TariffGuardApp extends StatelessWidget {
  const TariffGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TariffGuard AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: TariffColors.navyDeep,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: TariffColors.navyMid,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      initialRoute: '/dashboard',
      routes: {
        '/dashboard': (_) => const DashboardScreen(),
        '/invoice-form': (_) => const InvoiceFormScreen(),
        '/audit-result': (_) => const AuditResultScreen(),
        '/audit-history': (_) => const AuditHistoryScreen(),
        '/trash': (_) => const TrashScreen(),
      },
    );
  }
}
