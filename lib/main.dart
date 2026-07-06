// TariffGuard AI — Customs Export Intelligence Platform

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/features/dashboard/presentation/pages/main_layout_screen.dart';
import 'package:hscode_auditor/features/invoice/presentation/pages/invoice_form_screen.dart';
import 'package:hscode_auditor/features/audit/presentation/pages/audit_result_screen.dart';
import 'package:hscode_auditor/features/auth/presentation/pages/auth_screen.dart';
import 'package:hscode_auditor/features/audit/presentation/pages/audit_history_screen.dart';
import 'package:hscode_auditor/features/dashboard/presentation/pages/trash_screen.dart';
import 'package:hscode_auditor/features/dashboard/presentation/pages/edit_audit_screen.dart';
import 'package:hscode_auditor/features/profile/presentation/pages/terms_conditions_screen.dart';
import 'package:hscode_auditor/core/util/auto_sync_service.dart';
import 'package:hscode_auditor/core/util/auth_service.dart';
import 'package:hscode_auditor/features/audit/data/models/hs_audit_result_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[STARTUP] Firebase Error: $e');
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
  );

  final container = ProviderContainer();
  container.read(autoSyncServiceProvider);

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
      ),
      home: const AuthGatekeeper(), 
      routes: {
        '/invoice-form': (_) => const InvoiceFormScreen(),
        '/audit-result': (_) => const AuditResultScreen(),
        '/audit-history': (_) => const AuditHistoryScreen(),
        '/trash': (_) => const TrashScreen(),
        '/terms-view': (_) => const TermsConditionsScreen(isGatekeeperMode: false),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/edit-audit') {
          final audit = settings.arguments as HsAuditResultModel;
          return MaterialPageRoute(builder: (_) => EditAuditScreen(audit: audit));
        }
        return null;
      },
    );
  }
}

class AuthGatekeeper extends ConsumerWidget {
  const AuthGatekeeper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isRegistering = ref.watch(registrationInProgressProvider);

    return authState.when(
      data: (user) {
        if (user != null && !isRegistering) {
          return TermsGatekeeper(uid: user.uid);
        }
        return const AuthScreen();
      },
      loading: () => const _LoadingScaffold(),
      error: (e, st) => _ErrorScaffold(message: 'Auth Error: $e'),
    );
  }
}

class TermsGatekeeper extends ConsumerWidget {
  final String uid;
  const TermsGatekeeper({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termsAcceptedAsync = ref.watch(userAcceptedTermsProvider(uid));

    return termsAcceptedAsync.when(
      data: (hasAccepted) {
        if (hasAccepted) {
          return const MainLayoutScreen();
        } else {
          return const TermsConditionsScreen(isGatekeeperMode: true);
        }
      },
      loading: () => const _LoadingScaffold(),
      error: (e, st) => _ErrorScaffold(message: 'Compliance Error: $e'),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: TariffColors.navyDeep,
      body: Center(child: CircularProgressIndicator(color: TariffColors.amberPending)),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TariffColors.navyDeep,
      body: Center(child: Text(message, style: const TextStyle(color: Colors.white))),
    );
  }
}
