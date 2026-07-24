import 'package:flutter/material.dart';
import '../core/achievements.dart';
import '../core/assets.dart';
import '../core/audio.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/neon.dart';
import '../widgets/starfield.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  void _claim(AchievementDef def) {
    GameStorage.instance.claimAchievement(def.id, def.reward);
    Audio.instance.sfx(Sfx.crystal, volume: 1.0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = GameStorage.instance;
    final unlockedCount = kAchievements.where((d) => d.progressOf(store) >= d.target).length;

    return Scaffold(
      body: Starfield(
        nebula: const [Color(0xFF3A1030), Color(0xFF120726)],
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
                  Text('ACHIEVEMENTS', style: NovaText.title(18)),
                  const Spacer(),
                  Text('$unlockedCount/${kAchievements.length}',
                      style: NovaText.title(14, color: NovaColors.gold)),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  itemCount: kAchievements.length,
                  itemBuilder: (ctx, i) => _card(kAchievements[i], store),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(AchievementDef def, GameStorage store) {
    final progress = def.progressOf(store);
    final done = progress >= def.target;
    final claimed = store.achievementClaimed(def.id);
    final frac = (progress / def.target).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: NeonPanel(
        border: claimed ? const [NovaColors.stroke, NovaColors.stroke] : def.color,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                    colors: claimed ? const [NovaColors.stroke, NovaColors.panelDark] : def.color),
              ),
              child: Icon(
                claimed ? Icons.check_rounded : def.icon,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.title, style: NovaText.title(14)),
                  const SizedBox(height: 2),
                  Text(def.description, style: NovaText.label(11, color: NovaColors.textLo)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(children: [
                      Container(height: 8, color: Colors.white10),
                      FractionallySizedBox(
                        widthFactor: frac,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: claimed ? const [NovaColors.stroke, NovaColors.stroke] : def.color),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  Text('${progress.clamp(0, def.target)}/${def.target}',
                      style: NovaText.label(11, color: NovaColors.textLo)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 88,
              child: claimed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: NovaColors.green, size: 26),
                        Text('Claimed', style: NovaText.label(10, color: NovaColors.textLo)),
                      ],
                    )
                  : NeonButton(
                      label: '+${def.reward}',
                      icon: Icons.diamond_rounded,
                      gradient: done ? NovaColors.goldGradient : const [NovaColors.stroke, NovaColors.panelDark],
                      height: 42,
                      fontSize: 12,
                      enabled: done,
                      onTap: () => _claim(def),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
