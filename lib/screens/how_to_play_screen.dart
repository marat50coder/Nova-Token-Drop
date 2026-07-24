import 'package:flutter/material.dart';
import '../core/assets.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/neon.dart';
import '../widgets/starfield.dart';

class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  final _pc = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    GameStorage.instance.seenTutorial = true;
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages();
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
                  Text('HOW TO PLAY', style: NovaText.title(20)),
                ]),
              ),
              Expanded(
                child: PageView(
                  controller: _pc,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: pages,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == _page ? NovaColors.cyan : NovaColors.stroke,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: NeonButton(
                  label: _page == pages.length - 1 ? 'Got it' : 'Next',
                  icon: _page == pages.length - 1 ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  onTap: () {
                    if (_page == pages.length - 1) {
                      Navigator.of(context).pop();
                    } else {
                      _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _pages() {
    return [
      _page1(),
      _devicePage(
        'Charge Every Reactor',
        'Launch energy tokens and guide them so they strike each reactor and the central core. A level is won once every reactor is charged.',
        [
          _spriteItem('reactor', 0, 'Reactor', 'Charge it by hitting it'),
          _spriteItem('reactor', 8, 'Central Core', 'The final, biggest target'),
          _spriteItem('token', 8, 'Crystal', 'Collect for bonus points'),
        ],
      ),
      _devicePage(
        'Bend the Physics',
        'The station is full of devices that alter your token\'s path. Use them to build long chain reactions.',
        [
          _spriteItem('magnet', 0, 'Magnet', 'Pulls the token toward it'),
          _spriteItem('gravity', 0, 'Gravity Well', 'Pushes the token away'),
          _spriteItem('teleporter', 0, 'Teleporter', 'Warps to its twin portal'),
          _spriteItem('booster', 0, 'Booster', 'Rockets the token faster'),
        ],
      ),
      _abilityPage(),
    ];
  }

  Widget _page1() {
    return _wrap(Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(A.gameName, width: 240),
        const SizedBox(height: 20),
        Text('Objective', style: NovaText.title(22, color: NovaColors.gold)),
        const SizedBox(height: 12),
        Text(
          'You are the operator of deep-space energy stations. Drop energy tokens through the machinery, charge every reactor and deliver power to the Central Core.\n\nDrag to aim the launcher, then press LAUNCH. Chain reactions and crystals earn extra points and stars.',
          textAlign: TextAlign.center,
          style: NovaText.label(15, color: NovaColors.textHi).copyWith(height: 1.5),
        ),
      ],
    ));
  }

  Widget _devicePage(String title, String desc, List<Widget> items) {
    return _wrap(Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: NovaText.title(20, color: NovaColors.cyan)),
        const SizedBox(height: 10),
        Text(desc, textAlign: TextAlign.center, style: NovaText.label(14, color: NovaColors.textLo).copyWith(height: 1.5)),
        const SizedBox(height: 22),
        ...items,
      ],
    ));
  }

  Widget _abilityPage() {
    return _wrap(Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Active Abilities', style: NovaText.title(20, color: NovaColors.magenta)),
        const SizedBox(height: 10),
        Text('While a token is flying, tap an ability to change its fate. Each level gives a limited number of uses.',
            textAlign: TextAlign.center, style: NovaText.label(14, color: NovaColors.textLo).copyWith(height: 1.5)),
        const SizedBox(height: 22),
        _abilityItem(Icons.hourglass_bottom_rounded, 'Slow-Mo', 'Slows time so you can react', const [NovaColors.cyan, NovaColors.blue]),
        _abilityItem(Icons.swap_vert_rounded, 'Gravity Flip', 'Inverts gravity for a moment', const [NovaColors.violet, NovaColors.magenta]),
        _abilityItem(Icons.control_camera_rounded, 'Nudge', 'Pushes the token to the nearest reactor', const [NovaColors.green, NovaColors.cyan]),
        _abilityItem(Icons.blur_on_rounded, 'Magnet Pulse', 'Attracts the token to uncharged reactors', const [NovaColors.blue, NovaColors.violet]),
      ],
    ));
  }

  Widget _wrap(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.5),
        child: child,
      ),
    );
  }

  Widget _spriteItem(String cat, int idx, String name, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeonPanel(
        padding: const EdgeInsets.all(10),
        border: const [NovaColors.blue, NovaColors.violet],
        child: Row(children: [
          Image.asset(A.sprite(cat, idx), width: 52, height: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: NovaText.title(15)),
                const SizedBox(height: 2),
                Text(desc, style: NovaText.label(12, color: NovaColors.textLo)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _abilityItem(IconData icon, String name, String desc, List<Color> grad) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeonPanel(
        padding: const EdgeInsets.all(10),
        border: grad,
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: LinearGradient(colors: grad)),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: NovaText.title(15)),
                const SizedBox(height: 2),
                Text(desc, style: NovaText.label(12, color: NovaColors.textLo)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
