import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/sprite_cache.dart';
import '../core/theme.dart';
import 'models.dart';
import 'level.dart';
import 'game_controller.dart';

/// Maps world units (100 wide x worldHeight tall) to on-screen pixels.
class GameGeom {
  final double scale;
  final Offset origin;
  const GameGeom(this.scale, this.origin);

  factory GameGeom.fit(Size size, double worldHeight) {
    final scale = math.min(size.width / kWorldWidth, size.height / worldHeight);
    final w = kWorldWidth * scale;
    final h = worldHeight * scale;
    return GameGeom(scale, Offset((size.width - w) / 2, (size.height - h) / 2));
  }

  Offset toScreen(Offset w) => Offset(origin.dx + w.dx * scale, origin.dy + w.dy * scale);
  Offset toWorld(Offset s) => Offset((s.dx - origin.dx) / scale, (s.dy - origin.dy) / scale);
  double s(double v) => v * scale;
}

class GamePainter extends CustomPainter {
  final GameController c;
  final ui.Image? bg;
  GamePainter(this.c) : bg = SpriteCache.instance.get('assets/bg/location${c.level.bgIndex}.webp'), super(repaint: c);

  @override
  void paint(Canvas canvas, Size size) {
    final g = GameGeom.fit(size, c.level.worldHeight);
    final field = Rect.fromLTWH(g.origin.dx, g.origin.dy, kWorldWidth * g.scale, c.level.worldHeight * g.scale);

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(field, const Radius.circular(18)));

    _drawBackground(canvas, field);

    _drawWalls(canvas, g);
    _drawReflectors(canvas, g);
    _drawDevices(canvas, g);
    _drawParticles(canvas, g);
    if (c.phase == GamePhase.aiming) _drawAimGuide(canvas, g);
    _drawLauncher(canvas, g);
    if (c.ballActive) _drawBall(canvas, g);

    canvas.restore();

    // field border
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = const LinearGradient(colors: NovaColors.heroGradient)
          .createShader(field);
    canvas.drawRRect(RRect.fromRectAndRadius(field, const Radius.circular(18)), border);
  }

  void _drawBackground(Canvas canvas, Rect field) {
    if (bg != null) {
      paintImageCover(canvas, field, bg!);
      canvas.drawRect(field, Paint()..color = const Color(0x66060818));
    } else {
      canvas.drawRect(field, Paint()..color = NovaColors.deepSpace);
    }
  }

  void _drawWalls(Canvas canvas, GameGeom g) {
    final p = Paint()..color = const Color(0xFF5A6690);
    final glow = Paint()
      ..color = NovaColors.cyan.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (final w in c.level.walls) {
      final r = Rect.fromLTWH(
        g.origin.dx + w.left * g.scale,
        g.origin.dy + w.top * g.scale,
        w.width * g.scale,
        w.height * g.scale,
      );
      final rr = RRect.fromRectAndRadius(r, Radius.circular(r.height / 2));
      canvas.drawRRect(rr, glow);
      canvas.drawRRect(rr, p);
    }
  }

  void _drawReflectors(Canvas canvas, GameGeom g) {
    for (final rf in c.level.reflectors) {
      final a = g.toScreen(rf.a);
      final b = g.toScreen(rf.b);
      final thickness = g.s(3.0);
      final glowColor = Color.lerp(NovaColors.cyan, Colors.white, rf.pulse)!;
      final glow = Paint()
        ..color = glowColor.withValues(alpha: 0.5 + rf.pulse * 0.4)
        ..strokeWidth = thickness + 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawLine(a, b, glow);
      final core = Paint()
        ..shader = const LinearGradient(colors: [NovaColors.cyan, NovaColors.violet])
            .createShader(Rect.fromPoints(a, b))
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a, b, core);
      // end caps
      final cap = Paint()..color = Colors.white.withValues(alpha: 0.9);
      canvas.drawCircle(a, thickness * 0.55, cap);
      canvas.drawCircle(b, thickness * 0.55, cap);
    }
  }

  void _drawDevices(Canvas canvas, GameGeom g) {
    for (final d in c.level.devices) {
      if (d.consumed) continue;
      final center = g.toScreen(d.pos);
      final img = SpriteCache.instance.sprite(d.cat, d.spriteIndex);
      final boxR = g.s(d.radius) * (d.kind == DeviceKind.core ? 1.28 : 1.18);

      // glow
      final glowColor = _deviceGlow(d);
      final needCharge = d.mustCharge && !d.charged;
      final glowAlpha = needCharge ? 0.25 : (0.45 + d.pulse * 0.5);
      canvas.drawCircle(
        center,
        boxR * (1.15 + d.pulse * 0.25),
        Paint()
          ..color = glowColor.withValues(alpha: glowAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, boxR * 0.5),
      );

      // field ring for magnets / antigrav
      if (d.fieldRadius > 0) {
        canvas.drawCircle(
          center,
          g.s(d.fieldRadius),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = glowColor.withValues(alpha: 0.18),
        );
      }

      if (img != null) {
        final dest = Rect.fromCenter(center: center, width: boxR * 2, height: boxR * 2);
        final paint = Paint()..filterQuality = FilterQuality.medium;
        if (needCharge) {
          paint.colorFilter = const ColorFilter.matrix(<double>[
            0.5, 0, 0, 0, 0, //
            0, 0.5, 0, 0, 0, //
            0, 0, 0.5, 0, 0, //
            0, 0, 0, 0.75, 0,
          ]);
        }
        canvas.save();
        canvas.translate(center.dx, center.dy);
        if (d.kind == DeviceKind.teleporter || d.kind == DeviceKind.antigrav) {
          canvas.rotate(d.spin);
        }
        final s = 1.0 + d.pulse * 0.12;
        canvas.scale(s, s);
        canvas.translate(-center.dx, -center.dy);
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          dest,
          paint,
        );
        canvas.restore();
      } else {
        canvas.drawCircle(center, boxR, Paint()..color = glowColor);
      }
    }
  }

  Color _deviceGlow(Device d) {
    switch (d.kind) {
      case DeviceKind.reactor:
        return c.chargedColor(d);
      case DeviceKind.core:
        return NovaColors.gold;
      case DeviceKind.magnet:
        return NovaColors.blue;
      case DeviceKind.antigrav:
        return NovaColors.violet;
      case DeviceKind.teleporter:
        return NovaColors.cyan;
      case DeviceKind.booster:
        return NovaColors.cyan;
      case DeviceKind.crystal:
        return const Color(0xFF6FE0FF);
      case DeviceKind.bumper:
        return NovaColors.stroke;
    }
  }

  void _drawParticles(Canvas canvas, GameGeom g) {
    for (final p in c.particles) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(
        g.toScreen(p.pos),
        g.s(p.size) * a,
        Paint()
          ..color = p.color.withValues(alpha: a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  void _drawAimGuide(Canvas canvas, GameGeom g) {
    // simulate a short trajectory preview
    var pos = Offset(c.level.launchX, 9);
    var vel = Offset(math.sin(c.aimAngle), math.cos(c.aimAngle)) * c.launchSpeed;
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.85);
    const h = 1 / 60.0;
    for (var i = 0; i < 90; i++) {
      vel = Offset(vel.dx, vel.dy + 62 * h);
      pos += vel * h;
      if (pos.dx < 2 || pos.dx > kWorldWidth - 2) break;
      if (pos.dy > c.level.worldHeight) break;
      if (i % 6 == 0) {
        final fade = (1 - i / 90).clamp(0.15, 1.0);
        canvas.drawCircle(g.toScreen(pos), g.s(0.9), dot..color = Colors.white.withValues(alpha: fade * 0.8));
      }
    }
  }

  void _drawLauncher(Canvas canvas, GameGeom g) {
    final center = g.toScreen(Offset(c.level.launchX, 9));
    final r = g.s(5.5);
    canvas.drawCircle(center, r * 1.2, Paint()
      ..color = NovaColors.cyan.withValues(alpha: 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5));
    canvas.drawCircle(center, r, Paint()
      ..shader = const RadialGradient(colors: [Colors.white, NovaColors.cyan, NovaColors.blue])
          .createShader(Rect.fromCircle(center: center, radius: r)));
    canvas.drawCircle(center, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.7));
  }

  void _drawBall(Canvas canvas, GameGeom g) {
    // trail
    for (var i = 0; i < c.trail.length; i++) {
      final a = i / c.trail.length;
      canvas.drawCircle(
        g.toScreen(c.trail[i]),
        g.s(c.ballRadius) * a * 0.9,
        Paint()..color = NovaColors.cyan.withValues(alpha: a * 0.25),
      );
    }
    final center = g.toScreen(c.ballPos);
    final r = g.s(c.ballRadius);
    canvas.drawCircle(center, r * 1.7, Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r));
    final img = SpriteCache.instance.sprite('token', c.skin);
    if (img != null) {
      final dest = Rect.fromCenter(center: center, width: r * 2.6, height: r * 2.6);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dest,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      canvas.drawCircle(center, r, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => true;
}

extension on GameController {
  Color chargedColor(Device d) {
    const colors = [
      Color(0xFF35E7FF), Color(0xFFFFA23D), Color(0xFF6FA8FF), Color(0xFF56F09B),
      Color(0xFF9B5BFF), Color(0xFF35E7FF), Color(0xFF6FE0FF), Color(0xFFFF4FD8), Color(0xFFFFC24B),
    ];
    return colors[d.spriteIndex % colors.length];
  }
}

/// Draws [img] covering [rect] (BoxFit.cover) with center alignment.
void paintImageCover(Canvas canvas, Rect rect, ui.Image img) {
  final iw = img.width.toDouble();
  final ih = img.height.toDouble();
  final scale = math.max(rect.width / iw, rect.height / ih);
  final w = iw * scale;
  final h = ih * scale;
  final src = Rect.fromLTWH((w - rect.width) / 2 / scale, (h - rect.height) / 2 / scale,
      rect.width / scale, rect.height / scale);
  canvas.drawImageRect(img, src, rect, Paint()..filterQuality = FilterQuality.medium);
}
