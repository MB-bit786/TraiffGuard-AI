import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// State object for connection to track both status and whether it's user-overridden
class ConnectionState {
  final bool isOnline;
  final bool isManual;

  ConnectionState({required this.isOnline, this.isManual = false});

  ConnectionState copyWith({bool? isOnline, bool? isManual}) {
    return ConnectionState(
      isOnline: isOnline ?? this.isOnline,
      isManual: isManual ?? this.isManual,
    );
  }
}

class ConnectionNotifier extends StateNotifier<ConnectionState> {
  StreamSubscription? _subscription;

  ConnectionNotifier() : super(ConnectionState(isOnline: true)) {
    _init();
  }

  Future<void> _init() async {
    // 1. Initial Check
    final results = await Connectivity().checkConnectivity();
    _updateStatus(results);

    // 2. Listen for changes
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      // Only auto-update if the user hasn't taken manual control
      if (!state.isManual) {
        _updateStatus(results);
      }
    });
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // connectivity_plus 6.x returns a list
    final bool hasConnection = results.isNotEmpty && 
        !results.contains(ConnectivityResult.none);
    
    state = state.copyWith(isOnline: hasConnection);
    debugPrint('[NETWORK] Auto-detected: ${hasConnection ? "ONLINE" : "OFFLINE"}');
  }

  /// Manually toggle the connection status. 
  /// This puts the app into "Manual Mode" until the user toggles back or app restarts.
  void toggle() {
    final newStatus = !state.isOnline;
    state = ConnectionState(
      isOnline: newStatus,
      isManual: true, // Mark as manual so auto-detection stops overriding
    );
    debugPrint('[NETWORK] User Override: ${newStatus ? "ONLINE" : "OFFLINE"}');
  }

  /// Resets back to automatic system detection
  void resetToAuto() {
    state = state.copyWith(isManual: false);
    _init(); // Trigger a re-check
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final connectionProvider = StateNotifierProvider<ConnectionNotifier, ConnectionState>((ref) {
  return ConnectionNotifier();
});
