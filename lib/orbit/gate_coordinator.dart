import 'dart:async';
import 'dart:io';

import 'config/nova_gate_config.dart';
import 'core/gate_models.dart';
import 'infra/cold_tap_reader.dart';
import 'infra/drift_attribution.dart';
import 'infra/gate_exchange.dart';
import 'infra/link_probe.dart';
import 'infra/orbit_vault.dart';
import 'infra/pulse_hub.dart';
import 'infra/signal_agent.dart';

/// The whole routing brain of the Nova gate. [decide] runs the cold-start →
/// attribution → config pipeline once and returns a [GateTarget].
class GateCoordinator {
  GateCoordinator({
    required this.vault,
    required this.probe,
    required this.attribution,
    required this.exchange,
    required this.pulse,
    required this.agent,
    required this.runtimeEnabled,
  });

  final OrbitVault vault;
  final LinkProbe probe;
  final DriftAttribution attribution;
  final GateExchange exchange;
  final PulseHub pulse;
  final SignalAgent agent;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && NovaGateConfig.gateCredentialsReady;

  Future<GateTarget>? _decideFuture;

  /// True once the first decision pipeline has finished. Guards
  /// [_refreshForToken] so an FCM token arriving *mid-decision* does not fire a
  /// premature config POST with empty attribution (that request always 404s and
  /// races the real, attribution-complete request).
  bool _settled = false;

  /// De-duplicates only *concurrent* calls (the boot screen can build twice at
  /// startup). The cache clears once the pipeline finishes, so Retry from the
  /// offline screen re-runs the whole pipeline instead of replaying a cached
  /// OfflineTarget forever.
  Future<GateTarget> decide({
    required void Function(double value) onProgress,
  }) {
    final existing = _decideFuture;
    if (existing != null) return existing;
    _settled = false;
    return _decideFuture = _decide(onProgress: onProgress).whenComplete(() {
      _decideFuture = null;
      _settled = true;
    });
  }

  Future<GateTarget> _decide({
    required void Function(double value) onProgress,
  }) async {
    if (!enabled) {
      onProgress(1);
      return const GameTarget();
    }

    pulse.onTokenChanged = _refreshForToken;
    final coldRoute = await ColdTapReader.consume();
    if (coldRoute != null) {
      await vault.saveRoute(GateRoute.portal);
      await vault.consumePushUrl();
      unawaited(_backgroundDispatch());
      onProgress(1);
      return PortalTarget(coldRoute, coldLaunch: true);
    }

    onProgress(0.12);
    return switch (vault.route) {
      GateRoute.undecided => _firstDecision(onProgress),
      GateRoute.portal => _returningPortal(onProgress),
      GateRoute.game => _returningGame(onProgress),
    };
  }

  Future<GateTarget> _firstDecision(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      return const OfflineTarget(returnToGame: false);
    }
    progress(0.28);
    try {
      await pulse.boot();
    } catch (_) {}
    if (!await probe.canReachNetwork()) {
      return const OfflineTarget(returnToGame: false);
    }
    progress(0.48);
    // Fresh installs need a wider window: the ATT prompt + AppsFlyer SDK spin-up
    // + conversion callback can take ~10s on a cold first launch. A short
    // timeout here makes the gate give up and fall back to the game before the
    // paid attribution (and its config URL) ever arrives.
    await attribution.awaitSignals(installTimeout: const Duration(seconds: 15));
    progress(0.72);
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) {
      await vault.saveRoute(GateRoute.portal);
      return PortalTarget(reply.url!);
    }
    await vault.saveRoute(GateRoute.game);
    return const GameTarget();
  }

  Future<GateTarget> _returningPortal(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      return const OfflineTarget(returnToGame: false);
    }
    final pending = await vault.consumePushUrl();
    if (pending != null && pending.isNotEmpty) {
      progress(1);
      return PortalTarget(pending);
    }
    final cached = await vault.savedUrl();
    if (cached != null && !vault.cachedUrlExpired) {
      progress(1);
      return PortalTarget(cached);
    }

    await Future.wait<void>(<Future<void>>[
      pulse.boot(),
      attribution.start(),
    ]);
    if (!await probe.canReachNetwork()) {
      return const OfflineTarget(returnToGame: false);
    }
    progress(0.62);
    await attribution.awaitSignals(installTimeout: const Duration(seconds: 5));
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return PortalTarget(reply.url!);
    if (cached != null) return PortalTarget(cached);
    return const OfflineTarget(returnToGame: false);
  }

  Future<GateTarget> _returningGame(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      progress(1);
      return const GameTarget();
    }
    await Future.wait<void>(<Future<void>>[
      pulse.boot(),
      attribution.start(),
    ]);
    if (!await probe.canReachNetwork()) {
      progress(1);
      return const GameTarget();
    }
    progress(0.55);
    await attribution.awaitSignals();
    final reply = await _requestConfig();
    progress(1);
    if (!reply.hasDestination) return const GameTarget();
    await vault.saveRoute(GateRoute.portal);
    return PortalTarget(reply.url!);
  }

  Future<GateReply> _requestConfig({String? token}) async {
    final body = await attribution.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? pulse.token,
    );
    return exchange.request(body);
  }

  Future<void> _backgroundDispatch() async {
    try {
      await Future.wait<void>(<Future<void>>[
        pulse.boot(),
        attribution.awaitSignals(),
      ]);
      await _requestConfig();
    } catch (_) {}
  }

  Future<void> _refreshForToken(String token) async {
    // Only refresh the backend with a late FCM token AFTER the first decision
    // has settled. During the initial pipeline `compose()` already picks up
    // `pulse.token`, so firing here mid-decision only produces a redundant POST
    // with empty attribution.
    if (!_settled) return;
    try {
      await _requestConfig(token: token);
    } catch (_) {}
  }
}
