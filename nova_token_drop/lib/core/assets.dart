/// Asset path helpers.
class A {
  static const ui = 'assets/ui';
  static const bg = 'assets/bg';
  static const sounds = 'assets/sounds';
  static const music = 'assets/music';
  static const sprites = 'assets/sprites';

  static const gameName = '$ui/game_name.webp';
  static const icon = '$ui/icon.png';
  static const loadingVertical = '$ui/loading_vertical.webp';
  static const loadingHorizontal = '$ui/loading_horizontal.webp';

  static String location(int i) => '$bg/location$i.webp';

  static String sprite(String cat, int i) => '$sprites/$cat/$i.png';

  // sprite counts available per category
  static const Map<String, int> counts = {
    'token': 9,
    'reactor': 9,
    'magnet': 9,
    'reflector': 8,
    'gravity': 10,
    'teleporter': 8,
    'utility': 24,
    'gate': 32,
    'booster': 16,
    'decor': 35,
  };

  /// Every sprite path we want preloaded into the GPU cache.
  static List<String> allSprites() {
    final list = <String>[];
    counts.forEach((cat, n) {
      for (var i = 0; i < n; i++) {
        list.add(sprite(cat, i));
      }
    });
    return list;
  }
}

/// Background music tracks.
class Music {
  static const menu = 'music/menu_theme.wav';
  static const game = 'music/game_theme.wav';
}

/// SFX (paths relative to assets/ for audioplayers AssetSource).
class Sfx {
  static const uiClick = 'sounds/UI_button_click.mp3';
  static const uiHover = 'sounds/interface_hover.mp3';
  static const launch = 'sounds/energy_sphere_start.mp3';
  static const charge = 'sounds/energy_charge.mp3';
  static const reactor = 'sounds/reactor_activation.mp3';
  static const strongReactor = 'sounds/stronger__sphere_against_a_metallic_reactor.mp3';
  static const reflect = 'sounds/reflection_hit.mp3';
  static const metalHit = 'sounds/sphere_hitting_a_polished_metallic.mp3';
  static const magnet = 'sounds/magnetic_attraction.mp3';
  static const gravity = 'sounds/gravity_inversion.mp3';
  static const teleport = 'sounds/teleportation.mp3';
  static const booster = 'sounds/speed_boster.mp3';
  static const combo = 'sounds/combo.mp3';
  static const chain = 'sounds/energy_activations_rapidly_triggering_one_another.mp3';
  static const crystal = 'sounds/crystal_activation.mp3';
  static const levelComplete = 'sounds/completing_a_level.mp3';
  static const perfect = 'sounds/achieving_a_perfect_score.mp3';
  static const split = 'sounds/Energy_Split.mp3';
  static const merge = 'sounds/energy_spheres_merge.mp3';
}
