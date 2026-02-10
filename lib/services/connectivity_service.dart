import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Service to monitor internet connectivity.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final http.Client _client;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final _controller = StreamController<bool>.broadcast();

  /// Stream of connectivity status (true = online, false = offline).
  Stream<bool> get onConnectivityChanged => _controller.stream;

  ConnectivityService({http.Client? client})
      : _client = client ?? http.Client();

  /// Initialize and start listening to connectivity changes.
  void initialize() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      final hasConnection = results.any(
        (r) => r != ConnectivityResult.none,
      );
      if (hasConnection) {
        // Verify real internet access with a lightweight request
        final isOnline = await _checkRealConnectivity();
        _controller.add(isOnline);
      } else {
        _controller.add(false);
      }
    });
  }

  /// Check current connectivity status.
  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    final hasConnection = results.any(
      (r) => r != ConnectivityResult.none,
    );
    if (!hasConnection) return false;
    return _checkRealConnectivity();
  }

  /// Pings a lightweight endpoint to verify real internet access.
  Future<bool> _checkRealConnectivity() async {
    try {
      final response = await _client
          .head(Uri.parse('https://api.deezer.com/'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
    _client.close();
  }
}
