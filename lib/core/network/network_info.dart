import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Observes device connectivity state.
class NetworkInfo {
  NetworkInfo({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  Future<bool> get isConnected async {
    final List<ConnectivityResult> results =
        await _connectivity.checkConnectivity();
    return results.any(
      (result) => result != ConnectivityResult.none,
    );
  }

  Future<ConnectivityResult> get currentConnectivity async {
    final List<ConnectivityResult> results =
        await _connectivity.checkConnectivity();
    if (results.isEmpty) return ConnectivityResult.none;
    return results.first;
  }
}
