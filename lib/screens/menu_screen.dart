import 'package:flutter/material.dart';
import '../core/assets.dart';
import '../core/audio.dart';
import '../core/daily_challenges.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/neon.dart';
import '../widgets/starfield.dart';
import 'daily_challenges_screen.dart';
import 'level_select_screen.dart';
import 'how_to_play_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'tokens_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  void initState() {
    super.initState();
    Audio.instance.playMusic(Music.menu);
  }

  void _refresh() => setState(() {});

  bool get _hasUnclaimedDaily {
    final store = GameStorage.instance;
    final defs = todaysChallenges();
    for (var i = 0; i < defs.length; i++) {
      if (!store.dailyClaimed(i) && store.dailyProgress(defs[i].metricKey) >= defs[i].target) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final store = GameStorage.instance;
    return Scaffold(
      body: Starfield(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    _statPill(Icons.diamond_rounded, '${store.crystals}', NovaColors.cyan),
                    const Spacer(),
                    _dailyBell(),
                    const SizedBox(width: 10),
                    _statPill(Icons.star_rounded, '${store.totalStars}/120', NovaColors.gold),
                  ],
                ),
                const Spacer(flex: 3),
                const FloatingLogo(width: 320),
                const Spacer(flex: 2),
                NeonButton(
                  label: 'Play',
                  icon: Icons.play_arrow_rounded,
                  gradient: NovaColors.goldGradient,
                  height: 64,
                  fontSize: 22,
                  onTap: () async {
                    await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LevelSelectScreen()));
                    _refresh();
                  },
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: NeonButton(
                      label: 'Tokens',
                      icon: Icons.bubble_chart_rounded,
                      gradient: const [NovaColors.magenta, NovaColors.violet],
                      height: 56,
                      fontSize: 16,
                      onTap: () async {
                        await Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const TokensScreen()));
                        _refresh();
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: NeonButton(
                      label: 'Progress',
                      icon: Icons.public_rounded,
                      gradient: const [NovaColors.green, NovaColors.cyan],
                      height: 56,
                      fontSize: 16,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const StatsScreen())),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: NeonButton(
                      label: 'How to',
                      icon: Icons.help_outline_rounded,
                      gradient: const [NovaColors.cyan, NovaColors.blue],
                      height: 56,
                      fontSize: 16,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const HowToPlayScreen())),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: NeonButton(
                      label: 'Settings',
                      icon: Icons.settings_rounded,
                      gradient: const [NovaColors.blue, NovaColors.violet],
                      height: 56,
                      fontSize: 16,
                      onTap: () async {
                        await Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                        _refresh();
                      },
                    ),
                  ),
                ]),
                const Spacer(flex: 2),
                Text('v1.0  ·  com.novatoken.dropgame',
                    style: NovaText.label(11, color: NovaColors.textLo)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dailyBell() {
    final badge = _hasUnclaimedDaily;
    return GestureDetector(
      onTap: () async {
        Audio.instance.sfx(Sfx.uiClick, volume: 0.6);
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const DailyChallengesScreen()));
        _refresh();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xCC0B1030),
              shape: BoxShape.circle,
              border: Border.all(color: NovaColors.magenta.withValues(alpha: 0.6), width: 1.4),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: NovaColors.magenta, size: 20),
          ),
          if (badge)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: NovaColors.red,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: NovaColors.red, blurRadius: 6)],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC0B1030),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(value, style: NovaText.title(15)),
      ]),
    );
  }
}
