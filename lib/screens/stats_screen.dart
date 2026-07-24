import 'package:flutter/material.dart';
import '../core/achievements.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../game/level.dart';
import '../widgets/neon.dart';
import '../widgets/starfield.dart';
import 'achievements_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  Widget build(BuildContext context) {
    final store = GameStorage.instance;
    final explored = store.galaxyExplored;
    final readyToClaim = kAchievements
        .where((d) => !store.achievementClaimed(d.id) && d.progressOf(store) >= d.target)
        .length;

    return Scaffold(
      body: Starfield(
        nebula: const [Color(0xFF102A45), Color(0xFF06122B)],
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Row(children: [
                  NeonIconButton(
                    icon: Icons.arrow_back_rounded,
                    gradient: const [NovaColors.violet, NovaColors.blue],
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Text('PROGRESS', style: NovaText.title(20)),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    NeonPanel(
                      border: NovaColors.goldGradient,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.public_rounded, color: NovaColors.gold, size: 22),
                            const SizedBox(width: 10),
                            Text('Galaxy Explored', style: NovaText.title(16)),
                            const Spacer(),
                            Text('${(explored * 100).round()}%',
                                style: NovaText.title(16, color: NovaColors.gold)),
                          ]),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(children: [
                              Container(height: 12, color: Colors.white10),
                              FractionallySizedBox(
                                widthFactor: explored.clamp(0.0, 1.0),
                                child: Container(
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(colors: NovaColors.goldGradient),
                                  ),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 6),
                          Text('${store.levelsCompleted}/40 levels completed',
                              style: NovaText.label(12, color: NovaColors.textLo)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    NeonButton(
                      label: readyToClaim > 0
                          ? 'Achievements · $readyToClaim ready'
                          : 'Achievements',
                      icon: Icons.emoji_events_rounded,
                      gradient: readyToClaim > 0
                          ? NovaColors.goldGradient
                          : const [NovaColors.magenta, NovaColors.violet],
                      height: 52,
                      fontSize: 14,
                      onTap: () async {
                        await Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const AchievementsScreen()));
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        _stat(Icons.bolt_rounded, '${store.lifeReactors}', 'Reactors charged', const [NovaColors.green, NovaColors.cyan]),
                        _stat(Icons.auto_awesome_rounded, 'x${store.lifeChainBest}', 'Longest chain', const [NovaColors.gold, Color(0xFFFF8A3D)]),
                        _stat(Icons.diamond_rounded, '${store.lifeCrystalsCollected}', 'Crystals collected', const [NovaColors.cyan, NovaColors.blue]),
                        _stat(Icons.star_rounded, '${store.totalStars}/120', 'Stars earned', const [NovaColors.gold, NovaColors.red]),
                        _stat(Icons.military_tech_rounded, '${store.perfectLevels}/40', 'Perfect levels', const [NovaColors.magenta, NovaColors.violet]),
                        _stat(Icons.blur_on_rounded, '${store.lifeMagnetUses}', 'Fields triggered', const [NovaColors.blue, NovaColors.violet]),
                        _stat(Icons.rocket_launch_rounded, '${store.lifeBoosterUses}', 'Boosts triggered', const [NovaColors.cyan, NovaColors.green]),
                        _stat(Icons.blur_circular_rounded, '${store.lifeBallsLaunched}', 'Tokens launched', const [NovaColors.violet, NovaColors.pink]),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text('Sectors', style: NovaText.title(16)),
                    const SizedBox(height: 10),
                    for (var ch = 0; ch < kChapterSizes.length; ch++) _chapterRow(ch, store),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label, List<Color> grad) {
    return NeonPanel(
      border: grad,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: grad.first, size: 24),
          const SizedBox(height: 8),
          Text(value, style: NovaText.title(19)),
          const SizedBox(height: 2),
          Text(label, style: NovaText.label(11, color: NovaColors.textLo)),
        ],
      ),
    );
  }

  Widget _chapterRow(int ch, GameStorage store) {
    var startId = 1;
    for (var i = 0; i < ch; i++) {
      startId += kChapterSizes[i];
    }
    var done = 0;
    for (var i = startId; i < startId + kChapterSizes[ch]; i++) {
      if (store.stars(i) > 0) done++;
    }
    final frac = done / kChapterSizes[ch];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(width: 22, child: Text('${ch + 1}', style: NovaText.title(13, color: NovaColors.textLo))),
        Expanded(child: Text(kChapterNames[ch], style: NovaText.label(13))),
        SizedBox(
          width: 90,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(children: [
              Container(height: 8, color: Colors.white10),
              FractionallySizedBox(
                widthFactor: frac.clamp(0.0, 1.0),
                child: Container(
                    height: 8,
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [NovaColors.cyan, NovaColors.violet]))),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Text('$done/${kChapterSizes[ch]}', style: NovaText.label(11, color: NovaColors.textLo)),
      ]),
    );
  }
}
