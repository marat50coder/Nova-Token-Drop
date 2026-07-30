import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/audio.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'orbit/config/nova_gate_config.dart';
import 'orbit/gate_coordinator.dart';
import 'orbit/infra/drift_attribution.dart';
import 'orbit/infra/gate_exchange.dart';
import 'orbit/infra/link_probe.dart';
import 'orbit/infra/orbit_vault.dart';
import 'orbit/infra/pulse_hub.dart';
import 'orbit/infra/signal_agent.dart';
import 'orbit/pages/boot_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Boot supports both orientations; the game locks to portrait later.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final vault = OrbitVault();
  final agent = SignalAgent();
  await Future.wait<void>(<Future<void>>[
    GameStorage.instance.init(),
    vault.initialize(),
    agent.prepare(),
  ]);
  // Kick off audio setup but don't block startup on it.
  unawaited(Audio.instance.init());

  var productionServicesReady = false;
  if (NovaGateConfig.gateCredentialsReady) {
    try {
      await Firebase.initializeApp();
      productionServicesReady = true;
    } catch (error) {
      assert(() {
        debugPrint('[NTD.BOOT] Firebase.initializeApp failed: $error');
        return true;
      }());
    }
    if (productionServicesReady) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } catch (_) {
        // App Check must never block FCM / gray routing.
      }
    }
  }

  final probe = LinkProbe();
  // Attribution + config POST must run even if Firebase init failed; only
  // push/FCM needs productionServicesReady.
  final pulse = PulseHub(vault, enabled: productionServicesReady);
  final attribution = DriftAttribution(agent);
  final coordinator = GateCoordinator(
    vault: vault,
    probe: probe,
    attribution: attribution,
    exchange: GateExchange(agent, vault),
    pulse: pulse,
    agent: agent,
    runtimeEnabled: NovaGateConfig.gateCredentialsReady,
  );

  runApp(NovaApp(coordinator: coordinator));
}

class NovaApp extends StatefulWidget {
  const NovaApp({super.key, this.coordinator});

  final GateCoordinator? coordinator;

  @override
  State<NovaApp> createState() => _NovaAppState();
}

class _NovaAppState extends State<NovaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Covers leaving the game entirely: Home button, task switch, screen
    // lock, or the app being closed — music (and any live SFX) must stop
    // instead of keeping playing in the background.
    if (state == AppLifecycleState.resumed) {
      Audio.instance.resumeFromBackground();
    } else {
      Audio.instance.pauseForBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nova Token Drop',
      debugShowCheckedModeBanner: false,
      theme: NovaTheme.build(),
      home: BootGate(coordinator: widget.coordinator),
    );
  }
}

/// Locks the app to portrait for gameplay/menus.
Future<void> lockPortrait() =>
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
