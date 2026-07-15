// TariffGuard AI — Customs Export Intelligence Platform

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/config/routes/app_router.dart';

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

    return MaterialApp.router(
      title: 'TariffGuard AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: TariffColors.navyDeep,
        fontFamily: 'Roboto',
      ),
      routerConfig: router,
    );
  }
}
