// TariffGuard AI — Customs Export Intelligence Platform

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/config/routes/app_router.dart';
import 'package:hscode_auditor/core/providers/theme_provider.dart';

void main() async {
  // 1. Mandatory initialization
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Initialize Firebase (awaited to prevent [core/no-app] crash)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[STARTUP] Firebase Error: $e');
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, 
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: TariffGuardApp(),
    ),
  );
}

class TariffGuardApp extends ConsumerWidget {
  const TariffGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'TariffGuard AI',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF1565C0),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.white,
          contentTextStyle: const TextStyle(color: Colors.black87),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titleTextStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
          contentTextStyle: const TextStyle(color: Colors.black54, fontSize: 14),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: TariffColors.navyDeep,
        colorSchemeSeed: const Color(0xFF1565C0),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: TariffColors.navyMid,
          foregroundColor: TariffColors.textPrimary,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: TariffColors.navySurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: TariffColors.cardBorder, width: 1),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: TariffColors.navyElevated,
          contentTextStyle: const TextStyle(color: TariffColors.textPrimary),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 8,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: TariffColors.navyMid,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: TariffColors.cardBorder)),
          titleTextStyle: const TextStyle(color: TariffColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
          contentTextStyle: const TextStyle(color: TariffColors.textSecondary, fontSize: 14),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: TariffColors.navyMid,
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: TariffColors.cardBorder)),
          textStyle: const TextStyle(color: TariffColors.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      routerConfig: router,
    );
  }
}
