import 'package:flutter/material.dart';
import '../core/audio.dart';
import '../core/assets.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../game/level.dart';
import '../widgets/neon.dart';
import '../widgets/starfield.dart';
import 'game_screen.dart';
import 'menu_screen.dart';

/// Shown when the player clears the final level of a chapter (a "sector").
/// Purely derived from real save data: chapter star totals, crystal totals
/// and the actual next-level unlock state — nothing here is decorative-only.
class ChapterCompleteScreen extends StatefulWidget {
  final int chapter; // 0..5, the chapter that was just finished
  final int? nextLevel; // null if chapter 5 (the whole galaxy) was finished

  const ChapterCompleteScreen({super.key, required this.chapter, this.nextLevel});

  @override
  State<ChapterCompleteScreen> createState() => _ChapterCompleteScreenState();
}

class _ChapterCompleteScreenState extends State<ChapterCompleteScreen> {
  @override
  void initState() {
    super.initState();
    Audio.instance.sfx(Sfx.perfect, volume: 1.0);
  }

  int _chapterStart(int chapter) {
    var start = 1;
    for (var i = 0; i < chapter; i++) {
      start += kChapterSizes[i];
    }
    return start;
  }

  @override
  Widget build(BuildContext context) {
    final store = GameStorage.instance;
    final start = _chapterStart(widget.chapter);
    final count = kChapterSizes[widget.chapter];
    var stars = 0;
    for (var i = start; i < start + count; i++) {
      stars += store.stars(i);
    }
    final maxStars = count * 3;
    final isFinalChapter = widget.nextLevel == null;

    return Scaffold(
      body: Starfield(
        nebula: _nebulaFor(widget.chapter),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isFinalChapter ? Icons.auto_awesome_rounded : Icons.rocket_launch_rounded,
                  size: 72,
                  color: NovaColors.gold,
                  shadows: [BoxShadow(color: NovaColors.gold.withValues(alpha: 0.7), blurRadius: 24)],
                ),
                const SizedBox(height: 18),
                Text(
                  isFinalChapter ? 'GALAXY CONQUERED' : 'SECTOR CLEARED',
                  textAlign: TextAlign.center,
                  style: NovaText.title(26, color: NovaColors.gold),
                ),
                const SizedBox(height: 8),
                Text(
                  kChapterNames[widget.chapter],
                  style: NovaText.title(16, color: NovaColors.cyan),
                ),
                const SizedBox(height: 24),
                NeonPanel(
                  border: NovaColors.goldGradient,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final filled = stars >= maxStars * (i + 1) / 3;
                          return Icon(
                            Icons.star_rounded,
                            size: 36,
                            color: filled ? NovaColors.gold : NovaColors.textLo,
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      Text('$stars / $maxStars stars in this sector',
                          style: NovaText.label(13, color: NovaColors.textLo)),
                      const Divider(color: NovaColors.stroke, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statChip(Icons.diamond_rounded, '${store.crystals}', NovaColors.cyan),
                          _statChip(Icons.flag_rounded, '${store.levelsCompleted}/40', NovaColors.green),
                          _statChip(Icons.public_rounded,
                              '${(store.galaxyExplored * 100).round()}%', NovaColors.violet),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                if (!isFinalChapter) ...[
                  Text(
                    'Sector ${widget.chapter + 2}: ${kChapterNames[widget.chapter + 1]} is now open.',
                    textAlign: TextAlign.center,
                    style: NovaText.label(13, color: NovaColors.textLo),
                  ),
                  const SizedBox(height: 14),
                  NeonButton(
                    label: 'Enter ${kChapterNames[widget.chapter + 1]}',
                    icon: Icons.arrow_forward_rounded,
                    gradient: NovaColors.goldGradient,
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => GameScreen(levelId: widget.nextLevel!),
                        ),
                      );
                    },
                  ),
                ] else
                  NeonButton(
                    label: 'Return to Menu',
                    icon: Icons.home_rounded,
                    gradient: NovaColors.goldGradient,
                    onTap: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const MenuScreen()),
                        (route) => false,
                      );
                    },
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MenuScreen()),
                    (route) => false,
                  ),
                  child: Text('Back to menu', style: NovaText.label(13, color: NovaColors.textLo)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String value, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 4),
      Text(value, style: NovaText.title(14)),
    ]);
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
}
