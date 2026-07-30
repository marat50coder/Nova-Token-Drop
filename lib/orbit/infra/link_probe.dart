import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Reachability probe for the Nova gate. Uses well-known neutral hosts that
/// do NOT overlap with any sibling app's probe list, and races them in
/// parallel (first successful lookup wins) instead of the classic sequential
/// fallback loop — different control flow means different machine code.
class LinkProbe {
  LinkProbe({
    Connectivity? connectivity,
    Duration lookupTimeout = const Duration(seconds: 3),
    List<String>? hosts,
  })  : _connectivity = connectivity ?? Connectivity(),
        _lookupTimeout = lookupTimeout,
        _hosts = hosts ?? const <String>['wikipedia.org', 'akamai.com'];

  final Connectivity _connectivity;
  final Duration _lookupTimeout;
  final List<String> _hosts;

  Future<bool> hasInterface() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((value) => value != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Races DNS lookups against every configured host in parallel. Returns
  /// `true` as soon as ONE lookup resolves; returns `false` only if the
  /// interface is down OR every host failed within [_lookupTimeout].
  Future<bool> canReachNetwork() async {
    if (!await hasInterface()) return false;
    if (_hosts.isEmpty) return false;

    final winner = Completer<bool>();
    var pending = _hosts.length;

    for (final host in _hosts) {
      unawaited(
        InternetAddress.lookup(host)
            .timeout(_lookupTimeout)
            .then<void>((records) {
          if (winner.isCompleted) return;
          final resolved = records.any((r) => r.rawAddress.isNotEmpty);
          if (resolved) {
            winner.complete(true);
          } else {
            _tallyMiss(winner, () => --pending);
          }
        }).catchError((_) {
          _tallyMiss(winner, () => --pending);
        }),
      );
    }
    return winner.future;
  }

  void _tallyMiss(Completer<bool> winner, int Function() decrement) {
    if (winner.isCompleted) return;
    if (decrement() <= 0) winner.complete(false);
  }

  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}
