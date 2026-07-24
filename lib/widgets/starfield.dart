import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Animated deep-space background with drifting stars and soft nebula glow.
class Starfield extends StatefulWidget {
  final Widget? child;
  final List<Color> nebula;
  const Starfield({super.key, this.child, this.nebula = const [Color(0xFF1A1147), Color(0xFF071033)]});

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final List<_Star> _stars = [];

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(7);
    for (var i = 0; i < 110; i++) {
      _stars.add(_Star(
        pos: Offset(rnd.nextDouble(), rnd.nextDouble()),
        size: rnd.nextDouble() * 1.8 + 0.4,
        speed: rnd.nextDouble() * 0.02 + 0.004,
        phase: rnd.nextDouble() * math.pi * 2,
        tint: rnd.nextDouble(),
      ));
    }
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.5),
          radius: 1.3,
          colors: [widget.nebula.first, widget.nebula.last, NovaColors.deepSpace],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _StarPainter(_stars, _c.value),
          size: Size.infinite,
          child: widget.child,
        ),
      ),
    );
  }
}

class _Star {
  Offset pos;
  final double size;
  final double speed;
  final double phase;
  final double tint;
  _Star({required this.pos, required this.size, required this.speed, required this.phase, required this.tint});
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;
  _StarPainter(this.stars, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final s in stars) {
      final y = (s.pos.dy + t * s.speed * 12) % 1.0;
      final twinkle = 0.55 + 0.45 * math.sin(t * math.pi * 2 * 3 + s.phase);
      final color = Color.lerp(NovaColors.cyan, Colors.white, s.tint)!;
      p.color = color.withValues(alpha: twinkle * 0.9);
      canvas.drawCircle(Offset(s.pos.dx * size.width, y * size.height), s.size, p);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.t != t;
}
