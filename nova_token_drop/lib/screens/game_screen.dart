import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../core/audio.dart';
import '../core/assets.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../game/game_controller.dart';
import '../game/game_painter.dart';
import '../game/level.dart';
import '../widgets/neon.dart';
import '../widgets/starfield.dart';
import 'chapter_complete_screen.dart';

class GameScreen extends StatefulWidget {
  final int levelId;
  const GameScreen({super.key, required this.levelId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late GameController c;
  Ticker? _ticker;
  Duration _last = Duration.zero;
  Size _fieldSize = const Size(1, 1);
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _build(widget.levelId);
    // SingleTickerProviderStateMixin only allows one ticker for the lifetime
    // of this State, so it must be created exactly once here (not per level).
    _ticker = createTicker(_tick)..start();
    Audio.instance.playMusic(Music.game);
  }

  void _build(int id) {
    final previous = _built ? c : null;
    c = GameController(LevelFactory.build(id), GameStorage.instance.skin);
    _built = true;
    previous?.dispose();
    _last = Duration.zero;
  }

  bool _built = false;

  void _tick(Duration elapsed) {
    if (_paused) {
      _last = elapsed;
      return;
    }
    final dt = _last == Duration.zero ? 0.016 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    c.step(dt.clamp(0.0, 0.05));
  }

  @override
  void dispose() {
    _ticker?.dispose();
    c.dispose();
    // Leaving the game screen (back button, Menu button, or moving on to a
    // chapter-complete interstitial) must hand audio back to the menu theme
    // instead of letting the game theme keep looping underneath.
    Audio.instance.playMusic(Music.menu);
    super.dispose();
  }

  GameGeom get _geom => GameGeom.fit(_fieldSize, c.level.worldHeight);

  void _onTapDown(TapDownDetails d) {
    if (c.phase != GamePhase.aiming) return;
    final local = d.localPosition;
    if (c.movesLeft > 0) {
      final g = _geom;
      for (var i = 0; i < c.level.reflectors.length; i++) {
        final rf = c.level.reflectors[i];
        if (_distToSeg(local, g.toScreen(rf.a), g.toScreen(rf.b)) < 26) {
          c.rotateReflector(i);
          return;
        }
      }
    }
    _aimTo(local);
  }

  void _aimTo(Offset local) {
    final g = _geom;
    final launcher = g.toScreen(Offset(c.level.launchX, 9));
    final dir = local - launcher;
    if (dir.dy <= 2) return;
    c.setAim(math.atan2(dir.dx, dir.dy));
  }

  double _distToSeg(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    var t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  void _retry() => setState(() {
        _paused = false;
        _build(c.level.id);
      });

  void _next() {
    final finished = c.level.id;
    final next = finished + 1;
    final finishedChapter = chapterOf(finished);
    final enteringNewChapter = next > 40 || chapterOf(next) != finishedChapter;

    if (enteringNewChapter) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChapterCompleteScreen(
            chapter: finishedChapter,
            nextLevel: next <= 40 ? next : null,
          ),
        ),
      );
      return;
    }
    setState(() {
      _paused = false;
      _build(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Starfield(
        nebula: _nebulaFor(c.level.chapter),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHud(),
                  Expanded(
                    child: LayoutBuilder(builder: (ctx, cons) {
                      _fieldSize = Size(cons.maxWidth, cons.maxHeight);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: _onTapDown,
                        onPanUpdate: (d) {
                          if (c.phase == GamePhase.aiming) _aimTo(d.localPosition);
                        },
                        child: RepaintBoundary(
                          child: CustomPaint(painter: GamePainter(c), size: Size.infinite),
                        ),
                      );
                    }),
                  ),
                  _buildBottomBar(),
                ],
              ),
              AnimatedBuilder(
                animation: c,
                builder: (_, _) {
                  if (c.phase == GamePhase.won) return _resultOverlay(won: true);
                  if (c.phase == GamePhase.lost) return _resultOverlay(won: false);
                  if (_paused) return _pauseOverlay();
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _nebulaFor(int chapter) {
    const palettes = [
      [Color(0xFF15224F), Color(0xFF071033)],
      [Color(0xFF2A1147), Color(0xFF0A0730)],
      [Color(0xFF102A45), Color(0xFF06122B)],
      [Color(0xFF241452), Color(0xFF0A0730)],
      [Color(0xFF3A1030), Color(0xFF120726)],
      [Color(0xFF3A1414), Color(0xFF120610)],
    ];
    return palettes[chapter % palettes.length];
  }

  // ---------- HUD ----------
  Widget _buildHud() {
    return AnimatedBuilder(
      animation: c,
      builder: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
        child: Column(
          children: [
            Row(
              children: [
                NeonIconButton(
                  icon: Icons.arrow_back_rounded,
                  size: 42,
                  gradient: const [NovaColors.violet, NovaColors.blue],
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                _hudChip(Icons.diamond_rounded, '${GameStorage.instance.crystals}', NovaColors.cyan),
                const Spacer(),
                Text('LEVEL ${c.level.id}', style: NovaText.title(16)),
                const Spacer(),
                _hudChip(Icons.sports_score_rounded, '${c.score}', NovaColors.gold),
                const SizedBox(width: 8),
                NeonIconButton(
                  icon: Icons.pause_rounded,
                  size: 42,
                  gradient: const [NovaColors.blue, NovaColors.cyan],
                  onTap: () => setState(() => _paused = true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _reactorBar()),
                const SizedBox(width: 10),
                _hudChip(Icons.blur_circular_rounded, '${c.ballsLeft}', NovaColors.magenta),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hudChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC0B1030),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 5),
        Text(value, style: NovaText.title(14)),
      ]),
    );
  }

  Widget _reactorBar() {
    final total = c.requiredReactors;
    final done = c.reactorsCharged;
    final frac = total == 0 ? 0.0 : done / total;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC0B1030),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: NovaColors.green.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Row(children: [
        const Icon(Icons.bolt_rounded, color: NovaColors.green, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(children: [
              Container(height: 8, color: Colors.white10),
              FractionallySizedBox(
                widthFactor: frac.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [NovaColors.green, NovaColors.cyan]),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Text('$done/$total', style: NovaText.title(13)),
      ]),
    );
  }

  // ---------- bottom bar ----------
  // Height must stay constant across phases (aiming/simulating) so the game
  // field above it never resizes when the player taps Launch.
  Widget _buildBottomBar() {
    return AnimatedBuilder(
      animation: c,
      builder: (_, _) {
        if (c.phase == GamePhase.won || c.phase == GamePhase.lost) {
          return const SizedBox(height: 4);
        }
        final aiming = c.phase == GamePhase.aiming;
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: Column(children: [
            Visibility(
              visible: aiming,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.touch_app_rounded, size: 16, color: NovaColors.textLo),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        c.level.reflectors.isNotEmpty
                            ? 'Drag to aim · tap reflectors to rotate (${c.movesLeft})'
                            : 'Drag to aim, then launch',
                        style: NovaText.label(12, color: NovaColors.textLo),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(children: [
              Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: _abilityRow())),
              const SizedBox(width: 10),
              SizedBox(
                width: 128,
                height: 56,
                child: Visibility(
                  visible: aiming,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: NeonButton(
                    label: 'Launch',
                    icon: Icons.rocket_launch_rounded,
                    gradient: NovaColors.goldGradient,
                    height: 56,
                    fontSize: 16,
                    onTap: c.launch,
                  ),
                ),
              ),
            ]),
          ]),
        );
      },
    );
  }

  Widget _abilityRow() {
    return Row(
      children: [
        for (final e in c.abilities.entries)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _abilityButton(e.key, e.value),
          ),
      ],
    );
  }

  Widget _abilityButton(AbilityType type, int count) {
    final info = _abilityInfo(type);
    final enabled = count > 0 && c.phase == GamePhase.simulating;
    return GestureDetector(
      onTap: enabled ? () => c.useAbility(type) : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: info.$2),
            boxShadow: enabled
                ? [BoxShadow(color: info.$2.last.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: -2)]
                : null,
          ),
          child: Stack(children: [
            Center(child: Icon(info.$1, color: Colors.white, size: 24)),
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text('$count', textAlign: TextAlign.center, style: NovaText.title(10)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  (IconData, List<Color>) _abilityInfo(AbilityType t) {
    switch (t) {
      case AbilityType.slowmo:
        return (Icons.hourglass_bottom_rounded, const [NovaColors.cyan, NovaColors.blue]);
      case AbilityType.gravityFlip:
        return (Icons.swap_vert_rounded, const [NovaColors.violet, NovaColors.magenta]);
      case AbilityType.nudge:
        return (Icons.control_camera_rounded, const [NovaColors.green, NovaColors.cyan]);
      case AbilityType.magnetPulse:
        return (Icons.blur_on_rounded, const [NovaColors.blue, NovaColors.violet]);
    }
  }

  // ---------- overlays ----------
  Widget _resultOverlay({required bool won}) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: NeonPanel(
          border: won ? NovaColors.goldGradient : const [NovaColors.red, NovaColors.violet],
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(won ? 'LEVEL COMPLETE' : 'OUT OF TOKENS',
                  style: NovaText.title(22, color: won ? NovaColors.gold : NovaColors.red)),
              const SizedBox(height: 16),
              if (won) _stars(c.stars),
              const SizedBox(height: 16),
              _resultStat('Score', '${c.score}', NovaColors.gold),
              _resultStat('Reactors charged', '${c.reactorsCharged}/${c.requiredReactors}', NovaColors.green),
              _resultStat('Best chain', 'x${c.bestChain}', NovaColors.magenta),
              if (won) _resultStat('Crystals earned', '+${c.crystalsEarned}', NovaColors.cyan),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: NeonButton(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    gradient: const [NovaColors.blue, NovaColors.violet],
                    height: 52,
                    fontSize: 15,
                    onTap: _retry,
                  ),
                ),
                const SizedBox(width: 10),
                if (won)
                  Expanded(
                    child: NeonButton(
                      label: c.level.id < 40 ? 'Next' : 'Finish',
                      icon: c.level.id < 40 ? Icons.arrow_forward_rounded : Icons.emoji_events_rounded,
                      gradient: NovaColors.goldGradient,
                      height: 52,
                      fontSize: 15,
                      onTap: _next,
                    ),
                  ),
              ]),
              const SizedBox(height: 10),
              NeonButton(
                label: 'Menu',
                icon: Icons.home_rounded,
                gradient: const [NovaColors.stroke, NovaColors.blue],
                height: 48,
                fontSize: 14,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stars(int n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final filled = i < n;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 48,
            color: filled ? NovaColors.gold : NovaColors.textLo,
            shadows: filled
                ? [BoxShadow(color: NovaColors.gold.withValues(alpha: 0.7), blurRadius: 14)]
                : null,
          ),
        );
      }),
    );
  }

  Widget _resultStat(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: NovaText.label(14, color: NovaColors.textLo)),
          Text(value, style: NovaText.title(15, color: color)),
        ],
      ),
    );
  }

  Widget _pauseOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: NeonPanel(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('PAUSED', style: NovaText.title(24)),
            const SizedBox(height: 22),
            NeonButton(label: 'Resume', icon: Icons.play_arrow_rounded, onTap: () => setState(() => _paused = false)),
            const SizedBox(height: 12),
            NeonButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              gradient: const [NovaColors.blue, NovaColors.violet],
              onTap: _retry,
            ),
            const SizedBox(height: 12),
            NeonButton(
              label: 'Menu',
              icon: Icons.home_rounded,
              gradient: const [NovaColors.stroke, NovaColors.blue],
              onTap: () => Navigator.of(context).pop(),
            ),
          ]),
        ),
      ),
    );
  }
}
