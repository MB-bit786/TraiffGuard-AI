import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AppConnectionState {
  final bool isOnline;
  final bool hasHandshake;
  final bool isManualOverride;
  final bool manualOnlineStatus;
  
  /// Effectively online means we have a network interface AND can reach the internet,
  /// UNLESS a manual override is active.
  bool get effectivelyOnline => isManualOverride ? manualOnlineStatus : (isOnline && hasHandshake);

  AppConnectionState({
    required this.isOnline, 
    this.hasHandshake = false,
    this.isManualOverride = false,
    this.manualOnlineStatus = true,
  });

  AppConnectionState copyWith({
    bool? isOnline, 
    bool? hasHandshake,
    bool? isManualOverride,
    bool? manualOnlineStatus,
  }) {
    return AppConnectionState(
      isOnline: isOnline ?? this.isOnline,
      hasHandshake: hasHandshake ?? this.hasHandshake,
      isManualOverride: isManualOverride ?? this.isManualOverride,
      manualOnlineStatus: manualOnlineStatus ?? this.manualOnlineStatus,
    );
  }
}

class ConnectionNotifier extends StateNotifier<AppConnectionState> {
  StreamSubscription? _subscription;
  Timer? _handshakeTimer;

  ConnectionNotifier() : super(AppConnectionState(isOnline: true)) {
    _init();
  }

  Future<void> _init() async {
    final results = await Connectivity().checkConnectivity();
    final bool isOnline = _checkOnline(results);
    state = AppConnectionState(isOnline: isOnline);
    
    if (isOnline) _performHandshake();

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final bool nowOnline = _checkOnline(results);
      state = state.copyWith(isOnline: nowOnline);
      if (nowOnline) {
        _performHandshake();
      } else {
        state = state.copyWith(hasHandshake: false);
      }
    });

    // Periodic heartbeat to verify real-world connectivity
    _handshakeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.isOnline) _performHandshake();
    });
  }

  Future<void> _performHandshake() async {
    if (kIsWeb) {
      state = state.copyWith(hasHandshake: true);
      return;
    }

    try {
      final lookup = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      final bool success = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
      if (mounted) state = state.copyWith(hasHandshake: success);
    } catch (_) {
      if (mounted) state = state.copyWith(hasHandshake: false);
    }
  }

  bool _checkOnline(List<ConnectivityResult> results) {
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }

  void toggleManualOverride(bool value) {
    state = state.copyWith(isManualOverride: value);
  }

  void setManualStatus(bool value) {
    state = state.copyWith(manualOnlineStatus: value);
  }

  void updateManualOverride({required bool isManual, required bool status}) {
    state = state.copyWith(isManualOverride: isManual, manualOnlineStatus: status);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _handshakeTimer?.cancel();
    super.dispose();
  }
}

final connectionProvider = StateNotifierProvider<ConnectionNotifier, AppConnectionState>((ref) {
  return ConnectionNotifier();
});
