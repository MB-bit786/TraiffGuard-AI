import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectionState {
  final bool isOnline;
  final bool hasHandshake;
  
  /// Effectively online means we have a network interface AND can reach the internet.
  bool get effectivelyOnline => isOnline && hasHandshake;

  ConnectionState({
    required this.isOnline, 
    this.hasHandshake = false
  });

  ConnectionState copyWith({bool? isOnline, bool? hasHandshake}) {
    return ConnectionState(
      isOnline: isOnline ?? this.isOnline,
      hasHandshake: hasHandshake ?? this.hasHandshake,
    );
  }
}

class ConnectionNotifier extends StateNotifier<ConnectionState> {
  StreamSubscription? _subscription;
  Timer? _handshakeTimer;

  ConnectionNotifier() : super(ConnectionState(isOnline: true)) {
    _init();
  }

  Future<void> _init() async {
    final results = await Connectivity().checkConnectivity();
    final bool isOnline = _checkOnline(results);
    state = ConnectionState(isOnline: isOnline);
    
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

  @override
  void dispose() {
    _subscription?.cancel();
    _handshakeTimer?.cancel();
    super.dispose();
  }
}

final connectionProvider = StateNotifierProvider<ConnectionNotifier, ConnectionState>((ref) {
  return ConnectionNotifier();
});
