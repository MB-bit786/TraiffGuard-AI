import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../audit/domain/entities/hs_audit_result_entity.dart';
import '../../../dashboard/presentation/providers/connection_provider.dart';
import 'package:hscode_auditor/core/util/gemini_audit_service.dart';
import 'package:hscode_auditor/core/util/auth_service.dart';
import '../../domain/usecases/process_customs_audit_use_case.dart';
import '../../../dashboard/presentation/providers/invoice_list_provider.dart';

class InvoiceFormState {
  final bool isAnalyzing;
  final String? error;
  final HsAuditResultEntity? result;

  const InvoiceFormState({
    this.isAnalyzing = false,
    this.error,
    this.result,
  });

  InvoiceFormState copyWith({
    bool? isAnalyzing,
    String? error,
    HsAuditResultEntity? result,
  }) {
    return InvoiceFormState(
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      error: error ?? this.error,
      result: result ?? this.result,
    );
  }
}

class InvoiceFormNotifier extends StateNotifier<InvoiceFormState> {
  final ProcessCustomsAuditUseCase _processAuditUseCase;
  final Ref _ref;

  InvoiceFormNotifier(this._processAuditUseCase, this._ref) : super(const InvoiceFormState());

  Future<bool> processCustomsAudit({
    required String invoiceNumber,
    required String consignee,
    required String cargoDescription,
    required String originCountry,
    required String destCountry,
    required double declaredValue,
    required String currency,
    required String totalWeightKg,
    required String plannedMonth,
    required String shippingMethod,
    String? hsCode,
  }) async {
    final bool isUserOnline = _ref.read(connectionProvider).isOnline;
    bool hasHandshake = false;

    if (isUserOnline && !kIsWeb) {
      try {
        final lookup = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
        hasHandshake = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
      } catch (_) {
        hasHandshake = false;
      }
    } else if (kIsWeb) {
      hasHandshake = isUserOnline;
    }

    final bool effectivelyOnline = isUserOnline && hasHandshake;
    final String userId = _ref.read(authServiceProvider).currentUser?.uid ?? 'anonymous';

    state = state.copyWith(isAnalyzing: true, error: null, result: null);

    final params = AuditParams(
      invoiceNumber: invoiceNumber,
      consignee: consignee,
      cargoDescription: cargoDescription,
      originCountry: originCountry,
      destCountry: destCountry,
      declaredValue: declaredValue,
      currency: currency,
      totalWeightKg: totalWeightKg,
      plannedMonth: plannedMonth,
      shippingMethod: shippingMethod,
      userId: userId,
      effectivelyOnline: effectivelyOnline,
      hsCode: hsCode,
    );

    final response = await _processAuditUseCase.execute(params);

    state = state.copyWith(
      isAnalyzing: false,
      result: response.result,
      error: response.error,
    );

    return true;
  }
}

final processCustomsAuditUseCaseProvider = Provider<ProcessCustomsAuditUseCase>((ref) {
  final repository = ref.watch(invoiceRepositoryProvider);
  final aiService = ref.watch(geminiAuditServiceProvider);
  return ProcessCustomsAuditUseCase(repository, aiService);
});

final invoiceFormNotifierProvider = StateNotifierProvider<InvoiceFormNotifier, InvoiceFormState>((ref) {
  final useCase = ref.watch(processCustomsAuditUseCaseProvider);
  return InvoiceFormNotifier(useCase, ref);
});
