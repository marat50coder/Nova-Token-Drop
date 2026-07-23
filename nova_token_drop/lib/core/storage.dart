import 'package:shared_preferences/shared_preferences.dart';

/// Persistent player progress.
class GameStorage {
  GameStorage._();
  static final GameStorage instance = GameStorage._();

  late SharedPreferences _p;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  // ---- audio prefs ----
  bool get musicOn => _p.getBool('musicOn') ?? true;
  set musicOn(bool v) => _p.setBool('musicOn', v);

  bool get sfxOn => _p.getBool('sfxOn') ?? true;
  set sfxOn(bool v) => _p.setBool('sfxOn', v);

  // ---- crystals (soft currency) ----
  int get crystals => _p.getInt('crystals') ?? 0;
  set crystals(int v) => _p.setInt('crystals', v);
  void addCrystals(int v) => crystals = crystals + v;

  // ---- selected token skin ----
  int get skin => _p.getInt('skin') ?? 7;
  set skin(int v) => _p.setInt('skin', v);

  bool skinUnlocked(int i) => i == 7 || i == 0 || (_p.getBool('skin_$i') ?? false);
  void unlockSkin(int i) => _p.setBool('skin_$i', true);

  // ---- level progression ----
  /// Highest unlocked level (1-based). Level 1 always unlocked.
  int get unlockedLevel => _p.getInt('unlockedLevel') ?? 1;
  set unlockedLevel(int v) => _p.setInt('unlockedLevel', v);

  int stars(int level) => _p.getInt('stars_$level') ?? 0;
  void setStars(int level, int s) {
    if (s > stars(level)) _p.setInt('stars_$level', s);
  }

  int best(int level) => _p.getInt('best_$level') ?? 0;
  void setBest(int level, int score) {
    if (score > best(level)) _p.setInt('best_$level', score);
  }

  int get totalStars {
    var t = 0;
    for (var i = 1; i <= 40; i++) {
      t += stars(i);
    }
    return t;
  }

  bool get seenTutorial => _p.getBool('seenTutorial') ?? false;
  set seenTutorial(bool v) => _p.setBool('seenTutorial', v);

  int get levelsCompleted {
    var n = 0;
    for (var i = 1; i <= 40; i++) {
      if (stars(i) > 0) n++;
    }
    return n;
  }

  int get perfectLevels {
    var n = 0;
    for (var i = 1; i <= 40; i++) {
      if (stars(i) == 3) n++;
    }
    return n;
  }

  double get galaxyExplored => levelsCompleted / 40.0;

  // ---- lifetime stats (for the Progress / Achievements screen) ----
  int get lifeReactors => _p.getInt('life_reactors') ?? 0;
  void addLifeReactors(int n) => _p.setInt('life_reactors', lifeReactors + n);

  int get lifeCrystalsCollected => _p.getInt('life_crystal_pickups') ?? 0;
  void addLifeCrystalsCollected(int n) =>
      _p.setInt('life_crystal_pickups', lifeCrystalsCollected + n);

  int get lifeChainBest => _p.getInt('life_chain_best') ?? 0;
  void reportChainBest(int n) {
    if (n > lifeChainBest) _p.setInt('life_chain_best', n);
  }

  int get lifeMagnetUses => _p.getInt('life_magnet') ?? 0;
  void addLifeMagnetUses(int n) => _p.setInt('life_magnet', lifeMagnetUses + n);

  int get lifeBoosterUses => _p.getInt('life_booster') ?? 0;
  void addLifeBoosterUses(int n) => _p.setInt('life_booster', lifeBoosterUses + n);

  int get lifeBallsLaunched => _p.getInt('life_balls') ?? 0;
  void addLifeBallsLaunched(int n) => _p.setInt('life_balls', lifeBallsLaunched + n);

  // ---- daily challenges ----
  String get _todayKey {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _ensureDaily() {
    final last = _p.getString('daily_key');
    final today = _todayKey;
    if (last != today) {
      _p.setString('daily_key', today);
      for (final key in ['reactors', 'chains', 'magnet', 'crystals', 'levels', 'booster']) {
        _p.setInt('daily_$key', 0);
      }
      for (var i = 0; i < 3; i++) {
        _p.setBool('daily_claimed_$i', false);
      }
    }
  }

  int dailyProgress(String metricKey) {
    _ensureDaily();
    return _p.getInt('daily_$metricKey') ?? 0;
  }

  void addDailyProgress(String metricKey, int n) {
    _ensureDaily();
    _p.setInt('daily_$metricKey', dailyProgress(metricKey) + n);
  }

  bool dailyClaimed(int slot) {
    _ensureDaily();
    return _p.getBool('daily_claimed_$slot') ?? false;
  }

  void claimDaily(int slot, int reward) {
    _ensureDaily();
    _p.setBool('daily_claimed_$slot', true);
    addCrystals(reward);
  }

  Duration get timeUntilDailyReset {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return next.difference(now);
  }

  Future<void> resetAll() async {
    final music = musicOn;
    final sfx = sfxOn;
    await _p.clear();
    musicOn = music;
    sfxOn = sfx;
  }
}
