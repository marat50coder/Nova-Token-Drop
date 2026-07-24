import 'package:flutter/material.dart';
import '../core/assets.dart';
import '../core/audio.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/neon.dart';
import '../widgets/starfield.dart';
import 'about_screen.dart';
import 'webview_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
                  Text('SETTINGS', style: NovaText.title(20)),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    NeonPanel(
                      child: Column(children: [
                        _toggle(
                          Icons.music_note_rounded,
                          'Music',
                          store.musicOn,
                          (v) {
                            setState(() => store.musicOn = v);
                            Audio.instance.refreshMusic();
                          },
                        ),
                        const Divider(color: NovaColors.stroke, height: 22),
                        _toggle(
                          Icons.volume_up_rounded,
                          'Sound Effects',
                          store.sfxOn,
                          (v) => setState(() => store.sfxOn = v),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    NeonPanel(
                      border: const [NovaColors.cyan, NovaColors.blue],
                      child: Column(children: [
                        _link(Icons.privacy_tip_rounded, 'Privacy Policy', () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const WebViewScreen(
                              title: 'Privacy Policy',
                              url: 'https://novatokendrop.com/privacy-policy.html',
                              whiteBackground: true,
                            ),
                          ));
                        }),
                        const Divider(color: NovaColors.stroke, height: 22),
                        _link(Icons.support_agent_rounded, 'Support', () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const WebViewScreen(
                              title: 'Support',
                              url: 'https://novatokendrop.com/support.html',
                            ),
                          ));
                        }),
                        const Divider(color: NovaColors.stroke, height: 22),
                        _link(Icons.info_outline_rounded, 'About Nova Token Drop', () {
                          Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => const AboutScreen()));
                        }),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    NeonPanel(
                      border: const [NovaColors.red, NovaColors.violet],
                      child: _link(Icons.restart_alt_rounded, 'Reset Progress', _confirmReset,
                          color: NovaColors.red),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text('Nova Token Drop · v1.0.0',
                          style: NovaText.label(12, color: NovaColors.textLo)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggle(IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return Row(children: [
      Icon(icon, color: NovaColors.cyan, size: 24),
      const SizedBox(width: 14),
      Expanded(child: Text(label, style: NovaText.title(16))),
      Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: NovaColors.cyan,
        inactiveTrackColor: NovaColors.panelDark,
      ),
    ]);
  }

  Widget _link(IconData icon, String label, VoidCallback onTap, {Color color = NovaColors.textHi}) {
    return InkWell(
      onTap: () {
        Audio.instance.sfx(Sfx.uiClick, volume: 0.6);
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, color: color == NovaColors.textHi ? NovaColors.cyan : color, size: 24),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: NovaText.title(16, color: color))),
          const Icon(Icons.chevron_right_rounded, color: NovaColors.textLo),
        ]),
      ),
    );
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Reset Progress?', style: NovaText.title(18)),
        content: Text('This will erase all levels, stars, crystals and unlocked tokens.',
            style: NovaText.label(14, color: NovaColors.textLo)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: NovaText.label(14, color: NovaColors.textLo)),
          ),
          TextButton(
            onPressed: () async {
              await GameStorage.instance.resetAll();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            },
            child: Text('Reset', style: NovaText.title(14, color: NovaColors.red)),
          ),
        ],
      ),
    );
  }
}
