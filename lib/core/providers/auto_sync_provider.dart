import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/core/services/auto_sync_service.dart';
import 'package:hscode_auditor/core/services/gemini_audit_service.dart';
import 'package:hscode_auditor/features/invoice/presentation/providers/invoice_providers.dart' as inv;
import 'package:hscode_auditor/features/dashboard/presentation/providers/connection_provider.dart';

export 'package:hscode_auditor/core/services/auto_sync_service.dart';

/// Global provider for the AutoSyncService.
final autoSyncServiceProvider = Provider<AutoSyncService>((ref) {
  final repository = ref.watch(inv.invoiceRepositoryProvider);
  final gemini = ref.watch(geminiAuditServiceProvider);
  final service = AutoSyncService(repository, gemini, ref);

  ref.listen(connectionProvider, (previous, next) {
    if (next.effectivelyOnline && (previous == null || !previous.effectivelyOnline)) {
      service.syncPendingAudits();
    }
  });

  return service;
});

/// Bootstraps the AutoSyncService and manages its lifecycle.
/// Watch this in the root UI (MainLayoutScreen) to keep background sync alive.
final autoSyncInitializerProvider = Provider<void>((ref) {
  final syncService = ref.watch(autoSyncServiceProvider);
  
  // 1. Start the listeners
  syncService.startListening();
  
  // 2. Graceful teardown
  ref.onDispose(() {
    debugPrint('[SYNC] Disposing background sync service...');
    syncService.dispose();
  });
});
