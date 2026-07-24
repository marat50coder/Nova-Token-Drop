import 'package:flutter/material.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../game/level.dart';
import '../widgets/neon.dart';
import '../widgets/starfield.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  Future<void> _openLevel(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(levelId: id)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = GameStorage.instance;
    return Scaffold(
      body: Starfield(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Row(
                  children: [
                    NeonIconButton(
                      icon: Icons.arrow_back_rounded,
                      gradient: const [NovaColors.violet, NovaColors.blue],
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Text('SELECT SECTOR', style: NovaText.title(20)),
                    const Spacer(),
                    Icon(Icons.star_rounded, color: NovaColors.gold, size: 20),
                    const SizedBox(width: 4),
                    Text('${store.totalStars}', style: NovaText.title(16)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                  children: [
                    for (var ch = 0; ch < kChapterSizes.length; ch++) _chapter(ch),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chapter(int ch) {
    final store = GameStorage.instance;
    var startId = 1;
    for (var i = 0; i < ch; i++) {
      startId += kChapterSizes[i];
    }
    final ids = List.generate(kChapterSizes[ch], (i) => startId + i);
    final unlockedAny = ids.first <= store.unlockedLevel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: NeonPanel(
        border: _chapterColors(ch),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: _chapterColors(ch)),
                ),
                child: Text('${ch + 1}', style: NovaText.title(14)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(kChapterNames[ch],
                    style: NovaText.title(16),
                    overflow: TextOverflow.ellipsis),
              ),
              if (!unlockedAny) const Icon(Icons.lock_rounded, color: NovaColors.textLo, size: 18),
            ]),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [for (final id in ids) _levelTile(id)],
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelTile(int id) {
    final store = GameStorage.instance;
    final locked = id > store.unlockedLevel;
    final stars = store.stars(id);
    final ch = chapterOf(id);
    return GestureDetector(
      onTap: locked ? null : () => _openLevel(id),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: locked
              ? const LinearGradient(colors: [Color(0xFF161A30), Color(0xFF0D1024)])
              : LinearGradient(colors: _chapterColors(ch).map((c) => c.withValues(alpha: 0.9)).toList()),
          border: Border.all(color: Colors.white.withValues(alpha: locked ? 0.06 : 0.25)),
          boxShadow: locked
              ? null
              : [BoxShadow(color: _chapterColors(ch).last.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: -3)],
        ),
        child: locked
            ? const Center(child: Icon(Icons.lock_rounded, color: NovaColors.textLo, size: 22))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$id', style: NovaText.title(22)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => Icon(
                        i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 12,
                        color: i < stars ? NovaColors.gold : Colors.white38,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Color> _chapterColors(int ch) {
    const palettes = [
      [NovaColors.cyan, NovaColors.blue],
      [NovaColors.green, NovaColors.cyan],
      [NovaColors.blue, NovaColors.violet],
      [NovaColors.violet, NovaColors.magenta],
      [NovaColors.magenta, NovaColors.pink],
      [NovaColors.gold, NovaColors.red],
    ];
    return palettes[ch % palettes.length];
  }
}
