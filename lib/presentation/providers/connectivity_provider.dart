import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the current connectivity status (connectivity_plus v5+ returns List)
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) async* {
  // Emit the initial state immediately so the UI doesn't wait for the next change
  final initial = await Connectivity().checkConnectivity();
  yield [initial];
  yield* Connectivity().onConnectivityChanged.map((result) => [result]);
});

/// Simple bool: true = has at least one active connection
final isConnectedProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) => results.any((r) => r != ConnectivityResult.none),
    loading: () => true, // assume connected while loading
    error: (_, __) => false,
  );
});
