import 'dart:async';
import 'package:flutter/material.dart';
import '../core/assets.dart';
import '../core/audio.dart';
import '../core/sprite_cache.dart';
import '../core/theme.dart';
import '../main.dart';
import 'menu_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with TickerProviderStateMixin {
  double _progress = 0; // raw preload fraction 0..1
  double _display = 0; // smoothed bar value
  bool _navigated = false;
  Timer? _smoother;
  late final AnimationController _dots =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void initState() {
    super.initState();
    _startLoading();
    // smoothly ease the displayed bar toward the target
    _smoother = Timer.periodic(const Duration(milliseconds: 32), (_) {
      final target = _progress * 0.92; // hold below 100% until the final moment
      if (mounted) setState(() => _display += (target - _display) * 0.12);
    });
  }

  Future<void> _startLoading() async {
    final started = DateTime.now();
    await SpriteCache.instance.preloadAll((p) {
      if (mounted) _progress = p;
    });
    // guarantee a minimum on-screen time so the animation reads well
    final elapsed = DateTime.now().difference(started);
    const minShow = Duration(milliseconds: 2200);
    if (elapsed < minShow) {
      await Future.delayed(minShow - elapsed);
    }
    // Fill the bar to 100% ONLY now, right before launching the game.
    _smoother?.cancel();
    for (var i = 0; i < 18; i++) {
      if (!mounted) return;
      setState(() => _display += (1.0 - _display) * 0.35 + 0.01);
      await Future.delayed(const Duration(milliseconds: 22));
    }
    if (!mounted) return;
    setState(() => _display = 1.0);
    await Future.delayed(const Duration(milliseconds: 260));
    _launch();
  }

  Future<void> _launch() async {
    if (_navigated) return;
    _navigated = true;
    await lockPortrait();
    Audio.instance.playMusic(Music.menu);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, a, _) => FadeTransition(opacity: a, child: const MenuScreen()),
      ),
    );
  }

  @override
  void dispose() {
    _smoother?.cancel();
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
          final barWidth = (isPortrait ? size.width : size.width * 0.6).clamp(220.0, 620.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(asset, fit: BoxFit.cover),
              // subtle darken at the bottom for legibility
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
                    Text('${(_display * 100).round()}%',
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
        boxShadow: [BoxShadow(color: NovaColors.blue.withValues(alpha: 0.4), blurRadius: 14, spreadRadius: -3)],
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
                  gradient: const LinearGradient(colors: [NovaColors.cyan, NovaColors.blue, NovaColors.violet]),
                  boxShadow: [BoxShadow(color: NovaColors.cyan.withValues(alpha: 0.8), blurRadius: 10)],
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(width: 3, color: Colors.white.withValues(alpha: 0.9)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
