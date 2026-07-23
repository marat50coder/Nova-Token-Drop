import 'package:flutter/material.dart';
import '../core/assets.dart';
import '../core/audio.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/neon.dart';
import '../widgets/starfield.dart';

class TokensScreen extends StatefulWidget {
  const TokensScreen({super.key});

  @override
  State<TokensScreen> createState() => _TokensScreenState();
}

class _TokensScreenState extends State<TokensScreen> {
  static const names = [
    'Plasma', 'Cryo', 'Magnetic', 'Phase', 'Quantum', 'Nova', 'Verdant', 'Solar', 'Crystal',
  ];
  static const cost = 600;

  void _tap(int i) {
    final store = GameStorage.instance;
    if (store.skinUnlocked(i)) {
      store.skin = i;
      Audio.instance.sfx(Sfx.uiClick, volume: 0.7);
      setState(() {});
    } else if (store.crystals >= cost) {
      store.crystals -= cost;
      store.unlockSkin(i);
      store.skin = i;
      Audio.instance.sfx(Sfx.crystal, volume: 0.9);
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: NovaColors.panelDark,
          content: Text('Need $cost crystals to unlock ${names[i]}',
              style: NovaText.label(14)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
                child: Row(children: [
                  NeonIconButton(
                    icon: Icons.arrow_back_rounded,
                    gradient: const [NovaColors.violet, NovaColors.blue],
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Text('TOKENS', style: NovaText.title(20)),
                  const Spacer(),
                  Icon(Icons.diamond_rounded, color: NovaColors.cyan, size: 20),
                  const SizedBox(width: 4),
                  Text('${store.crystals}', style: NovaText.title(16)),
                ]),
              ),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  padding: const EdgeInsets.all(16),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  children: [for (var i = 0; i < 9; i++) _tile(i)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(int i) {
    final store = GameStorage.instance;
    final unlocked = store.skinUnlocked(i);
    final selected = store.skin == i;
    return GestureDetector(
      onTap: () => _tap(i),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xCC0B1030),
          border: Border.all(
            color: selected ? NovaColors.gold : NovaColors.stroke,
            width: selected ? 2.4 : 1.2,
          ),
          boxShadow: selected
              ? [BoxShadow(color: NovaColors.gold.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: -2)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: unlocked ? 1 : 0.4,
                  child: Image.asset(A.sprite('token', i), width: 62, height: 62),
                ),
                if (!unlocked)
                  const Icon(Icons.lock_rounded, color: Colors.white, size: 24),
              ],
            ),
            const SizedBox(height: 6),
            Text(names[i], style: NovaText.title(12)),
            const SizedBox(height: 2),
            if (selected)
              Text('EQUIPPED', style: NovaText.label(10, color: NovaColors.gold))
            else if (unlocked)
              Text('Tap to equip', style: NovaText.label(10, color: NovaColors.textLo))
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.diamond_rounded, color: NovaColors.cyan, size: 12),
                  const SizedBox(width: 3),
                  Text('$cost', style: NovaText.label(10, color: NovaColors.cyan)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
