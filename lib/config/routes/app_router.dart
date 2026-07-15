import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/core/services/auth_service.dart';
import 'app_routes.dart';

// Import all screens
import 'package:hscode_auditor/features/auth/presentation/pages/auth_screen.dart';
import 'package:hscode_auditor/features/dashboard/presentation/pages/main_layout_screen.dart';
import 'package:hscode_auditor/features/invoice/presentation/pages/invoice_form_screen.dart';
import 'package:hscode_auditor/features/audit/presentation/pages/audit_result_screen.dart';
import 'package:hscode_auditor/features/audit/presentation/pages/audit_history_screen.dart';
import 'package:hscode_auditor/features/dashboard/presentation/pages/trash_screen.dart';
import 'package:hscode_auditor/features/dashboard/presentation/pages/edit_audit_screen.dart';
import 'package:hscode_auditor/features/profile/presentation/pages/terms_conditions_screen.dart';
import 'package:hscode_auditor/features/auth/presentation/pages/custom_splash_screen.dart';
import 'package:hscode_auditor/features/search/presentation/pages/tariff_directory_screen.dart';

// Providers and Models
import 'package:hscode_auditor/features/audit/data/models/hs_audit_result_model.dart';
import 'package:hscode_auditor/features/audit/presentation/providers/audit_detail_provider.dart';

/// A notifier that consolidates app state changes (like Auth) into a single Listenable
/// for GoRouter to react to without rebuilding the entire Router instance.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  bool _isSplashDone = false;

  RouterNotifier(this._ref) {
    // Listen to auth changes and notify GoRouter to re-evaluate redirect logic
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }

  bool get isSplashDone => _isSplashDone;
  
  void completeSplash() {
    _isSplashDone = true;
    notifyListeners();
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    debugLogDiagnostics: true,
    redirect: (BuildContext context, GoRouterState state) {
      final bool onSplash = state.matchedLocation == AppRoutes.splash;
      
      // 1. Splash Logic: If we are on splash, stay there until completeSplash is called.
      if (!notifier.isSplashDone) {
        return onSplash ? null : AppRoutes.splash;
      }
      
      // If we just finished splash and are still on /splash, go to root
      if (onSplash && notifier.isSplashDone) {
        return AppRoutes.root;
      }

      final authState = ref.read(authStateProvider);
      if (authState.isLoading) return null;

      final bool loggedIn = authState.value != null;
      final bool onAuth = state.matchedLocation == AppRoutes.auth;

      // 2. Unauthenticated User Guard
      if (!loggedIn) {
        return onAuth ? null : AppRoutes.auth;
      }

      // 3. Authenticated User Guard (Redirect away from Auth)
      if (onAuth) {
        return AppRoutes.root;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => CustomSplashScreen(
          onFinish: () => notifier.completeSplash(),
        ),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.root,
        builder: (context, state) {
          final user = ref.read(authStateProvider).value;
          if (user == null) return const AuthScreen();
          
          return Consumer(
            builder: (context, ref, child) {
              final termsAcceptedAsync = ref.watch(userAcceptedTermsProvider(user.uid));
              return termsAcceptedAsync.when(
                data: (hasAccepted) => hasAccepted 
                    ? const MainLayoutScreen() 
                    : const TermsConditionsScreen(isGatekeeperMode: true),
                loading: () => _buildRouterLoadingScaffold(),
                error: (e, _) => _buildRouterErrorScaffold('Compliance Error: $e'),
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.invoiceForm,
        builder: (context, state) => const InvoiceFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.auditResult,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AuditResultScreen(activeInvoiceId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.auditHistory,
        builder: (context, state) => const AuditHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.editAudit,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return Consumer(
            builder: (context, ref, child) {
              final auditAsync = ref.watch(auditDetailProvider(id));
              return auditAsync.when(
                data: (audit) => audit != null 
                    ? EditAuditScreen(audit: audit as HsAuditResultModel)
                    : _buildRouterErrorScaffold('Audit record $id not found.'),
                loading: () => _buildRouterLoadingScaffold(),
                error: (e, _) => _buildRouterErrorScaffold('Fetch failed: $e'),
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.trash,
        builder: (context, state) => const TrashScreen(),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (context, state) => const TermsConditionsScreen(isGatekeeperMode: false),
      ),
      GoRoute(
        path: AppRoutes.tariffDirectory,
        builder: (context, state) => const TariffDirectoryScreen(),
      ),
    ],
  );
});

Widget _buildRouterLoadingScaffold() {
  return const Scaffold(
    backgroundColor: Color(0xFF0A1628), // navyDeep
    body: Center(child: CircularProgressIndicator(color: Color(0xFFFFB300))), // amberPending
  );
}

Widget _buildRouterErrorScaffold(String message) {
  return Scaffold(
    backgroundColor: const Color(0xFF0A1628),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935), size: 48), // crimsonRisk
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    ),
  );
}
