import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class SyncManager {
  SyncManager({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  void start({required Future<void> Function() onConnected}) {
    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      final online = results.any((result) => result != ConnectivityResult.none);
      if (online) {
        await onConnected();
      }
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
