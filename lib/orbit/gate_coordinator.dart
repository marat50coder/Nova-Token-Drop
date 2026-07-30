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

/// Routing brain of the Nova gate. [decide] walks the cold-start → attribution
/// → config pipeline exactly once (concurrent calls receive the same future)
/// and returns a [GateTarget] describing where the boot splash should go next.
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

  static const Duration _firstInstallAttributionWindow =
      Duration(seconds: 15);
  static const Duration _returningAttributionWindow =
      Duration(seconds: 5);

  final OrbitVault vault;
  final LinkProbe probe;
  final DriftAttribution attribution;
  final GateExchange exchange;
  final PulseHub pulse;
  final SignalAgent agent;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && NovaGateConfig.gateCredentialsReady;

  Future<GateTarget>? _inFlight;

  /// True once the first pipeline has settled. Guards [_refreshAfterToken] so
  /// a late FCM token arriving mid-decision does NOT fire a premature config
  /// POST with empty attribution (that always 404s and races the real one).
  bool _settled = false;

  Future<GateTarget> decide({
    required void Function(double value) onProgress,
  }) {
    final existing = _inFlight;
    if (existing != null) return existing;
    _settled = false;
    final future = _runPipeline(onProgress).whenComplete(() {
      _inFlight = null;
      _settled = true;
    });
    return _inFlight = future;
  }

  Future<GateTarget> _runPipeline(void Function(double) progress) async {
    if (!enabled) {
      progress(1);
      return const GameTarget();
    }

    pulse.onTokenChanged = _refreshAfterToken;

    final coldRoute = await ColdTapReader.consume();
    if (coldRoute != null) {
      return _handleColdStart(coldRoute, progress);
    }

    progress(0.12);
    switch (vault.route) {
      case GateRoute.undecided:
        return _decideFirstRun(progress);
      case GateRoute.portal:
        return _decideReturningPortal(progress);
      case GateRoute.game:
        return _decideReturningGame(progress);
    }
  }

  Future<GateTarget> _handleColdStart(
    String coldRoute,
    void Function(double) progress,
  ) async {
    await vault.saveRoute(GateRoute.portal);
    await vault.consumePushUrl();
    unawaited(_dispatchInBackground());
    progress(1);
    return PortalTarget(coldRoute, coldLaunch: true);
  }

  Future<GateTarget> _decideFirstRun(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      return const OfflineTarget(returnToGame: false);
    }
    progress(0.28);

    // Fire push bootstrap early — errors here are non-fatal to routing.
    try {
      await pulse.boot();
    } catch (_) {}

    if (!await probe.canReachNetwork()) {
      return const OfflineTarget(returnToGame: false);
    }
    progress(0.48);

    // Fresh installs need a wider window: ATT prompt + AppsFlyer SDK spin-up
    // + conversion callback can take ~10s. A short timeout here would make
    // the gate fall back to the game before the paid attribution arrives.
    await attribution.awaitSignals(
      installTimeout: _firstInstallAttributionWindow,
    );
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

  Future<GateTarget> _decideReturningPortal(
    void Function(double) progress,
  ) async {
    if (!await probe.hasInterface()) {
      return const OfflineTarget(returnToGame: false);
    }

    // Any push URL waiting from a previous session wins immediately.
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

    // No fresh URL cached → refresh attribution + config.
    await Future.wait<void>(<Future<void>>[
      pulse.boot(),
      attribution.start(),
    ]);
    if (!await probe.canReachNetwork()) {
      return const OfflineTarget(returnToGame: false);
    }
    progress(0.62);
    await attribution.awaitSignals(
      installTimeout: _returningAttributionWindow,
    );

    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return PortalTarget(reply.url!);
    if (cached != null) return PortalTarget(cached);
    return const OfflineTarget(returnToGame: false);
  }

  Future<GateTarget> _decideReturningGame(
    void Function(double) progress,
  ) async {
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
    final payload = await attribution.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? pulse.token,
    );
    return exchange.request(payload);
  }

  Future<void> _dispatchInBackground() async {
    try {
      await Future.wait<void>(<Future<void>>[
        pulse.boot(),
        attribution.awaitSignals(),
      ]);
      await _requestConfig();
    } catch (_) {}
  }

  Future<void> _refreshAfterToken(String token) async {
    // Only refresh the backend with a late FCM token AFTER the first decision
    // has settled. During the initial pipeline `compose()` already picks up
    // `pulse.token`, so firing here mid-decision only produces a redundant
    // POST with empty attribution.
    if (!_settled) return;
    try {
      await _requestConfig(token: token);
    } catch (_) {}
  }
}
