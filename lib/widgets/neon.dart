import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/audio.dart';
import '../core/assets.dart';
import '../core/theme.dart';

/// A glassy neon panel with gradient border and inner glow.
class NeonPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final List<Color> border;
  final double radius;
  final Color fill;
  const NeonPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.border = NovaColors.heroGradient,
    this.radius = 22,
    this.fill = const Color(0xCC0B1030),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: border.map((c) => c.withValues(alpha: 0.9)).toList(),
        ),
        boxShadow: [
          BoxShadow(color: border.first.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: -4),
        ],
      ),
      padding: const EdgeInsets.all(1.6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius - 1.6),
          color: fill,
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Primary neon action button with press animation and click sound.
class NeonButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final List<Color> gradient;
  final double height;
  final double fontSize;
  final bool enabled;
  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.gradient = NovaColors.heroGradient,
    this.height = 58,
    this.fontSize = 18,
    this.enabled = true,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              Audio.instance.sfx(Sfx.uiClick, volume: 0.7);
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.height / 2),
              gradient: LinearGradient(colors: widget.gradient),
              boxShadow: [
                BoxShadow(
                  color: widget.gradient.last.withValues(alpha: 0.5),
                  blurRadius: 18,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.height / 2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.28), Colors.transparent],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: Colors.white, size: widget.fontSize + 4),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          widget.label.toUpperCase(),
                          style: NovaText.title(widget.fontSize, spacing: 1.8).copyWith(
                            shadows: [const Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1))],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular icon button (used for back / settings / sound).
class NeonIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final List<Color> gradient;
  final double size;
  const NeonIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.gradient = NovaColors.heroGradient,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Audio.instance.sfx(Sfx.uiClick, volume: 0.6);
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: gradient),
          boxShadow: [BoxShadow(color: gradient.last.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: -2)],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}

/// Animated title logo image with a subtle floating/orbit motion.
class FloatingLogo extends StatefulWidget {
  final double width;
  const FloatingLogo({super.key, required this.width});

  @override
  State<FloatingLogo> createState() => _FloatingLogoState();
}

class _FloatingLogoState extends State<FloatingLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final dy = math.sin(_c.value * math.pi * 2) * 8;
        final s = 1 + math.sin(_c.value * math.pi * 2) * 0.02;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(scale: s, child: child),
        );
      },
      child: Image.asset(A.gameName, width: widget.width),
    );
  }
}
