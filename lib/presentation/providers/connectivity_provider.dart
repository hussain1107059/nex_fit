import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_info.dart';
import '../../injection/dependency_injection.dart';

/// Emits whether the device currently has a usable network connection.
final connectivityProvider = StreamProvider<bool>((ref) {
  final NetworkInfo networkInfo = ref.watch(networkInfoProvider);
  return networkInfo.onConnectivityChanged.map(
    (List<ConnectivityResult> results) => results.any(
      (result) => result != ConnectivityResult.none,
    ),
  );
});
