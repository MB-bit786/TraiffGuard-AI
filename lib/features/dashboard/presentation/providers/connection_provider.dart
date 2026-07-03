import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectionState {
  final bool isOnline;
  ConnectionState({required this.isOnline});
}

class ConnectionNotifier extends StateNotifier<ConnectionState> {
  StreamSubscription? _subscription;

  ConnectionNotifier() : super(ConnectionState(isOnline: true)) {
    _init();
  }

  Future<void> _init() async {
    final results = await Connectivity().checkConnectivity();
    state = ConnectionState(isOnline: _checkOnline(results));

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      state = ConnectionState(isOnline: _checkOnline(results));
    });
  }

  bool _checkOnline(List<ConnectivityResult> results) {
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
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
