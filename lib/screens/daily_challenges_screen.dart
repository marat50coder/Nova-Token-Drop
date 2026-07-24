import 'dart:async';
import 'package:flutter/material.dart';
import '../core/audio.dart';
import '../core/assets.dart';
import '../core/daily_challenges.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/neon.dart';
import '../widgets/starfield.dart';

class DailyChallengesScreen extends StatefulWidget {
  const DailyChallengesScreen({super.key});

  @override
  State<DailyChallengesScreen> createState() => _DailyChallengesScreenState();
}

class _DailyChallengesScreenState extends State<DailyChallengesScreen> {
  Timer? _ticker;
  late List<DailyChallengeDef> _defs;

  @override
  void initState() {
    super.initState();
    _defs = todaysChallenges();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _claim(int slot, DailyChallengeDef def) {
    GameStorage.instance.claimDaily(slot, def.reward);
    Audio.instance.sfx(Sfx.crystal, volume: 1.0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = GameStorage.instance;
    final remain = store.timeUntilDailyReset;
    final hh = remain.inHours.toString().padLeft(2, '0');
    final mm = (remain.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (remain.inSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      body: Starfield(
        nebula: const [Color(0xFF241452), Color(0xFF0A0730)],
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
                  Text('DAILY CHALLENGES', style: NovaText.title(18)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: NeonPanel(
                  border: const [NovaColors.magenta, NovaColors.violet],
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Row(children: [
                    const Icon(Icons.hourglass_bottom_rounded, color: NovaColors.magenta, size: 20),
                    const SizedBox(width: 10),
                    Text('New tasks in', style: NovaText.label(13, color: NovaColors.textLo)),
                    const Spacer(),
                    Text('$hh:$mm:$ss', style: NovaText.title(16, color: NovaColors.gold)),
                  ]),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  itemCount: _defs.length,
                  itemBuilder: (ctx, i) => _card(i, _defs[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(int slot, DailyChallengeDef def) {
    final store = GameStorage.instance;
    final progress = store.dailyProgress(def.metricKey);
    final claimed = store.dailyClaimed(slot);
    final done = progress >= def.target;
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
                gradient: LinearGradient(colors: claimed ? const [NovaColors.stroke, NovaColors.panelDark] : def.color),
              ),
              child: Icon(def.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.title, style: NovaText.title(14)),
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
                            gradient: LinearGradient(colors: claimed ? const [NovaColors.stroke, NovaColors.stroke] : def.color),
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
                      onTap: () => _claim(slot, def),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
