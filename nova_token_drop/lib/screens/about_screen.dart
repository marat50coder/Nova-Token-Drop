import 'package:flutter/material.dart';
import '../core/assets.dart';
import '../core/audio.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../game/level.dart';
import '../widgets/neon.dart';
import '../widgets/starfield.dart';
import 'webview_screen.dart';

/// Real app info: derived from actual save data (not placeholder numbers),
/// plus working links into the Privacy Policy / Support web views.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
                  Text('ABOUT', style: NovaText.title(20)),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Center(child: Image.asset(A.gameName, width: 220)),
                    const SizedBox(height: 22),
                    NeonPanel(
                      child: Column(children: [
                        _row('Version', '1.0.0'),
                        const Divider(color: NovaColors.stroke, height: 18),
                        _row('Package', 'com.novatoken.dropgame'),
                        const Divider(color: NovaColors.stroke, height: 18),
                        _row('Sectors explored', '${(store.galaxyExplored * 100).round()}% · ${store.levelsCompleted}/40 levels'),
                        const Divider(color: NovaColors.stroke, height: 18),
                        _row('Reactors charged (lifetime)', '${store.lifeReactors}'),
                        const Divider(color: NovaColors.stroke, height: 18),
                        _row('Longest chain reaction', 'x${store.lifeChainBest}'),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Text('Sectors', style: NovaText.title(15)),
                    const SizedBox(height: 8),
                    NeonPanel(
                      border: const [NovaColors.cyan, NovaColors.blue],
                      child: Column(
                        children: [
                          for (var i = 0; i < kChapterNames.length; i++) ...[
                            if (i > 0) const Divider(color: NovaColors.stroke, height: 14),
                            Row(children: [
                              Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: NovaColors.deepSpace,
                                  border: Border.all(color: NovaColors.cyan.withValues(alpha: 0.5)),
                                ),
                                child: Text('${i + 1}', style: NovaText.title(12)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(kChapterNames[i], style: NovaText.label(13))),
                            ]),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    NeonPanel(
                      border: const [NovaColors.magenta, NovaColors.violet],
                      child: Column(children: [
                        _link(context, Icons.privacy_tip_rounded, 'Privacy Policy',
                            'https://novatokendrop.com/privacy-policy.html',
                            white: true),
                        const Divider(color: NovaColors.stroke, height: 22),
                        _link(context, Icons.support_agent_rounded, 'Support',
                            'https://novatokendrop.com/support.html'),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Nova Token Drop\nOperate the stations. Charge every reactor.\nDeliver power to the Nova Core.',
                        textAlign: TextAlign.center,
                        style: NovaText.label(12, color: NovaColors.textLo).copyWith(height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: NovaText.label(13, color: NovaColors.textLo))),
        Text(value, style: NovaText.title(13)),
      ],
    );
  }

  Widget _link(BuildContext context, IconData icon, String label, String url, {bool white = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Audio.instance.sfx(Sfx.uiClick, volume: 0.6);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WebViewScreen(title: label, url: url, whiteBackground: white),
        ));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(icon, color: NovaColors.cyan, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: NovaText.title(15))),
          const Icon(Icons.chevron_right_rounded, color: NovaColors.textLo),
        ]),
      ),
    );
  }
}
