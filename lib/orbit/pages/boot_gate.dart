import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/assets.dart';
import '../../core/theme.dart';
import '../../screens/loading_screen.dart';
import '../core/gate_models.dart';
import '../gate_coordinator.dart';
import 'no_link_page.dart';
import 'orbit_portal.dart';
import 'pulse_invite.dart';

/// Boot splash for the Nova gate. Looks like the game's own loader (same art)
/// while [GateCoordinator.decide] runs the attribution → config pipeline, then
/// routes to the WebView (paid) or the game's LoadingScreen (organic).
class BootGate extends StatefulWidget {
  const BootGate({super.key, this.coordinator});

  final GateCoordinator? coordinator;

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> with TickerProviderStateMixin {
  double _progress = 0;
  double _display = 0;
  GateTarget? _target;
  bool _started = false;
  bool _navigating = false;
  Timer? _smoother;
  Timer? _hardDeadline;
  late final DateTime _startTime;
  late final AnimationController _dots =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat();
  static const Duration _minSplash = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _smoother = Timer.periodic(const Duration(milliseconds: 32), (_) {
      final target = (_progress * 0.92).clamp(0.0, 1.0);
      if (mounted) {
        setState(() {
          final next = _display + (target - _display) * 0.12;
          _display = next.clamp(0.0, 1.0);
        });
      }
    });
    // Pure safety net. Must stay comfortably ABOVE the coordinator's happy-path
    // decision time (attribution wait ~10-15s on a cold first install) so the UI
    // never preempts a real paid decision and drops the user into the game.
    _hardDeadline = Timer(const Duration(seconds: 20), () {
      if (mounted && !_navigating) {
        _target ??= const GameTarget();
        _maybeNavigate();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final coordinator = widget.coordinator;
    if (coordinator == null) {
      _progress = 1;
      _target = const GameTarget();
      _maybeNavigate();
      return;
    }
    try {
      _target = await coordinator.decide(
        onProgress: (value) {
          if (mounted) setState(() => _progress = value.clamp(0.0, 1.0));
        },
      );
    } catch (_) {
      _target = const GameTarget();
    }
    _progress = 1;
    _maybeNavigate();
  }

  Future<void> _maybeNavigate() async {
    if (_navigating || _target == null) return;
    final elapsed = DateTime.now().difference(_startTime);
    if (elapsed < _minSplash) {
      await Future<void>.delayed(_minSplash - elapsed);
    }
    if (!mounted || _navigating) return;
    _navigating = true;
    _smoother?.cancel();
    _hardDeadline?.cancel();
    for (var i = 0; i < 14; i++) {
      if (!mounted) return;
      setState(() {
        final next = _display + (1.0 - _display) * 0.35 + 0.01;
        _display = next.clamp(0.0, 1.0);
      });
      if (_display >= 1.0) break; // stop the moment we hit 100%
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (!mounted) return;
    setState(() => _display = 1.0);
    if (!mounted) return;
    await _open(_target!);
  }

  Future<void> _open(GateTarget target) async {
    final coordinator = widget.coordinator;
    final navigator = Navigator.of(context);

    // Organic / gate disabled → hand off to the game's own loader (which
    // preloads sprites and starts menu music).
    if (target is GameTarget || coordinator == null) {
      SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
      navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoadingScreen()),
      );
      return;
    }

    if (target is OfflineTarget) {
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => NoLinkPage(
            probe: coordinator.probe,
            retryBuilder: (_) => BootGate(coordinator: coordinator),
          ),
        ),
      );
      return;
    }

    if (target is PortalTarget) {
      Widget portalBuilder(BuildContext _) => OrbitPortal(
        url: target.url,
        coldLaunch: target.coldLaunch,
        vault: coordinator.vault,
        probe: coordinator.probe,
        pulse: coordinator.pulse,
        agent: coordinator.agent,
      );

      if (coordinator.vault.shouldShowPushInvite &&
          await coordinator.pulse.canOfferPermission()) {
        if (!mounted) return;
        navigator.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PulseInvite(
              vault: coordinator.vault,
              pulse: coordinator.pulse,
              nextBuilder: portalBuilder,
            ),
          ),
        );
      } else {
        navigator.pushReplacement(
          MaterialPageRoute<void>(builder: portalBuilder),
        );
      }
    }
  }

  @override
  void dispose() {
    _smoother?.cancel();
    _hardDeadline?.cancel();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isPortrait = orientation == Orientation.portrait;
          final asset = isPortrait ? A.loadingVertical : A.loadingHorizontal;
          final size = MediaQuery.of(context).size;
          final barWidth =
              (isPortrait ? size.width : size.width * 0.6).clamp(220.0, 620.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(asset, fit: BoxFit.cover, filterQuality: FilterQuality.high),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC060818)],
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0, 0.82),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _loadingText(),
                    const SizedBox(height: 16),
                    _progressBar(barWidth.toDouble()),
                    const SizedBox(height: 8),
                    Text('${(_display.clamp(0.0, 1.0) * 100).round()}%',
                        style: NovaText.title(14, color: NovaColors.cyan)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _loadingText() {
    return AnimatedBuilder(
      animation: _dots,
      builder: (_, _) {
        final n = (_dots.value * 4).floor() % 4;
        return Text(
          'LOADING${'.' * n}',
          style: NovaText.title(20, color: Colors.white, spacing: 3).copyWith(
            shadows: [const Shadow(color: NovaColors.cyan, blurRadius: 12)],
          ),
        );
      },
    );
  }

  Widget _progressBar(double width) {
    return Container(
      width: width,
      height: 20,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xAA05081C),
        border: Border.all(color: NovaColors.stroke, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: NovaColors.blue.withValues(alpha: 0.4),
            blurRadius: 14,
            spreadRadius: -3,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            Container(color: Colors.white10),
            FractionallySizedBox(
              widthFactor: _display.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: const LinearGradient(
                    colors: [NovaColors.cyan, NovaColors.blue, NovaColors.violet],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: NovaColors.cyan.withValues(alpha: 0.8),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 3,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
