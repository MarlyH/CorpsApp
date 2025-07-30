import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  ConnectivityProvider() {
    // initial snapshot
    Connectivity().checkConnectivity().then((status) {
      final offline = status == ConnectivityResult.none;
      if (offline != _isOffline) {
        _isOffline = offline;
        notifyListeners();
      }
    });

    // subsequent updates
    Connectivity().onConnectivityChanged.listen((status) {
      final offline = status == ConnectivityResult.none;
      if (offline != _isOffline) {
        _isOffline = offline;
        notifyListeners();
      }
    });
  }
}
